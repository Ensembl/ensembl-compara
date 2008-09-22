package EnsEMBL::Web::ViewConfig::Transcript::Sequence_cDNA;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons        on
    codons       on
    codingseq    on
    translation  on
    rna          on
    variation    on
    number       on
  ));
  $view_config->storable = 1;
}

sub form {
  my $view_config = shift;

  warn "FORM CALLED....";
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'exons',       'select' => 'select', 'label'  => 'Show exons' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'codons',      'select' => 'select', 'label'  => 'Show codons' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'codingseq',   'select' => 'select', 'label'  => 'Show coding sequence' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'translation', 'select' => 'select', 'label'  => 'Show protein sequence' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'rna',         'select' => 'select', 'label'  => 'Show RNA features' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'variation',   'select' => 'select', 'label'  => 'Show variation features' });
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'number',      'select' => 'select', 'label'  => 'Number residues' });

}
1;
