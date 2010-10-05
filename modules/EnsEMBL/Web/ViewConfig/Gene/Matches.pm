# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Matches;

use strict;

sub init {
  my $view_config = shift;
  my $help        = shift;
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
  
  my %defaults = map { default_on($_) ? ($_->{'name'} => 'yes') : () } get_xref_types($view_config->hub);
  
  $view_config->_set_defaults(%defaults);
}

sub form {
  my ($view_config, $object) = @_;
  
  foreach (sort { default_on($b) <=> default_on($a) } get_xref_types($view_config->hub)) {
    $view_config->add_form_element({
      type   => 'CheckBox',
      select => 'select',
      name   => $_->{'name'},
      label  => $_->{'name'},
      value  => 'yes'
    });
  }
}

sub get_xref_types {
  my $hub = shift;
  my @xref_types;
  
  foreach (split /,/, $hub->species_defs->XREF_TYPES) {
    my @type_priorities = split /=/;
    
	  push @xref_types, {
      name     => $type_priorities[0],
      priority => $type_priorities[1]
    };
  }
  
  return @xref_types;
}

sub default_on {
  my $value = shift;
  
  my %default_on = (
    'Ensembl Human Transcript' => 1, 
    'HGNC (curated)'           => 1, 
    'HGNC (automatic)'         => 1, 
    'EntrezGene'               => 1, 
    'CCDS'                     => 1, 
    'RefSeq RNA'               => 1, 
    'UniProtKB/ Swiss-Prot'    => 1, 
    'RefSeq peptide'           => 1, 
    'RefSeq DNA'               => 1, 
    'RFAM'                     => 1, 
    'miRBase'                  => 1, 
    'Vega transcript'          => 1, 
    'MIM disease'              => 1, 
    'MGI'                      => 1, 
    'MGI_curated_gene'         => 1, 
    'MGI_automatic_gene'       => 1, 
    'MGI_curated_transcript'   => 1, 
    'MGI_automatic_transcript' => 1, 
    'ZFIN_ID'                  => 1,
    'Projected HGNC'           => 1
  );
  
  return $default_on{$value->{'name'}};
}

1;
