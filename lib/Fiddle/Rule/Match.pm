package Fiddle::Rule::Match;

use strict;
use warnings;

use base 'Fiddle::Rule';
use Carp;
use Data::Dumper;

sub _check_args {
    my ($self, $args) = @_;
    print Dumper($args);

    croak "Argument 'operator' missing" unless defined $args->{operator};
    croak "Argument 'operator' should be one of 'match' or 'not match'" unless $args->{operator} =~ m/^(not\s+)?match$/;

    croak "Argument 'attribute' missing" unless defined $args->{attribute};
    croak "Argument 'attribute' should be name" unless $args->{attribute} =~ m/^[a-z][a-z0-9_]+$/;

    croak "Argument 'regex' missing" unless defined $args->{regex};
#    croak "Argument 'regex' should be a regex" unless ref($args->{regex}) eq 'REGEX';

    return 1;
}

sub match {
    my ($self, $song) = @_;

    if ($self->{operator} eq 'match') {
        return unless defined $song->{ $self->{attribute} };

        if ($song->{$self->{attribute}} =~ $self->{regex}) {
            return $song;
        }
    }
    elsif ($self->{operator} eq 'not match') {
        return $song unless defined $song->{ $self->{attribute} };

        if ($song->{$self->{attribute}} !~ $self->{regex}) {
            return $song;
        }
    }

    return;
}

1;
