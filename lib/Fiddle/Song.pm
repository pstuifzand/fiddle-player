package Fiddle::Song;

use strict;
use warnings;

use Carp;
use Date::Format;

use Fiddle::Song::MP3;
#use Fiddle::Song::OGG;
#use Fiddle::Song::FLAC;


sub new {
    my ($klass, $songinfo) = @_;

    my $self = { %$songinfo };

    $self->{play_count} ||=0;
    $self->{skip_count} ||=0;

    return bless $self, $klass;
}

sub klass_from_filename {
    my ($filename) = @_;
    if (my ($ext) = $filename =~ m/\.(mp3|flac|ogg)$/) {
        return 'Fiddle::Song::' . uc $ext;
    }
    die "Can't find class for loading $filename";
}

sub new_from_filename {
    my ($klass, $filename, $previous) = @_;

    my $song_klass = klass_from_filename($filename);

    my $song = $song_klass->new($filename);

    my $info = {
        title    => $song->title || 'Unknown',
        artist   => $song->artist || 'Unknown',
        album    => $song->album || 'Unknown',
        track    => $song->track || 0,
        year     => $song->year || 0,
        genre    => $song->genre || '',
        filename => $filename,
        play_count => $previous ? $previous->{play_count} : 0,
        skip_count => $previous ? $previous->{skip_count} : 0,
    };

    return $klass->new($info);
}

sub rate {
    my ($self, $rate) = @_;

    if ($rate >= 1 && $rate <= 5) {
        $self->{rate} = $rate;
        return;
    }
    croak "Rate should be >= 1 and <= 5";
}

sub to_string {
    my $self = shift;
    my $str = '#<Song: artist=' . $self->{artist} . ', title=' . $self->{title} . ', album=' . $self->{album} . '>';
    return $str;
}

sub filename {
    my $self = shift;
    return $self->{filename};
}

sub played {
    my $self = shift;
    $self->{play_count}++;
    $self->{last_played} = time2str('%Y-%m-%d %T', time());
    return;
}

sub skipped {
    my $self = shift;
    $self->{skip_count}++;
    return;
}

1;
