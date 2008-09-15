#!/usr/bin/perl -w
use lib 'lib';

use MP::Playlist;
use Data::Dumper;

my $playlist = MP::Playlist->new();

eval {
    $playlist->add_file($ARGV[0]);
};
if ($@) {
    print "Unknown file: $@";
}

for my $song (@{$playlist->items()}) {
    print 'Title:  '. $song->title. "\n".
        'Artist: '. $song->artist. "\n".
        'Album:  '. $song->album. "\n".
        'Track:  '. $song->track. "\n";
        'Year:   '. $song->year. "\n".
        'Genre:  '. $song->genre. "\n";
}

