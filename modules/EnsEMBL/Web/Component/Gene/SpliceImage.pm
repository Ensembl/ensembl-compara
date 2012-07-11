package EnsEMBL::Web::Component::Gene::SpliceImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene::VariationImage);

sub content { return $_[0]->SUPER::content(1, 'gene_splice'); }

1;

