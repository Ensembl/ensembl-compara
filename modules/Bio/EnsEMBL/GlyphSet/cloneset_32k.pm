package Bio::EnsEMBL::GlyphSet::cloneset_32k;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::cloneset_1mb;
@ISA = qw(Bio::EnsEMBL::GlyphSet::cloneset_1mb);

sub my_label { return "32k cloneset"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
  return $_[0]->{'container'}->get_all_MiscFeatures( 'cloneset_32k' );
}

1;
