use strict;
use warnings;
 
use Test::Harness;
use Test;

BEGIN { plan tests => 8 }

use Bio::EnsEMBL::Test::TestUtils; 
use Bio::EnsEMBL::Compara::Homology;

my $homology = new Bio::EnsEMBL::Compara::Homology(
-dbID => 12,
-stable_id => "my_dummy_stable_id",
-description => "dummy gene",
-adaptor => "dummy_adaptor",
-method_link_species_set_id => 6);

$homology->method_link_type("ENSEMBL_ORTHOLOGUES");
$homology->method_link_id(2);

ok( $homology );
ok( test_getter_setter( $homology, "dbID", 202501 ));
ok( test_getter_setter( $homology, "stable_id", "dummy stable_id" ));
ok( test_getter_setter( $homology, "description", "my dummy description" ));
ok( test_getter_setter( $homology, "method_link_species_set_id", 2 ));
ok( test_getter_setter( $homology, "method_link_id", 2 ));
ok( test_getter_setter( $homology, "method_link_type", "blablablo" ));
ok( test_getter_setter( $homology, "adaptor", "dummy_adaptor" ));





