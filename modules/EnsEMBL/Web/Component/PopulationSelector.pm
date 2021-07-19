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

package EnsEMBL::Web::Component::PopulationSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  my $hub = $self->hub;

  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select populations';
  $self->{'included_header'} = 'Selected Populations';
  $self->{'excluded_header'} = 'Unselected Populations';
  $self->{'url_param'}       = 'pop';
  $self->{'rel'}             = 'modal_select_populations';

  # if referer_action param exists then get action from it else get it from hub itself
  # referer_action will be used by the view configs while action itself is usually used if a user selects select population directly from the sidebar
  $self->{'url'} = $hub->url({ action => ($hub->param('referer_action') || $hub->action) }, 1);
}

sub content_ajax {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $params      = $hub->multi_params; 
  my $length      = $object->Obj->{'seq_region_length'};
  my $slice       = $hub->database('core')->get_SliceAdaptor->fetch_by_region($object->seq_region_type, $object->seq_region_name, 1, $length, 1);
  my $ld_adaptor  = $hub->database('variation')->get_LDFeatureContainerAdaptor;
  my $pop_adaptor = $hub->database('variation')->get_PopulationAdaptor;
  my $populations = $ld_adaptor->get_populations_hash_by_Slice($slice);
#  my %shown       = map { $params->{"pop$_"} => $_ } grep s/^pop(\d+)$/$1/, keys %$params;
  my %shown;

  # Manual parameter (from external URL)
  my %pop_params = map { $_ => $params->{"pop$_"}} grep s/^pop(\d+)$/$1/, keys %$params;
  foreach my $id (sort{$a <=> $b} keys %pop_params) {
    my $pop_data = $pop_params{$id};
    if ($pop_data =~ /^\d+$/) {
      $shown{$pop_data} = $id;
    }
    else {
      my $pop = $pop_adaptor->fetch_by_name($pop_data);
      # Population name found in DB
      if ($pop) {
        my $pop_id = $pop->dbID();
        # Check if population already selected and if population has LD data
        if (!grep {$pop_id eq $_} keys(%pop_params) && $populations->{$pop_id}) {
          $shown{$pop_id} = $id;
          
        }
      }
    }
  }
  $self->{'all_options'}      = $populations;
  $self->{'included_options'} = \%shown;

  $self->SUPER::content_ajax;
}

1;
