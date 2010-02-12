package EnsEMBL::Web::ViewConfig::Transcript::Exons;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_exons      on
    panel_supporting on
    sscon            25
    seq_cols         60
    flanking         50
    fullseq          no
    oexon            no
    variation        off
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  $view_config->add_form_element({
    type  => 'NonNegInt',
    label => 'Flanking sequence at either end of transcript',
    name  => 'flanking'
  });
  
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'seq_cols',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, name => "$_ bps" }} map $_*15, 2..8
    ]
  });
  
  $view_config->add_form_element({
    type  => 'NonNegInt',
    label => 'Intron base pairs to show at splice sites', 
    name  => 'sscon'
  });
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Show full intronic sequence',
    name  => 'fullseq',
    value => 'yes'
  });
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Show exons only',
    name  => 'oexon',
    value => 'yes'
  });
  
  $view_config->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'variation',
    label  => 'Show variation features',
    values => [
      { value => 'off',  name => 'No'  },
      { value => 'exon', name => 'In exons only' },
      { value => 'on',   name => 'Yes' },
    ]
  });
}

1;
