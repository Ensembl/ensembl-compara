use strict;
use warnings;
 
use Test::Harness;
use Test;

BEGIN { plan tests => 8 }

use Bio::EnsEMBL::Test::TestUtils; 
use Bio::EnsEMBL::Compara::Family;

my $family = new Bio::EnsEMBL::Compara::Family(
-dbID => 12,
-stable_id => "my_dummy_stable_id",
-description => "dummy gene",
-adaptor => "dummy_adaptor",
-method_link_species_set_id => 7);

$family->method_link_type("FAMILY");
$family->method_link_id(2);

ok( $family );
ok( test_getter_setter( $family, "dbID", 202501 ));
ok( test_getter_setter( $family, "stable_id", "dummy stable_id" ));
ok( test_getter_setter( $family, "description", "my dummy description" ));
ok( test_getter_setter( $family, "method_link_species_set_id", 2 ));
ok( test_getter_setter( $family, "method_link_id", 2 ));
ok( test_getter_setter( $family, "method_link_type", "blablablo" ));
ok( test_getter_setter( $family, "adaptor", "dummy_adaptor" ));





