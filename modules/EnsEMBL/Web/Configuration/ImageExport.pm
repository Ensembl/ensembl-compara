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

package EnsEMBL::Web::Configuration::ImageExport;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Configuration);

sub caption { 
  my $self = shift;
  return 'Export Image'; 
}

sub populate_tree {
  my $self  = shift;

  ## Input nodes
  $self->create_node('ImageFormats', 'Image Formats', 
                      ['image_formats', 'EnsEMBL::Web::Component::ImageExport::ImageFormats']);
  $self->create_node('TextFormats', 'Text Formats', 
                      ['text_formats', 'EnsEMBL::Web::Component::ImageExport::TextFormats']);
  $self->create_node('SelectTracks', 'Select Tracks', 
                      ['select_tracks', 'EnsEMBL::Web::Component::ImageExport::SelectTracks']);

  ## Output nodes
  $self->create_node('ImageOutput',  '', [], { 'command' => 'EnsEMBL::Web::Command::ImageExport::ImageOutput'});
  $self->create_node('TextOutput',  '', [], { 'command' => 'EnsEMBL::Web::Command::ImageExport::TextOutput'});
  $self->create_node('Error', 'Output Error', ['error', 'EnsEMBL::Web::Component::ImageExport::Error']);
}

1;
