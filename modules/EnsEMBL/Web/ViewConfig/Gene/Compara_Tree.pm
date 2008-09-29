package EnsEMBL::Web::ViewConfig::Gene::Compara_Tree;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    image_width          800
    width                800
    text_format          msf
    tree_format          newick_mode
    newick_mode          full_web
    nhx_mode             full
    scale                150
  ));
#  $view_config->add_image_configs({qw( genetreeview nodas)});
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;
  our %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $view_config->add_fieldset('Text aligment output options');
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'text_format',
    'label'    => "Output format for sequence alignment",
    'values'   => [ map { { 'value' => $_,'name' => $formats{$_} } } sort keys %formats ]
  });

  $view_config->add_fieldset('Text tree output options');
  %formats =  EnsEMBL::Web::Constants::TREE_FORMATS;
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'tree_format',
    'label'    => "Output format for tree",
    'values'   => [ map { { 'value' => $_,'name' => $formats{$_}{'caption'} } } sort keys %formats ]
  });

  $view_config->add_form_element({
    'type'     => 'PosInt', 
    'required' => 'yes',      'name'     => 'scale',
    'label'    => "Scale size for Tree text dump",
  });

  %formats =  EnsEMBL::Web::Constants::NEWICK_OPTIONS;
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'newick_mode',
    'label'    => "Mode for Newick tree dumping",
    'values'   => [ map { { 'value' => $_,'name' => $formats{$_} } } sort keys %formats ]
  });

  %formats =  EnsEMBL::Web::Constants::NHX_OPTIONS;
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'nhx_mode',
    'label'    => "Mode for NHX tree dumping",
    'values'   => [ map { { 'value' => $_,'name' => $formats{$_} } } sort keys %formats ]
  });
}

1;
