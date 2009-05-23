package Fiddle::Query;

use strict;
use warnings;

use Carp;
use List::Util qw/shuffle/;

sub new {
    my ($klass, $args) = @_;
    my $type = $args->{type} || 'all';
    my $self = bless { rules => [], type => $type }, $klass;
    return $self;
}

sub match {
    my ($self, $song) = @_;

    if ($self->{type} eq 'all') {
        for my $rule ($self->rules()) {
            if (!$rule->match($song)) {
                return;
            }
        }
        return $song;
    }
    elsif ($self->{type} eq 'any') {
        for my $rule ($self->rules()) {
            if ($rule->match($song)) {
                return $song;
            }
        }
        return;
    }
    croak "Unknown query type '$type'";
}

sub rules {
    my ($self) = @_;
    return @{$self->{rules}};
}

sub add_rule {
    my ($self, $rule) = @_;
    push @{$self->{rules}}, $rule;
    return;
}

sub set_order {
    my ($self, $order) = @_;
    $self->{order} = $order;
    return;
}

# Utility function
sub _sort_by(&@) {
    my ($block, @list) = @_;

    return
        map { $_->[0] }
        sort { $a->[1] cmp $b->[1] }
        map { [ $_, $block->($_) ] } @list;
}

sub order_function {
    my ($self) = @_;

    $self->{order}{type} ||= 'unsorted';

    if ($self->{order}{type} eq 'random') {
        return sub {
            my ($songs) = @_;
            return [ shuffle @$songs ];
        };
    }
    elsif ($self->{order}{type} eq 'sorted') {
        $self->{order}{order} ||= 'asc';

        if ($self->{order}{order} eq 'desc') {
            return sub {
                my ($songs) = @_;
                return [ reverse(_sort_by { $_[0]->{ $self->{order}{attribute} } } @$songs) ];
            };
        }
        elsif ($self->{order}{order} eq 'asc') {
            return sub {
                my ($songs) = @_;
                return [ _sort_by { $_[0]->{ $self->{order}{attribute} } } @$songs ];
            };
        }
    }
    return sub {
        my ($songs) = @_;
        return $songs;
    };
}

sub set_name {
    my ($self, $name) = @_;
    $self->{name} = $name;
    return;
}

1;

