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

package EnsEMBL::Draw::GlyphSet::text;

### Generic text module, used to create footer lines 

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub init_label {
    return;
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

  my( $fontname, $fontsize ) = $self->get_font_details( 'text' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3] + ($self->my_config('extra_height') || 0);

  my $text = $self->my_config('text');
  unless ($text)  {  $text =  $self->{'config'}->{'text'}; }
  $self->push($self->Text({
    'x'         => 1, 
    'y'         => 2,
    'height'    => $h,
    'halign'    => 'left',
    'font'      => $fontname,
    'ptsize'    => $fontsize,
    'colour'    => 'black',
    'text'      => $text,
    'absolutey' => 1,
  }) );
}

1;
