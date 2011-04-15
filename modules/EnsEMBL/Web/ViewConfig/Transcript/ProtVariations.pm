# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ProtVariations;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->_set_defaults(qw(
    consequence_format   ensembl
    show_scores          no
  ));
  
  $self->storable = 1;
}

sub form {
  my $self = shift;

  # Add selection
  $self->add_fieldset('Consequence types');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'ensembl', name => 'Ensembl terms'           },
      { value => 'so',      name => 'Sequence Ontology terms' },
      { value => 'ncbi',    name => 'NCBI terms'              },
    ]
  });  
  
  if ($self->hub->species =~ /homo_sapiens/i) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => 'Show SIFT and PolyPhen scores',
      name  => 'show_scores',
      value => 'yes',
      raw   => 1,
    });
  }
}

1;
