package EnsEMBL::Web::ViewConfig::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    consequence_format   ensembl
    show_scores          no
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  # Add selection
  $view_config->add_fieldset('Gene/Transcript');
  
  $view_config->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'ensembl',  name => 'Ensembl terms'           },
      { value => 'so',       name => 'Sequence Ontology terms' },
      { value => 'ncbi',     name => 'NCBI terms'              },
    ]
  });  
  
  if($view_config->hub->species =~ /homo_sapiens/i) {
    $view_config->add_form_element({
      type  => 'CheckBox',
      label => 'Show SIFT and PolyPhen scores',
      name  => 'show_scores',
      value => 'yes',
      raw   => 1,
    });
  }
}

1;
