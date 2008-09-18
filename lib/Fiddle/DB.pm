package Fiddle::DB;
use strict;
use warnings;

use Carp;
use Storable;
use File::Next;

use Fiddle::Song;

sub new_from_filename {
    my ($klass, $filename) = @_;

    my $self = bless {}, $klass;
    $self->{filename} = $filename;

    if (-e $filename) {
        $self->{db} = retrieve($filename);
    }
    else {
        $self->{db} = {};
    }

    return $self;
}

sub save {
    my ($self) = @_;
    store($self->{db}, $self->{filename});
    return;
}

sub get_file_info {
    my ($self, $filename) = @_;

    if (!exists $self->{db}->{$filename}) {
        eval {
            $self->{db}->{$filename} = Fiddle::Song->new_from_filename($filename);
        };
        if ($@) {
            delete $self->{db}->{$filename};
            croak $@;
        }
    }

    return $self->{db}->{$filename};
}

sub songs {
    my ($self) = @_;
    return values(%{$self->{db}});
}

sub find_on_property {
    my ($self, $property, $regex) = @_;

    my @results;

    for ($self->songs()) {
        push @results, $_ if $_->{$property} =~ m/$regex/;
    }

    return @results;
}

sub query {
    my ($self, $query) = @_;
    my $order_f = $query->order_function();
    return @{ $order_f->(  [grep { $query->match($_) } $self->songs()]  ) };
}

sub update {
    my ($self, $dir) = @_;

    print STDERR "Updating [$dir]\n";

    my $files = File::Next::files($dir);

    while (my $file = $files->()) {
        eval {
            print STDERR $file . "\n";
            my $info = $self->get_file_info($file);
        };
        if ($@) {
            print STDERR "For $file: $@\n";
        }
    }

    return;
}

1;
