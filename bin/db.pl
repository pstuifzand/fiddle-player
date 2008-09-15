#!/usr/bin/perl -w

use Storable;
use Data::Dumper;

use lib 'lib';
use MP::Song;

my $db = retrieve('music.db');

my @songs = grep { $_->{artist} eq 'NOFX' } values %$db;

for (sort { $a->{album} cmp $b->{album} } @songs) {
    print $_->to_string() . "\n";
}

print Dumper(group_by(sub { $_->{album} }, @songs));

sub group_by {
    my ($sub, @list) = @_;

    my $results = {};

    for my $song (@list) {
        local $_  = $song;
        push @{$results->{ $sub->() }}, $song;
    }
    
    return $results;
}
