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

package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return $self->set_format if $hub->function eq 'set_format';
  
  my $error      = $hub->input->cgi_error;
  my ($method)   = grep $hub->param($_), qw(file url text);
  my $url_params = { __clear => 1 };

  if ($error =~ /413/) {
    $url_params->{'filter_module'} = 'Data';
    $url_params->{'filter_code'}   = 'too_big';
  }
  
  if ($method) {
    $url_params = $self->upload($method);
    $url_params->{'action'} = $url_params->{'format'} ? 'UploadFeedback' : 'MoreInput';
  } else {
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
