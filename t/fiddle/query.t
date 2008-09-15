use Test::More tests => 4;
use Test::Deep;
use Data::Dumper;

use_ok('Fiddle::Query') or die "Can't use Fiddle::Query";

{
    # Sorted on title ascending
    my $q = Fiddle::Query->new();
    $q->set_order({ type => 'sorted', attribute => 'title', order => 'asc' });
    my $order_f = $q->order_function();
    my $songs = $order_f->([ {title => 'A'}, {title => 'Z'}, {title=>'C'} ]);
    cmp_deeply($songs, [{title=>'A'},{title=>'C'}, {title=>'Z'}]);
}

{
    # Sorted on title descending
    my $q = Fiddle::Query->new();
    $q->set_order({ type => 'sorted', attribute => 'title', order => 'desc' });
    my $order_f = $q->order_function();
    my $songs = $order_f->([ {title => 'A'}, {title => 'Z'}, {title=>'C'} ]);
    cmp_deeply( $songs, [{title=>'Z'},{title=>'C'}, {title=>'A'}]);
}

{
    # No order
    my $q = Fiddle::Query->new();
    my $order_f = $q->order_function();
    my $songs = $order_f->([ {title => 'A'}, {title => 'Z'}, {title=>'C'} ]);
    cmp_deeply($songs, [{title=>'A'},{title=>'Z'}, {title=>'C'}]);
}

