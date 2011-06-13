
package EnsEMBL::Web::ViewConfig::LRG::ProteinSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons             => 'yes',
    display_width     => 60,
    variation         => 'no',
    population_filter => 'off',
    min_frequency     => 0.1,
    number            => 'no'
  });
}

sub form {
  my $self = shift;

  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'display_width',
    label  => 'Number of amino acids per row',
    values => [
      map {{ value => $_, name => "$_ aa" }} map 10*$_, 3..20
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'exons', select => 'select', label => 'Show exons' });
  
  if ($self->species_defs->databases->{'DATABASE_VARIATION'}) {
    $self->add_form_element({ type => 'YesNo', name => 'variation', select => 'select', label => 'Show variation features' });
    
    my $pa = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation');
    my $populations = $pa->fetch_all_HapMap_Populations;
    push @$populations, @{$pa->fetch_all_1KG_Populations};
    
    if (scalar @$populations) {
      my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $self->add_form_element($general_markup_options{'pop_filter'});
      $self->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $self->add_form_element({ type => 'YesNo', name => 'number',    select => 'select', label => 'Number residues' });
}

1;
