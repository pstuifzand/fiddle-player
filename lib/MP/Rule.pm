package MP::Rule;
use strict;
use warnings;

sub new {
    my ($klass, $args) = @_;
    my $self = bless {}, $klass;
    $self->_check_args($args);
    %$self = (%$args, %$self);
    return $self;
}

sub _check_args {
    return 1;
}

sub match {
    my ($self, $song) = @_;
    return;
}

1;
