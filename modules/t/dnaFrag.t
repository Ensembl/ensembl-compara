use strict;
use warnings;
 
use lib 't';
 
use Test::Harness;
use Test;
BEGIN { plan tests => 7 }

use TestUtils qw( debug test_getter_setter ); 
use Bio::EnsEMBL::Compara::DnaFrag;

my $df = new Bio::EnsEMBL::Compara::DnaFrag;

ok( $df );
ok( test_getter_setter( $df, "genomedb", "dummy_db" ));
ok( test_getter_setter( $df, "type", "dummy" ));
ok( test_getter_setter( $df, "adaptor", "dummy_adaptor" ));
ok( test_getter_setter( $df, "dbID", 42 ));
ok( test_getter_setter( $df, "start", 1 ));
ok( test_getter_setter( $df, "end", 256 ));
