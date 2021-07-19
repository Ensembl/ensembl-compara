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

package EnsEMBL::Web::Command::UserData::FlipTrack;

## Flip a track's status between on (1) and off (0)

use strict;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  my $disconnect = $hub->param('disconnect');
  my $flipped = $self->object->flip_records([$hub->param('record')], $disconnect);

  unless ($flipped) {
    my $message;
    if ($hub->param('format') eq 'TRACKHUB') {
      $message  = $disconnect ? 'disconnect' : 'connect';
      $message .= ' your trackhub';
    }
    else {
      $message = $disconnect ? 'disable' : 'enable';
      $message .= ' your track';
    }
    $hub->session->set_record_data({
        type     => 'message',
        code     => 'track_flip_error',
        message  => "Sorry, we could not $message.",
        function => '_error'
      });
  }
 
  my $url_params = {};
  $url_params->{ __clear} = 1;
  $url_params->{reload}   = 1;
  $url_params->{'action'} = 'ManageData';

  return $self->ajax_redirect($self->hub->url($url_params));
}

1;
