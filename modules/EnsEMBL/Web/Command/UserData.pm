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

package EnsEMBL::Web::Command::UserData;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::File::User;

use base qw(EnsEMBL::Web::Command);

sub ajax_redirect {
  ## Provide default value for redirectType and modalTab
  my ($self, $url, $param, $anchor, $redirect_type, $modal_tab) = @_;
  $self->SUPER::ajax_redirect($url, $param, $anchor, $redirect_type || 'modal', $modal_tab || 'modal_user_data');
}

sub upload {
### Simple wrapper around File::User 
  my ($self, $method, $type) = @_;
  my $hub       = $self->hub;
  my $params    = {};

  my $file  = EnsEMBL::Web::File::User->new('hub' => $hub, 'empty' => 1);
  my $error = $file->upload;

  if ($error) {
    $params->{'restart'} = 1;
    $hub->session->add_data(
      type     => 'message',
      code     => 'userdata_error',
      message  => "There was a problem uploading your data: $error.<br />Please try again.",
      function => '_error'
    );
  } else {
    $params->{'species'}  = $hub->param('species') || $hub->species;
    $params->{'code'}     = $file->code;
  } 
 
  return $params;
}

1;
