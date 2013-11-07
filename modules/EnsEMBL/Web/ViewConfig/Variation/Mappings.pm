# $Id$

package EnsEMBL::Web::ViewConfig::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    motif_scores       => 'no'
  });

  $self->title = 'Genes and regulation';
}

sub form {
  my $self = shift;
  
  if ($self->hub->species =~ /homo_sapiens|mus_musculus/i) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => 'Show regulatory motif binding scores',
      name  => 'motif_scores',
      value => 'yes',
      raw   => 1,
    });
  }
}

1;
