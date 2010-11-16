# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Matches;

use strict;

sub init {
  my $view_config = shift;
  my $help        = shift;
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
  
  my %defaults = map { default_on($_) ? ($_->{'name'} => 'yes') : ($_->{'name'} => 'off') } get_xref_types($view_config->hub);
  
  $view_config->_set_defaults(%defaults);
}

sub form {
  my ($view_config, $object) = @_;
  
  foreach (sort { default_on($a) <=> default_on($b) } get_xref_types($view_config->hub)) {
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
    'HGNC (curated)'           => 2, 
    'HGNC (automatic)'         => 3, 
    'EntrezGene'               => 4, 
    'CCDS'                     => 5, 
    'RefSeq RNA'               => 6, 
    'UniProtKB/ Swiss-Prot'    => 7, 
    'RefSeq peptide'           => 8, 
    'RefSeq DNA'               => 9, 
    'RFAM'                     => 10, 
    'miRBase'                  => 11, 
    'Vega transcript'          => 12, 
    'MIM disease'              => 13, 
    'MGI'                      => 14, 
    'MGI_curated_gene'         => 15, 
    'MGI_automatic_gene'       => 16, 
    'MGI_curated_transcript'   => 17, 
    'MGI_automatic_transcript' => 18, 
    'ZFIN_ID'                  => 19,
    'Projected HGNC'           => 20
  );
  if (defined($default_on{$value->{'name'}})){
    return $default_on{$value->{'name'}};
  }else{
    return 100;
  }  
  return ;
}

1;
