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

package EnsEMBL::Web::Command::UserData::CheckConvert;

### Upload some data and add relevant parameters to the wizard workflow

use strict;

use HTML::Entities qw(encode_entities);

use Bio::EnsEMBL::Variation::Utils::VEP qw(@VEP_WEB_CONFIG);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self               = shift;
  my $hub                = $self->hub;
  my $id_mapper          = $hub->param('id_mapper');
  my $consequence_mapper = $hub->param('consequence_mapper');
  my $url_params         = { __clear => 1 };
  my ($method)           = grep $hub->param($_), qw(file url text);
  my @files_to_convert;

  if ($id_mapper) {
    $url_params->{'action'}    = 'SelectOutput';
    $url_params->{'id_mapper'} = $id_mapper;
    $hub->param('format', 'ID');
  } elsif ($consequence_mapper) {
    $url_params->{'action'}             = 'SNPConsequence';
    $url_params->{'consequence_mapper'} = $consequence_mapper;
    $url_params->{$_}                   = $hub->param($_) for 'format', @VEP_WEB_CONFIG;
  } else {
    $url_params->{'action'} = 'ConvertFeatures';
  }
  
  if ($method) {
    my $response = $self->upload($method);
    my $code     = delete $response->{'code'};
    
    $url_params->{$_} = $response->{$_} for keys %$response;
    push @files_to_convert, "upload_$code:$response->{'name'}";
  }
  
  push @files_to_convert, $hub->param('convert_file');
  
  $url_params->{'convert_file'} = \@files_to_convert;
  $url_params->{'conversion'}   = $hub->param('conversion') unless $id_mapper || $consequence_mapper;
  $url_params->{$_}             = $hub->param($_) for qw(id_limit variation_limit);
  
  $self->ajax_redirect($hub->url($url_params));
}

1;

