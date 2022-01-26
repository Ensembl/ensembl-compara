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

package EnsEMBL::Web::Command::UserData::DropUpload;

### Called by JavaScript only - see method dropFileUpload in 15_ImageMap.js

use strict;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return if $hub->input->cgi_error =~ /413/; # TOO BIG
  return if !$hub->param('text') || $hub->param('text') =~ /^\s*(http|ftp)/;
  
  my $species_defs = $hub->species_defs;
  
  $hub->param('assembly', $species_defs->ASSEMBLY_VERSION);
 
  my $upload = $self->upload('text');
  
  if ($upload->{'code'}) {
    my $nearest = $upload->{'nearest'};
    
    if ($nearest && $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', split /[^\w|\.]/, $nearest)) {
      print $nearest;
    } else {
      $hub->param('code', $upload->{'code'});
      $self->object->delete_upload;
      return;
    }
  }
}

1;
