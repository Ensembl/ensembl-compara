package EnsEMBL::Web::ViewConfig::Transcript::Population;

use strict;


my %validation = (
  'opt_freq'      =>  ['on', 'By frequency'],
  'opt_cluster'   =>  ['on', 'By Cluster'],
  'opt_doublehit' =>  ['on', 'By doublehit'],
  'opt_submitter' =>  ['on', 'By submitter'],
  'opt_hapmap'    =>  ['on', 'Hapmap'],
  'opt_noinfo'    =>  ['on', 'No information'],
);

my %class = (
  'opt_in-del'    =>  ['on', 'In-dels'],
  'opt_snp'       =>  ['on', 'SNPs'],
  'opt_mixed'     =>  ['on', 'Mixed variations'],
  'opt_microsat'  =>  ['on', 'Micro-satellite repeats'], 
  'opt_named'     =>  ['on', 'Named variations'],
  'opt_mnp'       =>  ['on', 'MNPs'],
  'opt_het'       =>  ['on', 'Hetrozygous variations'],
  'opt_'          =>  ['on', 'Unclassified']
);

my %type = (
  'opt_non_synonymous_coding' =>  ['on', 'Non-synonymous'],
  'opt_frameshift_coding'     =>  ['on', 'Frameshift'],
  'opt_synonymous_coding'     =>  ['on', 'Synonymous'],
  'opt_5prime_utr'            =>  ['on', "5' UTR"],
  'opt_3prime_utr'            =>  ['on', "3' UTR"],
  'opt_intronic'              =>  ['on', 'Intronic'],
  'opt_downstream'            =>  ['on', 'Downstream'],
  'opt_upstream'              =>  ['on', 'Upstream'],
  'opt_intergenic'            =>  ['on', 'Intergenic'],
  'opt_essential_splice_site' =>  ['on', 'Essential splice site'],
  'opt_splice_site'           =>  ['on', 'Splice site'],
  'opt_regulatory_region'     =>  ['on', 'Regulatory region'],
  'opt_stop_gained'           =>  ['on', 'Stop gained'],
  'opt_stop_lost'             =>  ['on', 'Stop lost'],
  'opt_sara'                  =>  ['on', 'SARA (same as ref.assembly)']
);

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_image          on 
    context              100
    panel_transcript     on
    image_width          800
    reference            ),'',qw(
  ));

  

  foreach ( @{$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'DISPLAY_STRAINS'}}){
    $view_config->_set_defaults( 'opt_pop_'.$_  =>  'off');
  }
  foreach ( @{$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'DEFAULT_STRAINS'}}){  
    $view_config->_set_defaults( 'opt_pop_'.$_  =>  'on');
  }
  $view_config->_set_defaults('opt_pop_'.$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'REFERENCE_STRAIN'} => 'off');

  ### Add source information if we have a variation database
  my $T = $view_config->species_defs->databases->{'DATABASE_VARIATION'};
  if( $T ) {
    my @sources = keys %{$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'tables'}{'source'}{'counts'} || {} };
    foreach (@sources){
      my $name = 'opt_'.lc($_);
      $name =~s/\s+/_/g;
      $view_config->_set_defaults($name  => 'on');
    }
  }

  ## Add other options 
  my @options = (\%validation, \%class, \%type); 

  foreach (@options){
    my %hash = %$_;
    foreach my $key (keys %hash){
     $view_config->_set_defaults(lc($key) =>  $hash{$key}[0]);
    }
  }

  $view_config->add_image_configs({qw(
    tsv_context          nodas
    tsv_transcript       nodas
    tsv_sampletranscript nodas
  )});
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;
 
  ### Add source selection
  $view_config->add_fieldset('Select Variation Source');
  my $t = $object->table_info( 'variation', 'source' );
  my @sources = keys %{$t->{'counts'}};
  foreach (sort @sources){
    my $name = 'opt_'.lc($_);
    $name =~s/\s+/_/g;
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $_,
      'name'     => $name,
      'value'    => 'on', 'raw' => 1
    });
  }
  ### Add class selection
  $view_config->add_fieldset('Select Variation Class');
  foreach( keys %class ) {
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $class{$_}[1],
      'name'     => lc($_),
      'value'    => 'on', 'raw' => 1
    });
  }
  ### Add type selection
  $view_config->add_fieldset('Select Variation Type');
  foreach( keys %type ) {
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $type{$_}[1],
      'name'     => lc($_),
      'value'    => 'on', 'raw' => 1
    });
  }
  ### Add Individual selection
  $view_config->add_fieldset('Select Individuals');
  foreach (@{$object->species_defs->databases->{'DATABASE_VARIATION'}->{'DEFAULT_STRAINS'}}){
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $_,
      'name'     =>  'opt_pop_'.$_,
      'value'    => 'on', 'raw' => 1
    });
  }
  foreach (@{$object->species_defs->databases->{'DATABASE_VARIATION'}->{'DISPLAY_STRAINS'}}){
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $_,
      'name'     =>  'opt_pop_'.$_,
      'value'    => 'on', 'raw' => 1
    });
  }
  $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'REFERENCE_STRAIN'},
      'name'     =>  'opt_pop_'.$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'REFERENCE_STRAIN'},
      'value'    => 'on', 'raw' => 1
  });
  ### Add context selection
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'context',
    'label'    => 'Context',
    'values'   => [
      { 'value' => '20',   'name' => '20bp' },
      { 'value' => '50',   'name' => '50bp' },
      { 'value' => '100',  'name' => '100bp' },
      { 'value' => '200',  'name' => '200bp' },
      { 'value' => '500',  'name' => '500bp' },
      { 'value' => '1000', 'name' => '1000bp' },
      { 'value' => '2000', 'name' => '2000bp' },
      { 'value' => '5000', 'name' => '5000bp' },
      { 'value' => 'FULL', 'name' => 'Full Introns' },
    ]
  });
}


1;
