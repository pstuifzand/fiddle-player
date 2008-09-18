package Fiddle::Config;
use strict;
use warnings;

use YAML qw/LoadFile DumpFile/;
use Data::Dumper;
use File::Spec::Functions;

sub new {
    my ($klass) = @_;

    my $config_dir = $ENV{HOME} . '/.fiddle/';

    if (!-e $config_dir) {
        mkdir $config_dir;
    }

    for (qw/db playlists/) {
        my $dir = File::Spec->catfile($config_dir, $_);
        if (!-e $dir) {
            mkdir $dir;
        }
    }

    my $filename = $config_dir . '/config.yml';

    if (!-e $filename) {
        my $config = { music_dir => $ENV{HOME} . '/Music' };
        DumpFile($filename, $config);
    }

    my $self = bless {
        filename   => $filename,
        config     => LoadFile($filename),
        config_dir => $config_dir,
    }, $klass;

    return $self;
}

sub get {
    my ($self, $name) = @_;

    my @parts = split /\./, $name;

    my $ref = $self->{config};

    for (@parts) {
        $ref = $ref->{$_};
    }

    return $ref;
}

sub music_database {
    my $self = shift;
    return  $self->{config_dir} . '/db/music.db';
}

sub playlist_file {
    my $self = shift;
    my $filename = shift;

    my $playlist_dir = $self->{config_dir} . '/playlists/';
    my $playlist_file = $playlist_dir . $filename . '.plq';

    return $playlist_file;
}

1;
