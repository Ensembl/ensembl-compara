=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Command::UserData::TrackHubRedirect;

use strict;

use EnsEMBL::Web::File::AttachedFormat::TRACKHUB;
use EnsEMBL::Web::Utils::UserData qw(check_attachment);
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $session       = $hub->session;
  my $url           = $hub->param('url');
     $url           =~ s/(^\s+|\s+$)//g; # Trim leading and trailing whitespace
  my $filename      = [split '/', $url]->[-1];
  my ($redirect, $anchor);
  my $params        = {};

  ## Allow for manually-created URLs with capitalisation, and 
  ## also validate any user-provided species name
  my $species       = $hub->param('species') || $hub->param('Species');
  if (!$species) {
    $species = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  }
  elsif (!$species_defs->valid_species($species)) {
    $redirect = '/trackhub_error.html';
    $params->{'species'}  = $species;
    $params->{'error'}    = 'unknown_species';
    $species              = undef;
  }

  if ($species) {
    if ($url) {
      my $new_action  = '';
      ($new_action, $params) = $hub->param('assembly_name') ? () : check_attachment($hub, $url);

      if ($new_action) {
        ## Hub is already attached, so just go there
        $redirect = sprintf('/%s/Location/View', $species);
        $anchor   = 'modal_config_viewbottom';
        if ($params->{'menu'}) {
          $anchor .= '-'.$params->{'menu'};
          delete $params->{'menu'};
        }
      }
      else {
        my $assembly_lookup = $species_defs->assembly_lookup;

        ## Does the URL include an assembly name (needed where there are multiple assemblies
        ## per species on a given site, eg. fungi)
        my $assembly_name = $hub->param('assembly_name');
        if ($assembly_name) {
          my $url = $assembly_lookup->{$assembly_name}[0];
          ## check that this looks like the right species
          if ($url =~ /^$species/) {
            $species = $url;
          }
        }

        ## Check if we have any supported assemblies
        my $trackhub = EnsEMBL::Web::File::AttachedFormat::TRACKHUB->new('hub' => $self->hub, 'url' => $url);
        my $hub_info = $trackhub->{'trackhub'}->get_hub({'assembly_lookup' => $assembly_lookup, 'parse_tracks' => 0});

        if ($hub_info->{'unsupported_genomes'}) {
          $redirect = '/trackhub_error.html';
          $params->{'error'}  = 'archive_only';
          $params->{'url'}    = $url;
          ## Get lookup that includes old assemblies
          my $lookup = $species_defs->assembly_lookup(1);
          foreach (@{$hub_info->{'unsupported_genomes'}||{}}) {
            my $info = $lookup->{$_};
            $params->{'species_'.$info->[0]} = $info->[1];
          }
        }
        else {
          ($new_action, $params) = $self->attach($trackhub, $filename); 

          ## Override standard redirect with sample location
          $redirect     = sprintf('/%s/Location/View', $species);
          if ($params->{'abort'}) {
            $params = {};
          }
          else {
            $redirect     = sprintf('/%s/Location/View', $species);
            $anchor       = 'modal_config_viewbottom';
            my $menu      = $params->{'menu'} || $params->{'name'};
            $anchor      .= '-'.$menu if $menu;
            delete($params->{'menu'});
            delete($params->{'name'});

            my %messages  = EnsEMBL::Web::Constants::USERDATA_MESSAGES;
            my $p         = $params->{'reattach'} || $params->{'species_flag'} 
                            || $params->{'assembly_flag'} || 'ok';
            my $key       = sprintf('hub_%s', $p);

            if ($messages{$key}) {
              ## Open control panel at Custom tracks if chosen species not supported
              if ($params->{'species_flag'} && $params->{'species_flag'} eq 'other_only') {
                $anchor = 'modal_user_data';
              }
              else {
                $hub->session->set_record_data({
                  type     => 'message',
                  code     => 'AttachURL',
                  message  => $messages{$key}{'message'},
                  function => '_'.$messages{$key}{'type'},
                });
              }
            }
          }
        }
        if ($redirect =~ /Location/) {
          ## Allow optional gene parameter to override the location
          if ($hub->param('gene')) {
            $params->{'g'} = $hub->param('gene');
            delete $params->{'r'};
          }
          else {
            my $location    = $hub->param('r') || $hub->param('location') || $hub->param('Location');
            unless ($location) {
              my $sample_links  = $species_defs->get_config($species, 'SAMPLE_DATA');
              $location         = $sample_links->{'LOCATION_PARAM'} if $sample_links;
            }
            $params->{'r'} = $location;
          }
        } else {
          $redirect           = '/trackhub_error.html';
          $params->{'error'}  = 'no_url';
        }
      }
    }
  }
  
  $self->ajax_redirect($redirect, $params, $anchor);  
}

1;
