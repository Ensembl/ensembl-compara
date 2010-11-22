package EnsEMBL::Web::ViewConfig::Gene::Compara_Paralog;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    image_width          800
    width                800
    seq                  Protein
    text_format          clustalw
    scale                150
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $view_config->add_fieldset('Aligment output');
  $view_config->add_form_element({
    type   => 'DropDown', 
    select => 'select',   
    name   => 'seq',
    label  => 'View as cDNA or Protein',
    values => [ map {{ value => $_, name => $_ }} qw(cDNA Protein) ]
  });

  $view_config->add_form_element({
    type   => 'DropDown', 
    select => 'select',   
    name   => 'text_format',
    label  => 'Output format for sequence alignment',
    values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
  });
}

1;
