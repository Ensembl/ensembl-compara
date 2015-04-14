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

package EnsEMBL::Web::Command::UserData::AddFile;

use strict;

use List::Util qw(first);
use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return $self->set_format if $hub->function eq 'set_format';
 
  my ($method)  = first { $hub->param($_) } qw(url file text);
  my $format    = $hub->param('format');

  if ($method eq 'url') {
    ## Attach the file from the remote URL
    
  }
  else {
    ## Upload the data
    my %remote_formats = map { lc $_ => 1 } @{$self->hub->species_defs->multi_val('REMOTE_FILE_FORMATS')||[]};
    if ($remote_formats{$format}) {
      $url_params->{'restart'} = 1;
      $hub->session->add_data(
        type     => 'message',
        code     => 'userdata_error',
        message  => "We are unable to upload files of this type. Please supply a URL for this data.",
        function => '_error'
      );
    }
    else {
      $url_params = $self->upload($method);
      $url_params->{ __clear} = 1;
      $url_params->{'action'} = 'UploadFeedback';
    }
  }

  if ($url_params->{'restart'}) {
    $url_params->{'action'} = 'SelectFile';
  }

  return $self->ajax_redirect($self->hub->url($url_params));
}

sub set_format {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $code    = $hub->param('code');
  my $format  = $hub->param('format');
  
  $session->set_data(%{$session->get_data(code => $code)}, format => $format) if $format;
  
  $self->ajax_redirect($hub->url({
    action   => $format ? 'UploadFeedback' : 'MoreInput',
    function => undef,
    format   => $format,
    code     => $code
  }));
}

1;
