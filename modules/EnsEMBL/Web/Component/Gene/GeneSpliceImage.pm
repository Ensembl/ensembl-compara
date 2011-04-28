# $Id$

package EnsEMBL::Web::Component::Gene::GeneSpliceImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene::GeneSNPImage);

sub content { return $_[0]->SUPER::content(1, 'GeneSpliceView'); }

1;

