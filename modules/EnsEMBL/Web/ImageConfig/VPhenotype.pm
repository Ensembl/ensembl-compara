# $Id$

package EnsEMBL::Web::ImageConfig::VPhenotype;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::Vkaryotype);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  $self->get_node('user_data')->remove;
}

1;
