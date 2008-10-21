package EnsEMBL::Web::ViewConfig::Transcript::Sequence_Protein;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons        yes
    seq_cols     60
    variation    yes
    number       yes
  ));
  $view_config->storable = 1;
}

sub form {
  my $view_config = shift;

  $view_config->add_form_element({
    'type'     => 'DropDown', 'select' => 'select',
    'required' => 'yes',      'name'   => 'seq_cols',
    'values'   => [
      map { {'value' => $_, 'name' => "$_ aa"} } map { 10 * $_ } (3..20)
    ],
    'label'    => "Number of amino acids per row"
  });

  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'exons',       'select' => 'select', 'label'  => 'Show exons' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'variation',   'select' => 'select', 'label'  => 'Show variation features' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'number',      'select' => 'select', 'label'  => 'Number residues' });

}
1;
