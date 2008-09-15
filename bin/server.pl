use strict;
use warnings;

use lib 'lib';

use Glib;
use POE qw/Loop::Glib/;
use POE::Component::Server::TCP;
use GStreamer -init;
use Data::Dumper;

use MP::Config;
use MP::DB;
use MP::Playlist;
use MP::AutoPlaylist;
use MP::Playlist::Parser;

POE::Session->create(
    inline_states => {
        _start => sub {
            my ($heap, $kernel, $session) = @_[HEAP, KERNEL, SESSION];
            $kernel->alias_set('player');

            my $config_dir = $ENV{HOME} . '/.mp/';
            $heap->{config_dir} = $config_dir;

            print STDERR "Using config_dir $config_dir\n";

            my $config = MP::Config->new($config_dir . '/config.yml');
            $heap->{config} = $config;

            my $play = GStreamer::ElementFactory->make("playbin", "play");

            $heap->{play} = $play;
            $heap->{bus} = $play->get_bus();
            $heap->{bus}->add_signal_watch();
            $heap->{bus}->signal_connect('message', $session->postback('gstreamer_message_handler'));

            my $db_file = $config_dir . '/db/music.db';

            print STDERR "Loading database $db_file\n";
            $heap->{db} = MP::DB->new_from_filename($db_file);

            $heap->{stopping} = 0;
            $heap->{db}->save();

            $_[KERNEL]->sig( INT => 'sig_INT' );
        },

        _stop => sub {
            my ($heap, $kernel) = @_[HEAP, KERNEL];
            $heap->{play}->set_state("null");
            $heap->{db}->save();
        },

        load_playlist => sub {
            my ($heap, $filename) = @_[HEAP, ARG0];

            my $parser = MP::Playlist::Parser->new();

            my $playlist_dir = $heap->{config_dir} . '/playlists/';

            my $playlist_file = $playlist_dir . $filename . '.plq';

            my $query = $parser->parse($playlist_file);

            print Dumper($query);

            $heap->{playlist} = MP::AutoPlaylist->new($heap->{db});

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
            print "Saving database\n";
            $heap->{db}->save();

            print "Removing player alias\n";
            $_[KERNEL]->alias_remove('player');

            print "Sending tcp_server shutdown\n";
            $kernel->post('tcp_server'=>'shutdown');

            print "Disconnecting bus message handler\n";
            $heap->{bus}->disconnect('message');
            
            $kernel->sig_handled();

            return;
        },

        gstreamer_message_handler => sub {
            my ($heap, $kernel, $args0, $args1) = @_[HEAP, KERNEL, ARG0, ARG1];

            if ($heap->{stopping}) {
                return;
            }

            #print Dumper($args1);

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

            my $song = $heap->{playlist}->current_song();
            print Dumper($song);
            if ($song) {
                print "Starting " . $song->to_string() . "\n";

                $song->played();

                my $play = $heap->{play};
                $play->set(uri => Glib::filename_to_uri($song->filename(), "localhost"));
                $play->set_state("playing");
            }
            else {
                print "No song in playlist\n";
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
            $song->skipped();

            if (!$playlist->next_item()) {
                $play->set_state("paused");
                return;
            }

            $play->set_state("null");
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

            $play->set_state("null");

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
    },
);

POE::Component::Server::TCP->new(
    Alias => 'tcp_server',
    Port => 12345,

    ClientConnected => sub {
        print "got a connection from $_[HEAP]{remote_ip}\n";
        $_[HEAP]{client}->put("connected");
    },
    ClientInput => sub {
        my ($client_input, $kernel, $session) = @_[ARG0, KERNEL, SESSION];
        if ($client_input =~ m/^play\b/) {
            $kernel->post('player' => 'play');
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^pause\b/) {
            $kernel->post('player' => 'pause');
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^next\b/) {
            $kernel->post('player' => 'next');
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^prev\b/) {
            $kernel->post('player' => 'prev');
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^rate\s+(\d+)/) {
            $kernel->post('player' => 'rate', $1, $session->postback('rate_ok'));
        }
        elsif ($client_input =~ m/^quit\b/) {
            $kernel->post('player' => 'quit');
            $kernel->post('server' => "shutdown" );
        }
        elsif ($client_input =~ m/^playlist\s+(\w+)$/) {
            $kernel->post(player => load_playlist => $1);
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^random\s+(on|off)$/) {
            $kernel->post(player => random => ($1 eq 'on'));
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^repeat\s+(on|off)$/) {
            $kernel->post(player => repeat => ($1 eq 'on'));
            $_[HEAP]{client}->put("+ok");
        }
        elsif ($client_input =~ m/^update$/) {
            $kernel->post(player => 'update');
            $_[HEAP]{client}->put("+ok updating");
        }
    },
    ClientDisconnected => sub {
        print "client from $_[HEAP]{remote_ip} disconnected\n";
    },
    InlineStates => {
        rate_ok => sub {
            my ($heap, $kernel, $args) = @_[HEAP, KERNEL, ARG1];
            $heap->{client}->put("+ok rate " . $args->[0]);
        },
    },
);

POE::Kernel->run();
