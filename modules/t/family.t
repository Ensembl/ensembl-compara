use strict;
use warnings;
 
use Test::Harness;
use Test;

BEGIN { plan tests => 7 }

use Bio::EnsEMBL::Test::TestUtils; 
use Bio::EnsEMBL::Compara::Family;

my $family = new Bio::EnsEMBL::Compara::Family(
-dbID => 12,
-stable_id => "my_dummy_stable_id",
-description => "dummy gene",
-adaptor => "dummy_adaptor",
-source_id => 7,
-source_name => "ENSEMBL_FAMILIES");

ok( $family );
ok( test_getter_setter( $family, "dbID", 202501 ));
ok( test_getter_setter( $family, "stable_id", "dummy stable_id" ));
ok( test_getter_setter( $family, "description", "my dummy description" ));
ok( test_getter_setter( $family, "source_id", 2 ));
ok( test_getter_setter( $family, "source_name", "blablablo" ));
ok( test_getter_setter( $family, "adaptor", "dummy_adaptor" ));





