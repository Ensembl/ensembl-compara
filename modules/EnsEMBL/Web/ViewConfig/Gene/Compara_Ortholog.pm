package EnsEMBL::Web::ViewConfig::Gene::Compara_Ortholog;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Constants;

sub init {
  my $view_config = shift;
  
  $view_config->_set_defaults(qw(
      image_width 800
      width       800
      seq         Protein
      text_format clustalw
      scale       150
    ),
    map { 'species_' . lc($_) => 'yes' } $view_config->species_defs->valid_species
  );
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $view_config->add_fieldset('Aligment output options');
  
  $view_config->add_form_element({
    'type'     => 'DropDown', 
    'select'   => 'select',
    'required' => 'yes',      
    'name'     => 'seq',
    'label'    => 'View as cDNA or Protein',
    'values'   => [ map {{ 'value' => $_, 'name' => $_ }} qw(cDNA Protein) ]
  });
  
  $view_config->add_form_element({
    'type'     => 'DropDown', 
    'select'   => 'select',
    'required' => 'yes',      
    'name'     => 'text_format',
    'label'    => 'Output format for sequence alignment',
    'values'   => [ map {{ 'value' => $_, 'name' => $formats{$_} }} sort keys %formats ]
  });
  
  $view_config->add_fieldset('Show alignments from the following species');
  
  my %species = map { $view_config->_species_label($_) => $_ } $view_config->species_defs->valid_species;
  
  foreach (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %species) {
    $view_config->add_form_element({
      'type'  => 'CheckBox', 
      'label' => $_,
      'name'  => 'species_' . lc $species{$_},
      'value' => 'yes',
      'raw'   => 1
    });
  }
}

1;
