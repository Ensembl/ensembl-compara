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

package EnsEMBL::Draw::GlyphSet::_text;

### Generic text module - not clear if/where it's used

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

## Get text details...
  my $t = $self->get_text_simple( $self->my_config('text'),$self->my_config('size'));

  $self->push( $self->Text({
## Centre text...
    'width'     => $self->{'container'}->length
    'x'         => 0
    'halign'    => $self->my_config('align')||'center',
    'y'         => 0,
    'height'    => $t->{'height'},
    'font'      => $t->{'font'},
    'ptsize'    => $t->{'fontsize'},
    'colour'    => $self->my_config('col')||'black',
    'text'      => $t->{'original'},
    'absolutey' => 1,
  }));
}

1;
