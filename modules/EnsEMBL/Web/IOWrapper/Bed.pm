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

package EnsEMBL::Web::IOWrapper::BED;

### Wrapper for Bio::EnsEMBL::IO::Parser::Bed, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::IOWrapper);

sub create_hash {
  my $self = shift;
  return {
    'start'         => $self->parser->get_start,
    'end'           => $self->parser->get_end,
    'seq_region'    => $self->parser->get_seqname,
    'strand'        => $self->parser->get_strand,
    'score'         => $self->parser->get_score,
    'colour'        => $self->rgb_to_hex($self->parser->get_itemRgb),
    'cigar_string'  => $self->create_cigar_string,
  };
}

sub create_cigar_string {
  my $self = shift;

  if (!$self->parser->get_blockCount || !$self->parser->get_blockSizes 
          || !$self->parser->getchromStarts) {
    return ($self->parser->get_end - $self->parser->get_start + 1).'M'; 
  } 

  my $cigar;
  my @block_starts  = @{$self->parser->getChromStarts};
  my @block_lengths = @{$self->parser->getBlockSizes};
  my $strand = $self->parser->get_strand();
  my $end = 0;

  foreach(0..($self->parser->get_blockCount - 1)) {
    my $start = shift @block_starts;
    my $length = shift @block_lengths;
    if ($_) {
      if ($strand == -1) {
        $cigar = ( $start - $end - 1)."I$cigar";
      } else {
        $cigar .= ( $start - $end - 1)."I";
      }
    }
    if ($strand == -1) {
      $cigar = $length."M$cigar";
    } else {
      $cigar.= $length.'M';
    }
    $end = $start + $length -1;
  }
  return $cigar;
}

1;
