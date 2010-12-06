package EnsEMBL::Web::ViewConfig::Transcript::Exons;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_exons       on
    panel_supporting  on
    sscon             25
    seq_cols          60
    flanking          50
    fullseq           no
    oexon             no
    variation         off
    population_filter off
    min_frequency     0.1
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
    
  $view_config->add_form_element({
    type  => 'NonNegInt',
    label => 'Flanking sequence at either end of transcript',
    name  => 'flanking'
  });
  
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'seq_cols',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, name => "$_ bps" }} map $_*15, 2..8
    ]
  });
  
  $view_config->add_form_element({
    type  => 'NonNegInt',
    label => 'Intron base pairs to show at splice sites', 
    name  => 'sscon'
  });
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Show full intronic sequence',
    name  => 'fullseq',
    value => 'yes'
  });
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Show exons only',
    name  => 'oexon',
    value => 'yes'
  });
  
  if ($object->species_defs->databases->{'DATABASE_VARIATION'}) {
    $view_config->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'variation',
      label  => 'Show variation features',
      values => [
        { value => 'off',  name => 'No'            },
        { value => 'on',   name => 'Yes'           },
        { value => 'exon', name => 'In exons only' },
      ]
    });
    
    my $populations = $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {
      my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $view_config->add_form_element($general_markup_options{'pop_filter'});
      $view_config->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  $_->{$view_config->SELECT_ALL_FLAG} = 1 for @{$view_config->get_form->fieldsets};
}

1;
