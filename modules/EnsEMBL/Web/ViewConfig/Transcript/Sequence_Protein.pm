package EnsEMBL::Web::ViewConfig::Transcript::Sequence_Protein;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons             yes
    display_width     60
    variation         no
    population_filter off
    min_frequency     0.1
    number            no
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'display_width',
    label  => 'Number of amino acids per row',
    values => [
      map {{ value => $_, name => "$_ aa" }} map 10*$_, 3..20
    ]
  });
  
  $view_config->add_form_element({ type => 'YesNo', name => 'exons', select => 'select', label => 'Show exons' });
  
  if ($object->species_defs->databases->{'DATABASE_VARIATION'}) {
    $view_config->add_form_element({ type => 'YesNo', name => 'variation', select => 'select', label => 'Show variation features' });
    
    my $populations = $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {
      my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $view_config->add_form_element($general_markup_options{'pop_filter'});
      $view_config->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $view_config->add_form_element({ type => 'YesNo', name => 'number',    select => 'select', label => 'Number residues' });
}

1;
