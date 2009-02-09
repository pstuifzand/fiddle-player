package Fiddle::Song::MP3;

use strict;
use warnings;

use MP3::Tag;

sub new {
    my ($klass, $filename) = @_;

    my $mp3 = MP3::Tag->new($filename);
    my ($title, $track, $artist, $album, $comment, $year, $genre) = $mp3->autoinfo();

    my $self = bless { 
        filename => $filename, 
        title    => $title,
        track    => $track,
        artist   => $artist,
        album    => $album,
        comment  => $comment,
        year     => $year,
        genre    => $genre,
    }, $klass;

    return $self;
}

sub title {
    my $self = shift;
    return $self->{title};
}

sub artist {
    my $self = shift;
    return $self->{artist};
}

sub album {
    my $self = shift;
    return $self->{album};
}

sub track {
    my $self = shift;
    return $self->{track};
}

sub year {
    my $self = shift;
    return $self->{year};
}

sub genre {
    my $self = shift;
    return $self->{genre};
}

sub comment {
    my $self = shift;
    return $self->{comment};
}

1;
