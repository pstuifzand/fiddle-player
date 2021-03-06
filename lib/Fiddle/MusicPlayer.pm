package Fiddle::MusicPlayer;
use strict;
use warnings;

use POE qw/Session/;

use Fiddle::Config;
use Fiddle::DB;
use Fiddle::Playlist;
use Fiddle::AutoPlaylist;
use Fiddle::Playlist::Parser;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;

sub new {
    my ($klass) = @_;

    POE::Session->create(
        inline_states => {
            _start => sub {
                my ($heap, $kernel, $session) = @_[HEAP, KERNEL, SESSION];
                $kernel->alias_set('player');

                $heap->{logger} = Log::Dispatch->new();
                $heap->{logger}->add(Log::Dispatch::File::Stamped->new(name => 'file1', min_level => 'debug', filename => 'logs/fiddle.log'));

                $heap->{logger}->info(localtime() . " Loading config\n");

                my $config = Fiddle::Config->new();
                $heap->{config} = $config;

                my $play = GStreamer::ElementFactory->make("playbin", "play");

                $heap->{play} = $play;
                $heap->{bus} = $play->get_bus();
                $heap->{bus}->add_signal_watch();
                $heap->{bus}->signal_connect('message', $session->postback('gstreamer_message_handler'));

                my $db_file = $heap->{config}->music_database();

                $heap->{logger}->info(localtime() . " Loading database $db_file\n");
                $heap->{db} = Fiddle::DB->new_from_filename($db_file);

                $heap->{stopping} = 0;
                $heap->{db}->save();

                $heap->{playlist} = Fiddle::AutoPlaylist->new($heap->{db});

                $heap->{playlist}->set_query_func(sub {
                    my ($db) = @_; return $db->songs();
                });
                $heap->{playlist}->refresh();

                $_[KERNEL]->sig( INT => 'sig_INT' );
            },

            _stop => sub {
                my ($heap, $kernel) = @_[HEAP, KERNEL];
                $heap->{play}->set_state("null");
                $heap->{db}->save();
            },

            load_playlist => sub {
                my ($heap, $filename) = @_[HEAP, ARG0];

                my $parser = Fiddle::Playlist::Parser->new();

                my $playlist_file = $heap->{config}->playlist_file($filename);
                my $query = $parser->parse($playlist_file);

                $heap->{playlist} = Fiddle::AutoPlaylist->new($heap->{db});

                $heap->{playlist}->set_query_func(sub {
                    my ($db) = @_;
                    return $db->query($query);
                });

                $heap->{playlist}->refresh();

                return;
            },

            'sig_INT' => sub {
                my ($heap, $kernel) = @_[HEAP, KERNEL];

                $heap->{play}->set_state("null");
                $heap->{logger}->info(localtime() . " Saving database\n");
                $heap->{db}->save();

                $heap->{logger}->debug(localtime() . " Removing player alias\n");
                $_[KERNEL]->alias_remove('player');

                $heap->{logger}->info(localtime(). " Sending tcp_server shutdown\n");
                $kernel->post('tcp_server'=>'shutdown');

                $heap->{logger}->info(localtime() . " Disconnecting bus message handler\n");
                $heap->{bus}->disconnect('message');
                
                $kernel->sig_handled();

                return;
            },

            gstreamer_message_handler => sub {
                my ($heap, $kernel, $args0, $args1) = @_[HEAP, KERNEL, ARG0, ARG1];

                if ($heap->{stopping}) {
                    return;
                }

                my ($bus, $message) = @$args1;

                if ($message->type & "error") {
                    warn $message->error;
                    $kernel->yield('next');
                }
                elsif ($message->type & "eos") {
                    $kernel->yield('next');
                }

                return 1;
            },

            play => sub {
                my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

                if (!$heap->{playlist}) {
                    $heap->{logger}->warning(localtime() . " No playlist\n");
                }

                my $song = $heap->{playlist}->current_song();

                if ($song) {
                    $heap->{logger}->info(localtime() . " Starting " . $song->to_string() . "\n");

                    $song->played();

                    my $play = $heap->{play};
                    $play->set_state("null");
                    $play->set(uri => Glib::filename_to_uri($song->filename(), "localhost"));
                    $play->set_state("playing");
                }
                else {
                    $heap->{logger}->info(localtime() . " No song in playlist\n");
                }

                return;
            },
            pause => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];
                my $play = $heap->{play};
                $play->set_state("paused");
                return;
            },

            'next' => sub {
                my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

                my $playlist = $heap->{playlist};
                my $play = $heap->{play};

                my $song = $heap->{playlist}->current_song();
                if ($song) {
                    $song->skipped();
                }

                if (!$playlist->next_item()) {
                    $play->set_state("paused");
                    return;
                }

                $kernel->yield('play');
                return;
            },

            prev => sub {
                my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
                my $playlist = $heap->{playlist};
                my $play = $heap->{play};

                my $song = $heap->{playlist}->current_song();
                $song->skipped();

                $playlist->prev_item();

                $kernel->yield('play');
                return;
            },

            repeat => sub {
                my ($kernel, $heap, $session, $arg) = @_[KERNEL, HEAP, SESSION, ARG0];
                my $playlist = $heap->{playlist};
                $playlist->repeat($arg);
                return;
            },

            random => sub {
                my ($kernel, $heap, $session, $arg) = @_[KERNEL, HEAP, SESSION, ARG0];
                my $playlist = $heap->{playlist};
                $playlist->shuffle($arg);
                return;
            },

            rate => sub {
                my ($kernel, $heap, $session, $rate, $callback) = @_[KERNEL, HEAP, SESSION, ARG0, ARG1];
                my $song = $heap->{playlist}->current_song();
                eval {
                    $song->rate($rate);
                    $heap->{db}->save();
                };
                $callback->($@);
            },

            quit => sub {
                my ($kernel, $heap) = @_[KERNEL,HEAP];
                $kernel->yield('sig_INT');
            },

            update => sub {
                my ($kernel, $heap) = @_[KERNEL,HEAP];
                my $config = $heap->{config};
                my $music_dir = $config->get('music_dir');
                $heap->{db}->update($music_dir);
                return;
            },

            status => sub {
                my ($kernel, $heap, $callback) = @_[KERNEL,HEAP,ARG0];

                my $song = $heap->{playlist}->current_song();
                if ($song) {
                    $callback->($song);
                }
            }
        },
    );
    return 'player';
}

1;

