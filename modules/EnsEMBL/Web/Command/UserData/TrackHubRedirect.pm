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

package EnsEMBL::Web::Command::UserData::TrackHubRedirect;

use strict;

use EnsEMBL::Web::File::AttachedFormat::TRACKHUB;
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
  my @bits          = split /\./, $filename;
  my $extension     = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
  my $pattern       = "^$extension\$";
  my ($redirect, $anchor);
  my $params        = {};

  ## Allow for manually-created URLs with capitalisation, and 
  ## also validate any user-provided species name
  my $species       = $hub->param('species') || $hub->param('Species');
  if (!$species) {
    $species = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  }
  elsif (!$hub->species_defs->valid_species($species)) {
    $redirect = '/info/website/trackhub_error.html';
    $params->{'species'}  = $species;
    $params->{'error'}    = 'unknown_species';
    $species              = undef;
  }

  if ($species) {
    my $location    = $hub->param('r') || $hub->param('location') || $hub->param('Location');

    $redirect       = $hub->species_path($species) . '/UserData/';
    $anchor         = 'modal_config_viewbottom';
    my $new_action  = '';

    if ($url) {
      ## Is this file already attached?
      ($new_action, $params)  = $self->check_attachment($url);

      unless ($new_action) {
        my $trackhub = EnsEMBL::Web::File::AttachedFormat::TRACKHUB->new('hub' => $self->hub, 'url' => $url);
     
        ($new_action, $params) = $self->attach($trackhub, $filename); 
      }

      ## Override standard redirect with sample location
      $redirect           = sprintf('/%s/Location/View', $species);
      unless ($location) {
        my $sample_links  = $species_defs->get_config($species, 'SAMPLE_DATA');
        $location         = $sample_links->{'LOCATION_PARAM'} if $sample_links;
      }
      $params->{'r'} = $location;

      my %messages  = EnsEMBL::Web::Constants::USERDATA_MESSAGES;
      my $p         = $params->{'reattach'} || $params->{'species_flag'} 
                        || $params->{'assembly_flag'} || 'ok';
      my $key       = sprintf('hub_%s', $p);

      if ($messages{$key}) {
        $anchor = 'modal_user_data' unless $p eq 'ok';
        $hub->session->add_data(
          type     => 'message',
          code     => 'AttachURL',
          message  => $messages{$key}{'message'},
          function => '_'.$messages{$key}{'type'},
        );
      }
    } else {
      $session->add_data(
        type     => 'message',
        code     => 'AttachURL',
        message  => 'No URL was provided',
        function => '_error'
      );
      $redirect .= 'SelectFile';
    }
  }
  
  $self->ajax_redirect($redirect, $params, $anchor);  
}

1;
