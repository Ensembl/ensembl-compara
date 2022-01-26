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

package EnsEMBL::Draw::GlyphSet::Vuserdata;

### Fetches userdata and munges it into a basic format 
### for rendering by the parent module

use strict;

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Wiggle';
with 'EnsEMBL::Draw::Role::BigWig';

use parent qw(EnsEMBL::Draw::GlyphSet::V_density);

sub _init {
my $self  = shift;
  ## Force default style to one that's understood by the vertical code
  $self->{'display'} = 'density_line';
  ## Filter data by chromosome
  my $chr   = $self->{'container'}->{'chr'};
  my $data  = $self->get_data;
  my $set   = $data->[0]{$chr} || {};
  return $self->build_tracks($set);
}

1;
