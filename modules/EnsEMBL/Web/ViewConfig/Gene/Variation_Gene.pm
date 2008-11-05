package EnsEMBL::Web::ViewConfig::Gene::Variation_Gene;

use strict;
use EnsEMBL::Web::Constants;

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
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  foreach (keys %options){
    my %hash = %{$options{$_}};
    foreach my $key (keys %hash){
     $view_config->_set_defaults(lc($key) =>  $hash{$key}[0]);
    }
  }

  $view_config->add_image_configs({qw(
    genesnpview_gene            nodas  
    genesnpview_transcript      nodas
  )});

  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my  %class  = %{$options{'class'}};
  my  %type = %{$options{'type'}};

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
  ### Add Validation selection
  $view_config->add_fieldset('Select Validation');
  foreach (keys %validation){
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $validation{$_}[1],
      'name'     =>  lc($_),
      'value'    => 'on', 'raw' => 1
    });
  }
  ### Add type selection
  $view_config->add_fieldset('Select Variation Type');
  foreach( keys %type ) {
    if ($_ eq 'opt_sara') { next;}
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $type{$_}[1],
      'name'     => lc($_),
      'value'    => 'on', 'raw' => 1
    });
  }
  ### Add context selection
  $view_config->add_fieldset('Context');
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
