=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Regulation::EvidenceSelector;

use strict;

use base qw(EnsEMBL::Web::Component::CloudMultiSelector EnsEMBL::Web::Component::Regulation);

use EnsEMBL::Web::Tools::ExoticSorts qw(id_sort);

use List::MoreUtils qw(uniq);

sub _init {
  my $self = shift;
 
  $self->SUPER::_init;
 
  $self->{'panel_type'}      = 'EvidenceSelector';
  $self->{'link_text'}       = 'Select evidence';
  $self->{'included_header'} = '{category}';
  $self->{'excluded_header'} = '{category}';
  $self->{'url_param'}       = 'evidence';
  $self->{'rel'}             = 'modal_select_evidence';
}

sub content_ajax {
  my $self        = shift;
  my $hub         = $self->hub;
  my $params      = $hub->multi_params; 

  my $context       = $self->hub->param('context') || 200;
  my $all_evidences = $self->all_evidences->{'all'};

  my %all_options = map { $_ => $_ } keys %$all_evidences;
  my @inc_options = grep { $all_evidences->{$_}{'on'} } keys %$all_evidences;
  my %inc_options;
  $inc_options{$inc_options[$_]} = $_+1 for(0..$#inc_options);
  my %evidence_categories = map { $_ => $all_evidences->{$_}{'group'} } keys %$all_evidences;
  my %evidence_clusters = map { $_ => $all_evidences->{$_}{'cluster'} } keys %$all_evidences;
  $self->{'categories'} = [ uniq(values %evidence_categories) ];


  $self->{'all_options'}      = \%all_options;
  $self->{'included_options'} = \%inc_options;
  $self->{'param_mode'} = 'single';
  $self->{'category_map'} = \%evidence_categories;
  $self->{'cluster_map'} = \%evidence_clusters;
  $self->{'sort_func'} = \&id_sort;
  $self->{'extra_params'} = { image_config => $hub->param('image_config') };

  $self->SUPER::content_ajax;
}

1;
