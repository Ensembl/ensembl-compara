=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Command::UserData::AttachDAS;

use strict;

use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use EnsEMBL::Web::Filter::DAS;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $session = $hub->session;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';
  my $server  = $hub->param('das_server');
  my $params  = {};
  
  if ($server) {
    my $filter  = EnsEMBL::Web::Filter::DAS->new({ object => $object });
    my $sources = $filter->catch($server, $hub->param('logic_name'));
    
    if ($filter->error_code) {
      $url .= 'SelectDAS';
      $params->{'filter_module'} = 'DAS';
      $params->{'filter_code'}   = $filter->error_code;
    } else {
      my (@success, @skipped);
      
      foreach my $source (@$sources) {
        # Fill in missing coordinate systems
        if (!scalar @{$source->coord_systems}) {
          my @expand_coords = grep $_, $hub->param($source->logic_name . '_coords');
          
          if (scalar @expand_coords) {
            @expand_coords = map Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_), @expand_coords;
            $source->coord_systems(\@expand_coords);
          } else {
            $params->{'filter_module'} = 'DAS';
            $params->{'filter_code'}   = 'no_coords';
          }
        }

        # NOTE: at present the interface only allows adding a source that has not
        # already been added (by disabling their checkboxes). Thus this call
        # should always evaluate true at present.
        if ($session->add_das($source)) {
          push @success, $source->logic_name;
        } else {
          push @skipped, $source->logic_name;
        }
        
        $session->configure_das_views($source); # Turn the source on
      }
      
      $session->save_das;
      $session->store;
      
      $url .= 'DasFeedback';
      $params->{'added'}   = \@success;
      $params->{'skipped'} = \@skipped;
    }
  } else {
    $url .= 'SelectDAS';
    $params->{'filter_module'} = 'DAS';
    $params->{'filter_code'}   = 'no_server';
  }
  
  $self->ajax_redirect($url, $params);
}

1;
