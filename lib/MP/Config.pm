package MP::Config;
use strict;
use warnings;

use YAML qw/LoadFile/;
use Data::Dumper;

sub new {
    my ($klass, $filename) = @_;

    my $self = bless {
        filename => $filename,
        config => LoadFile($filename) 
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

1;
