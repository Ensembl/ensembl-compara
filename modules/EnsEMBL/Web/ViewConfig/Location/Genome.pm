package EnsEMBL::Web::ViewConfig::Location::Genome;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
### Used by Constructor
### init function called to set defaults for the passed
### {{EnsEMBL::Web::ViewConfig}} object

  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_top      yes
    panel_zoom      no
    image_width   1200
    zoom_width     100
    context       1000
    rows          2
    chr_length    200
    h_padding     4
    h_spacing     6
    v_spacing     10
  ));
  $view_config->add_image_configs({qw(
    Vkaryotype    das
  )});
  $view_config->default_config = 'Vkaryotype';
  $view_config->storable       = 1;
  $view_config->can_upload = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  $view_config->add_fieldset('Chromosome layout');

  $view_config->add_form_element({
    'type'    => 'DropDown',
    'name'    => 'rows',
    'label'   => 'Number of rows of chromosomes',
    'values'  => [
      {'name' => '1', 'value' => '1'},
      {'name' => '2', 'value' => '2'},
      {'name' => '3', 'value' => '3'},
      {'name' => '4', 'value' => '4'},
    ],
    'select'  => 'select',
  });

  $view_config->add_form_element({
    'type'  => 'Int',
    'name'  => 'chr_length',
    'label' => 'Height of the longest chromosome (pixels)',
    'required'=>'yes',
  });

=pod
  $view_config->add_form_element({
    'type'  => 'Int',
    'name'  => 'h_padding',
    'label' => 'Padding around chromosomes (pixels)',
    'required'=>'yes',
  });

  $view_config->add_form_element({
    'type'  => 'Int',
    'name'  => 'h_spacing',
    'label' => 'Spacing between chromosomes (pixels)',
    'required'=>'yes',
  });

  $view_config->add_form_element({
    'type'  => 'Int',
    'name'  => 'v_spacing',
    'label' => 'Spacing between rows (pixels)',
    'required'=>'yes',
  });
=cut

}

1;
