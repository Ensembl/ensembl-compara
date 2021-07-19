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

package EnsEMBL::Draw::GlyphSet::spacer;

### Used in a number of complex images to create spaces between sections
### See various modules under EnsEMBL::Web::ImageConfig

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;  
  
  $self->push($self->Rect({
    x             => $self->image_width - $self->get_parameter('image_width') + $self->get_parameter('margin'),
    y             => 0,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    width         => $self->my_config('width')  || 1,
    height        => $self->my_config('height') || 20,
    colour        => $self->my_config('colour'),
  }));
}

1;
