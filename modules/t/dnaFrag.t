use strict;
use warnings;
 
use Test::Harness;
use Test;
BEGIN { plan tests => 9 }

use Bio::EnsEMBL::Test::TestUtils; 
use Bio::EnsEMBL::Compara::DnaFrag;

my $df = new Bio::EnsEMBL::Compara::DnaFrag;

ok( $df );
ok( test_getter_setter( $df, "genomedb", "dummy_db" ));
ok( test_getter_setter( $df, "type", "dummy" ));
ok( test_getter_setter( $df, "adaptor", "dummy_adaptor" ));
ok( test_getter_setter( $df, "dbID", 42 ));
ok( test_getter_setter( $df, "name", "dummy_name" ));
ok( test_getter_setter( $df, "start", 1 ));
ok( test_getter_setter( $df, "end", 256 ));
ok( $df->length == 256 );


