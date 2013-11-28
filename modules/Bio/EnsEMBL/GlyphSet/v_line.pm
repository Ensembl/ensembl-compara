=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::GlyphSet::v_line;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  
  my $strand = $self->strand;

  my $strand_flag    = $self->my_config('strand');

  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

  my $len            = $self->{'container'}->length();
  my $global_start   = $self->{'container'}->start();
  my $global_end     = $self->{'container'}->end();
  my $im_width       = $self->image_width();

  my @common = ( 'z' => 1000, 'colour' => 'red', 'absolutex' => 1, 'absolutey' => 1, 'absolutewidth' => 1 );

  ## Draw empty lines at the top and the bottom of the image(strand 'r')
  my $start = int(($im_width)/2);
  my $line = $self->Line({ 'x' => $start, 'y' => 0, 'width' => 0, 'height' => 0, @common });
  
  ## Links the 2 lines in a vertical one, in the middle of the image
  $self->join_tag($line, "v_line_$start", 0, 0, 'red', 'fill', 10);
        
  $self->push($line);
}

1;
