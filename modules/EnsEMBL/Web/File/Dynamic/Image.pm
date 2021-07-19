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

package EnsEMBL::Web::File::Dynamic::Image;

use strict;

use Image::Size;

use parent qw(EnsEMBL::Web::File::Dynamic);

### Replacement for EnsEMBL::Web::TmpFile::Image
### Data can be written to disk or, if enabled and appropriate, memcached

### Path structure: /base_dir/YYYY-MM-DD/XXXXXXXXXXXXXXX.png

sub new {
### @constructor
  my ($class, %args) = @_;
  $args{'extension'} ||= 'png';
  return $class->SUPER::new(%args);
}

sub width { 
### @getter
### @return Integer - width of image in pixels
  my $self = shift;
  return $self->{'width'}; 
}

sub height { 
### @getter
### @return Integer - height of image in pixels
  my $self = shift;
  return $self->{'height'}; 
}

sub size { 
### @getter
### @return Integer - size of image in bytes
  my $self = shift;
  return $self->{'size'}; 
}

sub read {
### Read the contents of an image file and set dimensions
### @return data String - contents of image file
  my $self = shift;

  my $data = $self->SUPER::read();

  $self->_set_image_params($data) if $data;

  return $data;
}

sub write {
### Determine the dimensions of an image and then write to disk/memory
### @param data String - rendered image
  my ($self, $data) = @_;

  if ($data) {
    $self->_set_image_params($data);
    return $self->SUPER::write($data);
  }
}

sub _set_image_params {
### Determine the dimensions of an image once it's been created
### @param data String - rendered image
### @return Void
  my ($self, $data) = @_;
  return unless $data;

  my ($x, $y, $z) = Image::Size::imgsize(\$data);
    #die "imgsize failed: $z" unless defined $x;
  $self->{'width'}  = $x;
  $self->{'height'} = $y;
  $self->{'size'}   = length($data);
}

1;

