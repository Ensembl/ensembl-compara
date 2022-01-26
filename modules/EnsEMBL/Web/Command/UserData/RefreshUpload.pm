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

package EnsEMBL::Web::Command::UserData::RefreshUpload;

## Re-uploads a file from a URL 

use strict;

use List::Util qw(first);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  my $url_params  = {};
  my $code        = $hub->param('code');
  my $file_info   = $hub->session->get_data('code' => $hub->param('code'));
 
  my %args = (
              'hub'             => $hub,
              'file'            => $file_info->{'url'},
              'write_location'  => $file_info->{'file'},
              );  

  my $file = EnsEMBL::Web::File::User->new(%args);
  if ($file) {
    ## Upload the data
    $url_params = $file->upload(
                                'method'  => 'url', 
                                'format'  => $file_info->{'format'},
                                'name'    => $file_info->{'name'},
                                );
  }

  $url_params->{ __clear} = 1;
  $url_params->{'action'} = 'ManageData';

  return $self->ajax_redirect($self->hub->url($url_params));
}

1;
