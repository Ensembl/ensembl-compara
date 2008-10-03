package EnsEMBL::Web::ViewConfig::Transcript::Sequence_Protein;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons        yes
    codons       yes
    codingseq    yes
    seq_cols         60
    translation  yes
    rna          yes
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
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'codons',      'select' => 'select', 'label'  => 'Show codons' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'codingseq',   'select' => 'select', 'label'  => 'Show coding sequence' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'translation', 'select' => 'select', 'label'  => 'Show protein sequence' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'rna',         'select' => 'select', 'label'  => 'Show RNA features' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'variation',   'select' => 'select', 'label'  => 'Show variation features' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'number',      'select' => 'select', 'label'  => 'Number residues' });

}
1;
