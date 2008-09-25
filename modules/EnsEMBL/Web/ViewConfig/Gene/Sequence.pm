package EnsEMBL::Web::ViewConfig::Gene::Sequence;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my ($view_config) = @_;

  $view_config->title = 'Marked up gene sequence';
  $view_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600 
    exon_display            core
    exon_ori                all
    snp_display             off
    line_numbering          off
  ));
  $view_config->storable = 1;

}

sub form {
  my( $view_config, $object ) = @_;

  $view_config->add_form_element({
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
  });
  $view_config->add_form_element({
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
  });
  my $values = [
    { 'value' => 'off',           'name' => 'No exon markup' },
    { 'value' => 'Ab-initio',     'name' => 'Ab-initio exons' },
    { 'value' => 'core',          'name' => "Core exons" }
  ];
  push @$values, { 'value' => 'vega', 'name' => 'Vega exons' }
    if $object->species_defs->databases->{'DATABASE_VEGA'};
  push @$values, { 'value' => 'otherfeatures', 'name' => 'EST gene exons' }
    if $object->species_defs->databases->{'DATABASE_OTHERFEATURES'};

  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_display',
    'label'    => 'additional exons to display',
    'values'   => $values
  });
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => "Orientation of additional exons",
    'values'   => [
      { 'value' =>'fwd' , 'name' => 'Display same orientation exons only' },
      { 'value' =>'rev' , 'name' => 'Display reverse orientation exons only' },
      { 'value' =>'all' , 'name' => 'Display exons in both orientations' }
    ]
  });
  if( $object->species_defs->databases->{'DATABASE__VARIATION'} ) {
    $view_config->add_form_element({
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => [
        { 'value' =>'off',       'name' => 'No' },
        { 'value' =>'snp',       'name' => 'Yes' },
        { 'value' =>'snp_link' , 'name' => 'Yes and show links' },
      ]
    });
  }
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'line_numbering',
    'label'    => 'Line numbering',
    'values'   => [
      { 'value' =>'sequence' , 'name' => 'Relative to this sequence' },
      { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
      { 'value' =>'off'      , 'name' => 'None' },
    ]
  });
}
1;

