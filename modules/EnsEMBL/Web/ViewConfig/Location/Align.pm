package EnsEMBL::Web::ViewConfig::Location::Align;

use strict;

use EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

sub init { 
  my $view_config = shift;
  
  EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::init($view_config);
  
  $view_config->_set_defaults(qw(panel_top yes));
  
  $view_config->add_image_configs({qw(
    contigviewtop        nodas
    alignsliceviewbottom nodas
  )});
  
  $view_config->default_config = 'alignsliceviewbottom';
  $view_config->storable       = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_top',  'select' => 'select', 'label'  => 'Show overview panel' });
  
  EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::form($view_config, $object, 1);
}
1;
