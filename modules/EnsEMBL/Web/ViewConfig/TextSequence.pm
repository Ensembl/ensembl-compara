=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
    title_display      => 'off',
    hide_long_snps     => 'yes',
  });
}

sub variation_options {
  my ($self, $options) = @_;
  my $hub    = $self->hub;
  my %markup = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  
  $markup{'snp_display'}{'label'} = $options->{'label'} if $options->{'label'};
  
  push @{$markup{'snp_display'}{'values'}}, { value => 'snp_link', caption => 'Yes and show links' } unless $options->{'snp_link'} eq 'no';
  push @{$markup{'snp_display'}{'values'}}, @{$options->{'snp_display'}} if $options->{'snp_display'};
  
  $self->add_form_element($markup{'snp_display'});
  $self->add_form_element($markup{'hide_long_snps'});
  
  if ($options->{'consequence'} ne 'no') {
    my %consequence_types = map { $_->label && $_->feature_class =~ /transcript/i ? ($_->label => $_->SO_term) : () } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
    
    push @{$markup{'consequence_filter'}{'values'}}, map { value => $consequence_types{$_}, caption => $_ }, sort keys %consequence_types;
    
    $self->add_form_element($markup{'consequence_filter'});
  }
  
  # Population filtered variations currently fail to return in a reasonable time
#  if ($options->{'populations'}) {
#    my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation'); 
#    my @populations = map @{$pop_adaptor->$_}, @{$options->{'populations'}};
#    
#    if (scalar @populations) {
#      push @{$markup{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, caption => $_->name }} @populations;
#      
#      $self->add_form_element($markup{'pop_filter'});
#      $self->add_form_element($markup{'pop_min_freq'});
#    }
#  }
}

1;
