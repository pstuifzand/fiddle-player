package Fiddle::Playlist::Parser;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use Fiddle::Query;
use Fiddle::Rule::Match;

sub new {
    my ($klass) = @_;

    my $self = bless {}, $klass;

    return $self;
}

sub parse_line {
    my ($self, $line) = @_;

    # Comments
    return if $line =~ m/^\s*#/;

    $line =~ s/^\s+//;

    if ($line =~ m{^([a-z][a-z0-9_]*)\s+((?:not\s+)?match)\s+/([^/]+)/$}) {
        return { class => 'Fiddle::Rule::Match', args => { attribute => $1, operator => $2, regex => qr/$3/ } };
    }
    elsif ($line =~ m{^name\s+(.+)$}) {
        return { type => 'name', name => $1 };
    }
    elsif ($line =~ m{^order\s+(\w+)\s+(asc|desc)?$}) {
        return { type => 'order', attribute => $1, order => $2 };
    }
    elsif ($line =~ m{^random$}) {
        return { type => 'random' };
    }
    elsif ($line =~ m{^end}) {
        return { type => 'end' };
    }
    elsif ($line =~ m{^match\s+(any|all)$}) {
        return { subrule => 1, class => 'Fiddle::Query', args => { type => $1 }  };
    }

    return;
}

sub parse {
    my ($self, $filename) = @_;

    print STDERR "Loading playlist query '$filename'\n";

    my @query_tree;

    unshift @query_tree, Fiddle::Query->new();

    open my $fh, '<', $filename or croak "Can't open $filename: $!";

    while (<$fh>) {
        my $rule = $self->parse_line($_);
        next if !defined $rule;

        print Dumper($rule);

        if (defined $rule->{class}) {
            my $rule_obj =  $rule->{class}->new( $rule->{args} );
            if ($rule->{subrule}) {
                unshift @query_tree, $rule_obj;
            }
            else {
                $query_tree[0]->add_rule($rule_obj); 
            }
        }
        elsif ($rule->{type} eq 'name') {
            $query_tree[0]->set_name($rule->{name});
        }
        elsif ($rule->{type} eq 'order') {
            $query_tree[0]->set_order({ type => 'sorted', attribute => $rule->{attribute}, order => $rule->{order} });
        }
        elsif ($rule->{type} eq 'random') {
            $query_tree[0]->set_order({ type => 'random' });
        }
        elsif ($rule->{type} eq 'end') {
            my $rule_obj = shift @query_tree;
            $query_tree[0]->add_rule($rule_obj);
        }
    }

    close $fh;

    return $query_tree[0];
}

1;

