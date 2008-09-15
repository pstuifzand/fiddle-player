package Fiddle::Playlist;

use strict;
use warnings;

use Carp;
use Fiddle::Song;

sub new {
    my $klass = shift;
    my $db    = shift;

    my $self = bless {}, $klass;

    $self->{db}      = $db;
    $self->{items}   = [];
    $self->{current} = 0;

    return $self;

};

sub refresh {
}

sub length {
    my ($self) = @_;
    return scalar @{$self->{items}};
}

sub load {
    my ($self, $filename) = @_;

    print "Loading playlist '$filename'\n";

    open my $fh, '<', $filename or croak "Can't open $filename: $!";

    while (<$fh>) {
        chomp;
        next if m/^\s*$/;
        next if m/^\s*#/;
        $self->add_file($_);
    }
    print "Playlist loaded\n";

    return;
}

sub repeat {
    my ($self, $repeat) = @_;
    $self->{repeat} = $repeat;
    return;
}

sub shuffle {
    my ($self, $shuffle) = @_;
    $self->{shuffle} = $shuffle;
    return;
}

sub items {
    my $self = shift;
    return $self->{items};
}

sub add_file {
    my ($self, $filename) = @_;

    eval {
        my $file = $self->{db}->get_file_info($filename);
        push @{$self->{items}}, $file;
        print "  Adding file $filename\n";
    };
    if ($@) {
        print "  Can't add file $filename: $@\n";
    }

    return;
}

sub next_item {
    my $self = shift;

    if ($self->{shuffle}) {
        $self->{current} = int(rand($self->length()));
    }
    else {
        $self->{current}+=1;
    }

    if ($self->{current} >= $self->length()) {
        if ($self->{repeat}) {
            $self->{current} = 0;
            return 1;
        }
        else {
            $self->{current} = 0;
            return;
        }
    }
    return 1;
}

sub prev_item {
    my $self = shift;
    $self->{current} -= 1;
    return;
}

sub current_file {
    my $self = shift;
    return $self->{items}->[$self->{current}]->filename();
}

sub current_song {
    my $self = shift;
    return $self->{items}->[$self->{current}];
}

1;
