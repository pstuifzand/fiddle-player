package MP::Song;

use strict;
use warnings;

use Carp;
use AudioFile::Info;
use Date::Format;

sub new {
    my ($klass, $songinfo) = @_;

    my $self = { %$songinfo };

    $self->{play_count} ||=0;
    $self->{skip_count} ||=0;

    return bless $self, $klass;
}

sub new_from_filename {
    my ($klass, $filename) = @_;

    my $song = AudioFile::Info->new($filename);

    my $info = {
        title    => $song->title || 'Unknown',
        artist   => $song->artist || 'Unknown',
        album    => $song->album || 'Unknown',
        track    => $song->track || 0,
        year     => $song->year || 0,
        genre    => $song->genre || '',
        filename => $filename,
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
