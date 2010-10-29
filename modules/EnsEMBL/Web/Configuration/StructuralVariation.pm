# $Id$

package EnsEMBL::Web::Configuration::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Summary';
}


sub populate_tree {
  my $self = shift;

  $self->create_node('Summary', 'Context',
    [qw(
      context  EnsEMBL::Web::Component::StructuralVariation::Context
    )],
    { 'availability' => 'structural_variation', 'concise' => 'Context' }
  );
  
}

1;
