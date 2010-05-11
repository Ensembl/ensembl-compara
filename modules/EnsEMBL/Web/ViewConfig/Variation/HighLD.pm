package EnsEMBL::Web::ViewConfig::Variation::HighLD;

use strict;

sub init {
  my ($view_config) = @_;
  my $variations = $view_config->species_defs->databases->{'DATABASE_VARIATION'}||{};
  
  #$view_config->_set_defaults($variations->{DEFAULT_LD_POP}, 'yes') if $variations->{DEFAULT_LD_POP};
  $view_config->_set_defaults($_, 'yes') foreach @{$view_config->species_defs->databases->{'DATABASE_VARIATION'}->{'LD_POPULATIONS'}};

  $view_config->_set_defaults(qw(
    max_distance          50000
    min_r2                0.8
    min_d_prime           0.8
    only_phenotypes       no
    min_p_log             0
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  # Add selection
  $view_config->add_fieldset('Thresholds');
  
  # max distance
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'max_distance',
    label  => 'Maximum distance between variations',
    values => [
      { value => '10000',  name => '10kb' },
      { value => '20000',  name => '20kb' },
      { value => '50000', name => '50kb' },
      { value => '100000', name => '100kb' },
      { value => '500000', name => '500kb' }
    ]
  });
  
  # min r2
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_r2',
    label  => 'Minimum r^2 value',
    values => [
      { value => '0',  name => '0' },
      { value => '0.1',  name => '0.1' },
      { value => '0.2',  name => '0.2' },
      { value => '0.3',  name => '0.3' },
      { value => '0.4',  name => '0.4' },
      { value => '0.5',  name => '0.5' },
      { value => '0.6',  name => '0.6' },
      { value => '0.7',  name => '0.7' },
      { value => '0.8',  name => '0.8' },
      { value => '0.9',  name => '0.9' },
      { value => '1',  name => '1' },
    ]
  });
  
  # min d_prime
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_d_prime',
    label  => 'Minimum D\' value',
    values => [
      { value => '0',  name => '0' },
      { value => '0.1',  name => '0.1' },
      { value => '0.2',  name => '0.2' },
      { value => '0.3',  name => '0.3' },
      { value => '0.4',  name => '0.4' },
      { value => '0.5',  name => '0.5' },
      { value => '0.6',  name => '0.6' },
      { value => '0.7',  name => '0.7' },
      { value => '0.8',  name => '0.8' },
      { value => '0.9',  name => '0.9' },
      { value => '1',  name => '1' },
    ]
  });
  
  # populations
  $view_config->add_fieldset("Populations");
  
  my $pa = $object->vari->adaptor->db->get_PopulationAdaptor;
  my @pops = @{$pa->fetch_all_LD_Populations};

  foreach (sort {$a->name cmp $b->name} @pops) {
    $view_config->add_form_element({
      type  => 'CheckBox', 
      label => $_->name,
      name  => $_->name,
      value => 'yes',
      raw   => 1
    });
  }
  
  # other options
  $view_config->add_fieldset("Phenotype options");
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Only display variations associated with phenotypes',
    name  => 'only_phenotypes',
    value => 'yes',
    raw   => 1,
  });
  
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'min_p_log',
    label  => 'Minimum p-value (-log10) of associated phenotypes',
    values => [
      { value => '0',  name => '0 (show all)' },
      { value => '1',  name => '1' },
      { value => '2',  name => '2' },
      { value => '3',  name => '3' },
      { value => '4',  name => '4' },
      { value => '5',  name => '5' },
      { value => '6',  name => '6' },
      { value => '7',  name => '7' },
      { value => '8',  name => '8' },
      { value => '9',  name => '9' },
      { value => '10',  name => '10' },
      { value => '20',  name => '20' },
    ]
  });
}
1;
