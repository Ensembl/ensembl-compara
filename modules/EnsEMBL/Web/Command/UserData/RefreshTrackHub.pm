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

package EnsEMBL::Web::Command::UserData::RefreshTrackHub;

## Re-parse a trackhub's configuration files 

use strict;

use List::Util qw(first);

use EnsEMBL::Web::Utils::TrackHub; 

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  my $url_params      = {};
  my $session_record  = $hub->session->get_data('code' => $hub->param('code'), 'type' => 'url');
 
  my $trackhub  = EnsEMBL::Web::Utils::TrackHub->new('hub' => $hub, 'url' => $session_record->{'url'});
  ## Don't validate assembly - if we're reattaching, it must by definition be OK
  ## (unless it's been changed radically, in which case all bets are off!)
  my $hub_info = $trackhub->get_hub({
                                      'parse_tracks'    => 1,
                                      'refresh'         => 1,
                                    });

  $url_params->{ __clear} = 1;
  $url_params->{'action'} = 'ManageData';

  if ($hub_info->{'error'}) {
    $hub->session->set_record_data({
      type     => 'message',
      code     => 'trackhub_refresh_error',
      message  => "Sorry, we were unable to refresh your trackhub at this time. Please check the hub site and try again later.", 
      function => '_error'
    });
  }

  return $self->ajax_redirect($self->hub->url($url_params));
}

1;
