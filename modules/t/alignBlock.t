use strict;
use warnings;
 
use lib 't';
 
use Test::Harness;
use Test;
BEGIN { plan tests => 15 }

use TestUtils qw( debug test_getter_setter ); 
use Bio::EnsEMBL::Compara::AlignBlock;

my $ab = new Bio::EnsEMBL::Compara::AlignBlock;

ok( $ab );

ok( test_getter_setter( $ab, "start", 1 ));
ok( test_getter_setter( $ab, "end", 256 ));

ok( test_getter_setter( $ab, "align_start", 1 ));
ok( test_getter_setter( $ab, "align_end", 256 ));

ok( test_getter_setter( $ab, "strand", 1 ));
ok( test_getter_setter( $ab, "perc_id", "0.42" ));

ok( test_getter_setter( $ab, "score", 100 ));

ok( test_getter_setter( $ab, "cigar_string", "M12I2M34D2M42" ));
ok( test_getter_setter( $ab, "dnafrag", "dummy" ));

ok ( $ab->primary_tag eq "align");
ok ( $ab->source_tag eq "ensembl");

ok ( $ab->has_tag == 0 );

my @tags = $ab->all_tags;

ok ( $tags[0] eq "primary_tag" );
ok ( $tags[1] eq "source_tag" );