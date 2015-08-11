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

## Attaches or uploads a file and does some basic checks on the format

use strict;

use List::Util qw(first);

use EnsEMBL::Web::File::AttachedFormat;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return $self->set_format if $hub->function eq 'set_format';
 
  my ($method)    = first { $hub->param($_) } qw(file text);
  my $format      = $hub->param('format');
  my $url_params  = {};
  my $new_action  = '';

  if ($method eq 'text' && $hub->param('text') =~ /^(http|ftp)/) {
    ## Attach the file from the remote URL
    my $url       = $hub->param('text'); 
    $url          =~ s/(^\s+|\s+$)//g; # Trim leading and trailing whitespace
    my $filename  = [split '/', $url]->[-1];

    ## Is this file already attached?
    ($new_action, $url_params) = $self->check_attachment($url);

    if ($new_action) {
      $url_params->{'action'} = $new_action;
    }
    else {
      my $format_package = 'EnsEMBL::Web::File::AttachedFormat::' . uc $format;
      my %args = ('hub' => $self->hub, 'format' => $format, 'url' => $url, 'track_line' => $self->hub->param('trackline'));

      if ($self->dynamic_use($format_package)) {
        $format = $format_package->new(%args);
      } else {
      $format = EnsEMBL::Web::File::AttachedFormat->new(%args);
      }

      ($new_action, $url_params) = $self->attach($format, $filename);
      $url_params->{'action'} = $new_action;
    }

  }
  else {
    ## Upload the data
      $url_params = $self->upload($method, $format);
      $url_params->{ __clear} = 1;
      $url_params->{'action'} = 'UploadFeedback';
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
