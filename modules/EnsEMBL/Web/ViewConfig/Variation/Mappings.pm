# $Id$

package EnsEMBL::Web::ViewConfig::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    consequence_format => 'ensembl',
    show_scores        => 'no'
  });

  $self->title = 'Gene/Transcript';
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
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
