package EnsEMBL::Web::ViewConfig::Transcript::Sequence_Protein;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons         yes
    display_width 60
    variation     no
    number        no
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'display_width',
    label  => 'Number of amino acids per row',
    values => [
      map {{ value => $_, name => "$_ aa" }} map 10*$_, 3..20
    ]
  });
  
  $view_config->add_form_element({ type => 'YesNo', name => 'exons',     select => 'select', label => 'Show exons' });
  $view_config->add_form_element({ type => 'YesNo', name => 'variation', select => 'select', label => 'Show variation features' }) if $object->species_defs->databases->{'DATABASE_VARIATION'};
  $view_config->add_form_element({ type => 'YesNo', name => 'number',    select => 'select', label => 'Number residues' });
}

1;
