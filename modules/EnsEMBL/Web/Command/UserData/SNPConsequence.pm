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

package EnsEMBL::Web::Command::UserData::SNPConsequence;

use strict;

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self         = shift;
  my $object       = $self->object;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $session      = $hub->session;
  my @files        = $hub->param('convert_file');
  my $size_limit   = $hub->param('variation_limit');
  my $species      = $hub->param('species') || $hub->species;
  my @temp_files;
  my $output;
  
  my $url_params = {
    species            => $species,
    action             => 'SelectOutput',
    consequence_mapper => $hub->param('consequence_mapper') || 0,
    _time              => $hub->param('_time')              || '',
    __clear            => 1,
  };
  
  foreach my $file_name (@files) {
    next unless $file_name;

    my ($file, $name) = split ':', $file_name;
    my ($results, $nearest, $file_count) = $object->calculate_consequence_data($file, $size_limit);
    my $table = $object->consequence_table($results);

    # Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
      extension    => 'txt',
      prefix       => 'user_upload',
      content_type => 'text/plain; charset=utf-8',
    );
    
    $temp_file->print($table->render_Text);
    
    push @temp_files, $temp_file->filename . ':' . $name;
    
    ## Resave this file location to the session
    my ($type, $code) = split '_', $file, 2;
    my $session_data  = $session->get_data(type => $type, code => $code);
    
    $session_data->{'filename'} = $temp_file->filename;
    $session_data->{'filesize'} = length $temp_file->content;
    $session_data->{'filetype'} = 'Variant Effect Predictor';
    $session_data->{'format'}   = 'VEP_OUTPUT';
    $session_data->{'strand'}   = 'f';
    $session_data->{'border'}   = 'off'; ## show as unjoined features
    $session_data->{'md5'}      = $temp_file->md5;
    $session_data->{'nearest'}  = $nearest;
    $session_data->{'assembly'} = $species_defs->get_config($species, 'ASSEMBLY_VERSION');

    $session->set_data(%$session_data);
    
    $url_params->{'code'}       = $code;
    $url_params->{'count'}      = $file_count;
    $url_params->{'size_limit'} = $size_limit;
  }
 
  $url_params->{'convert_file'} = \@temp_files;
  
  $self->ajax_redirect($hub->url($url_params));
}

1;

