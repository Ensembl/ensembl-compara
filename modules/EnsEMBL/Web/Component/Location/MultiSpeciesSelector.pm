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

package EnsEMBL::Web::Component::Location::MultiSpeciesSelector;

use strict;
use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::TaxonSelector);

sub _init {
  my $self = shift;
  my $hub = $self->hub;
  $self->SUPER::_init;
  $self->{'link_text'} = 'Select species or regions';
  $self->{'url_param'} = 's';
  $self->{'rel'}       = 'modal_select_species_or_regions';
  my $params           = { function => undef };
  $params->{'action'}  = $hub->param('referer_action') if $hub->param('referer_action');
  $self->{'action'}    = $hub->url($params);
  my %seen;
  my $params = $hub->referer->{'params'};
  my @species_list = grep !$seen{$_}++, sort { $a <=> $b } map { /^s(\d+)$/ ? $params->{"s$1"} : () } keys %$params;
  $self->{'default_species'} = \@species_list;
}

sub buttons {
  my $self = shift;
  my $class = $self->hub->param("$self->{'url_param'}1") ? '' : 'pulse';
  return {
    'url'     => $self->ajax_url('ajax', {multiselect => 1, referer_action => $self->hub->action}),
    'caption' => $self->{'link_text'},
    'class'   => 'config _species_selector ' . $class,
    'modal'   => 1,
    'rel'     => $self->{'rel'}
  };
}

1;
