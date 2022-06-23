=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
  my $new_action    = '';

  ## Allow for manually-created URLs with capitalisation, and 
  ## also validate any user-provided species name
  my $species = $hub->param('species') || $hub->param('Species');
  if (!$url) {
    $redirect           = '/trackhub_error.html';
    $params->{'error'}  = 'no_url';
    $species            = undef;
  }
  elsif ($species && !$species_defs->valid_species($species)) {
    $redirect = '/trackhub_error.html';
    $params->{'species'}  = $species;
    $params->{'error'}    = 'unknown_species';
    $species              = undef;
  } 
  else {
    ## Sanity check to see if we're already attached this hub
    ($new_action, $params) = $hub->param('assembly_name') ? () : check_attachment($hub, $url);

    if ($new_action) {
      $species = delete $params->{'species'}; 
      ## Just in case we don't have a species, fall back to primary
      $species ||= $species_defs->ENSEMBL_PRIMARY_SPECIES;

      $redirect = sprintf('/%s/Location/View', $species);
      $anchor   = 'modal_config_viewbottom';
      if ($params->{'menu'}) {
        $anchor .= '-'.$params->{'menu'};
        delete $params->{'menu'};
      }
    }
    else {
      my $trackhub        = EnsEMBL::Web::File::AttachedFormat::TRACKHUB->new('hub' => $self->hub, 'url' => $url);
      ## When attaching hub, only analyse current assemblies
      my $assembly_lookup = $species_defs->assembly_lookup;
      my $hub_info        = $trackhub->{'trackhub'}->get_hub({'assembly_lookup' => $assembly_lookup, 'parse_tracks' => 0});
  
      if ($hub_info->{'unsupported_genomes'}) {
        ## This should only be triggered if there are no genomes in the hub that are
        ## compatible with this site - see E::W::Utils::Trackhub::get_hub_internal 
        $redirect = '/trackhub_error.html';
        $params->{'error'}  = 'archive_only';
        $params->{'url'}    = $url;
        ## Get version of lookup that includes old assemblies
        my $lookup = $species_defs->assembly_lookup(1);
        foreach (@{$hub_info->{'unsupported_genomes'}||{}}) {
          my $info = $lookup->{$_};
          $params->{'species_'.$info->[0]} = $info->[1];
        }       
      }
      else {
        ($new_action, $params) = $self->attach($trackhub, $filename); 

        if ($params->{'error'}) {
          $redirect = '/trackhub_error.html';
          $hub->session->set_record_data({
            type     => 'message',
            code     => 'HubAttachError',
            message  => $params->{'error'}, 
          });
          $params->{'error'}  = 'other';
        }
        else {

          ## Get first species if none has been provided
          unless ($species) {
            my @genomes         = keys %{$hub_info->{'genomes'}||{}};
            my $first_genome    = $genomes[0];
          
            if ($first_genome) {

              foreach ($species_defs->valid_species) {
                if ($species_defs->get_config($_, 'ASSEMBLY_NAME') eq $first_genome || $species_defs->get_config($_, 'ASSEMBLY_VERSION') eq $first_genome) {
                  $species = $_;
                  last;
                }
              }
            }
          }

          ## Final sanity check that we do have a species!
          if ($species) {

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

            ## Override standard redirect with sample location
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
          else {
            $redirect = '/trackhub_error.html';
            $params->{'error'}    = 'unknown_species';
          }
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
  }
  
  $self->ajax_redirect($redirect, $params, $anchor);  
}

1;
