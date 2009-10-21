package EnsEMBL::Web::ViewConfig::Transcript::Population;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  
  my $variations = $view_config->species_defs->databases->{'DATABASE_VARIATION'};
  
  $view_config->_set_defaults(qw(
    panel_image          on 
    context              100
    panel_transcript     on
    image_width          800
    reference),          ''
  );

  $view_config->_set_defaults('opt_pop_' . $_ => 'off') for @{$variations->{'DISPLAY_STRAINS'}};
  $view_config->_set_defaults('opt_pop_' . $_ => 'on')  for @{$variations->{'DEFAULT_STRAINS'}};
  $view_config->_set_defaults('opt_pop_' . $variations->{'REFERENCE_STRAIN'} => 'on');

  # Add source information if we have a variation database
  if ($variations) {
    foreach (keys %{$variations->{'tables'}{'source'}{'counts'}||{}}){
      my $name = 'opt_' . lc($_);
      $name =~ s/\s+/_/g;
      $view_config->_set_defaults($name => 'on');
    }
  }

  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $view_config->_set_defaults(lc($key) => $hash{$key}[0]);
    }
  }

  $view_config->has_images(1);
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $variations = $object->species_defs->databases->{'DATABASE_VARIATION'};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};

  # Add context selection
	$view_config->add_fieldset('Context');
  
	$view_config->add_form_element({
		type   => 'DropDown',
    select => 'select',
		name   => 'context',
		label  => 'Context',
	  values => [
	    { value => '20',   name => '20bp' },
	    { value => '50',   name => '50bp' },
	    { value => '100',  name => '100bp' },
	    { value => '200',  name => '200bp' },
	    { value => '500',  name => '500bp' },
	    { value => '1000', name => '1000bp' },
	    { value => '2000', name => '2000bp' },
	    { value => '5000', name => '5000bp' },
	    { value => 'FULL', name => 'Full Introns' }
	  ]
  });
  
  # Add source selection
  $view_config->add_fieldset('Variation source');
  
  foreach (sort keys %{$object->table_info('variation', 'source')->{'counts'}}) {
    my $name = 'opt_' . lc($_);
    $name =~ s/\s+/_/g;
    
    $view_config->add_form_element({
      'type'  => 'CheckBox', 
      'label' => $_,
      'name'  => $name,
      'value' => 'on',
      'raw'   => 1
    });
  }
  
  # Add class selection
  $view_config->add_fieldset('Variation class');
  
  foreach (keys %class) {
    $view_config->add_form_element({
      type  => 'CheckBox',
      label => $class{$_}[1],
      name  => lc($_),
      value => 'on',
      raw   => 1
    });
  }
  
  # Add type selection
  $view_config->add_fieldset('Variation type');
  
  foreach (keys %type) {
    $view_config->add_form_element({
      'type'  => 'CheckBox',
      'label' => $type{$_}[1],
      'name'  => lc($_),
      'value' => 'on',
      'raw'   => 1
    });
  }
  
  # Add Individual selection
  $view_config->add_fieldset('Selected individuals');
  
  my @strains = (@{$variations->{'DEFAULT_STRAINS'}}, @{$variations->{'DISPLAY_STRAINS'}}, $variations->{'REFERENCE_STRAIN'});
  my %seen;
  
  foreach (sort @strains) { 
    if (!exists $seen{$_}) {
      $view_config->add_form_element({
       'type'  => 'CheckBox',
       'label' => $_,
       'name'  => 'opt_pop_' . $_,
       'value' => 'on',
       'raw'   => 1
      });
      
      $seen{$_} = 1; 
    }
  }
  
  $view_config->has_images(0) if $object->function ne 'Image';
}

1;
