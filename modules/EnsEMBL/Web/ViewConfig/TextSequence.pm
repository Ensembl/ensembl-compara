# $Id$

package EnsEMBL::Web::ViewConfig::TextSequence;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    display_width      => 60,
    population_filter  => 'off',
    min_frequency      => 0.1,
    consequence_filter => 'off',
  });
}

sub variation_options {
  my ($self, $options) = @_;
  my $hub    = $self->hub;
  my %markup = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  
  push @{$markup{'snp_display'}{'values'}}, { value => 'snp_link', name => 'Yes and show links' } unless $options->{'snp_link'} eq 'no';
  push @{$markup{'snp_display'}{'values'}}, @{$options->{'snp_display'}} if $options->{'snp_display'};
  
  $self->add_form_element($markup{'snp_display'});
  
  if ($options->{'consequence'} ne 'no') {
    my %consequence_types = map { $_->label ? ($_->label => $_->display_term) : () } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
    
    push @{$markup{'consequence_filter'}{'values'}}, map { name => $_, value => $consequence_types{$_} }, sort keys %consequence_types;
    
    $self->add_form_element($markup{'consequence_filter'});
  }
  
  # Population filtered variations currently fail to return in a reasonable time
#  if ($options->{'populations'}) {
#    my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation'); 
#    my @populations = map @{$pop_adaptor->$_}, @{$options->{'populations'}};
#    
#    if (scalar @populations) {
#      push @{$markup{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @populations;
#      
#      $self->add_form_element($markup{'pop_filter'});
#      $self->add_form_element($markup{'pop_min_freq'});
#    }
#  }
}

1;
