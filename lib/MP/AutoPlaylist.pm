package MP::AutoPlaylist;

use strict;
use warnings;

use base 'MP::Playlist';

sub set_query_func {
    my ($self, $query) = @_;
    $self->{query_func} =  $query;
    return;
}

sub refresh {
    my $self = shift;
    $self->{items} = [];
    $self->{items} = [ $self->{query_func}->($self->{db}) ];
    return;
}

1;

