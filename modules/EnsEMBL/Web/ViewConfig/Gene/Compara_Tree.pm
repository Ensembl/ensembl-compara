package EnsEMBL::Web::ViewConfig::Gene::Compara_Tree;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    image_width          800
    width                800
    text_format          msf
  ));
  $view_config->add_image_configs({qw(
    genetreeview nodas
  )});
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;
  our %formats = (
    'fasta'    => 'FASTA',
    'msf'      => 'MSF',
    'clustalw' => 'CLUSTAL',
    'selex'    => 'Selex',
    'pfam'     => 'Pfam',
    'mega'     => 'Mega',
    'nexus'    => 'Nexus',
    'phylip'   => 'Phylip',
    'psi'      => 'PSI',
  );
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'text_format',
    'label'    => "Output format for sequence alignment",
    'values'   => [
      map { { 'value' => $_,'name' => $formats{$_} } } sort keys %formats
    ]
  });
}
1;
