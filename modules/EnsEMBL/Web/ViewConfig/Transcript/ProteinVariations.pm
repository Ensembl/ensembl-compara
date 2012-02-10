# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ProteinVariations;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    consequence_format => 'ensembl',
  });

  $self->title = 'Protein Variations';
}

sub form {
  my $self = shift;

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
}

1;
