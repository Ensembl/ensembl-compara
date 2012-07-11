package EnsEMBL::Web::Component::Transcript::VariationImage;

use strict;

use base qw(EnsEMBL::Web::Component::VariationImage);

sub content { return $_[0]->SUPER::content(undef, 'transcript_variation'); }

1;
