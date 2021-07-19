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

package EnsEMBL::Web::Component::UserData::UploadFeedback;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}


sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $user   = $hub->user;
  my $code   = $hub->param('code');

  my $upload = $user ? $user->get_record_data({type => 'upload', 'code' => $code}) : {};

  ## Can't find a user record - check session
  unless (keys %$upload) {
    $upload = $hub->session->get_record_data({type => 'upload', code => $code});
  }

  my $html;

  if (keys %$upload) {
    my $format  = $upload->{'format'} || $hub->param('format');
    my $species = $upload->{'species'} ? $hub->species_defs->get_config($upload->{'species'}, 'SPECIES_SCIENTIFIC_NAME') : '';
    
    $html = sprintf('
      <p class="space-below">Thank you. Your file uploaded successfully</p>
      <p class="space-below"><strong>File uploaded</strong>: %s (%s, %s)</p>',
      $upload->{'name'},
      $format  ? "$format file"      : 'Unknown format',
      $species ? "<em>$species</em>" : 'unknown species'
    );
  } else {
    $html = 'Sorry, there was a problem uploading your file. Please try again.';
  }
  
  return $html;
}

1;
