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

package EnsEMBL::Draw::GlyphSet::tsv_transcript;

### Module for drawing transcripts on Transcript/Variation_Transcript/Image 
### (formerly known as TranscriptSNPView)
### See EnsEMBL::Web::Component::VariationImage for implementation


use strict;

use base qw(EnsEMBL::Draw::GlyphSet_transcript);

sub render_normal {
## Default (and currently only) rendering style for this track: as exon blocks
## joined by angled lines, with no labels
  my $self = shift;
  my $type = $self->type;
  
  return unless defined $type; 
  return unless $self->strand == -1;
  
  my $config      = $self->{'config'};  
  my $h           = 8; # Single transcript mode - set height to 30 - width to 8
    
  my %highlights;
  @highlights{$self->highlights} = ();  # build hashkeys of highlight list
  
  my $length     = $config->container_width;
  my $trans_ref  = $config->{'transcript'};   
  my $transcript = $trans_ref->{'transcript'}; 
  my $gene       = $self->{'config'}->core_object('gene')->Obj;
  my @exons      = sort { $a->[0] <=> $b->[0] } @{$trans_ref->{'exons'}};
  
  # If stranded diagram skip if on wrong strand
  # For exon_structure diagram only given transcript
  my $colour       = $self->my_colour($self->colour_key($gene, $transcript));
  my $coding_start = $trans_ref->{'coding_start'};
  my $coding_end   = $trans_ref->{'coding_end'};

  ## First of all draw the lines behind the exons
  foreach my $subslice (@{$config->{'subslices'}}) {
    $self->push($self->Rect({
      x         => $subslice->[0] + $subslice->[2] - 1,
      y         => $h / 2,
      h         => 1,
      width     => $subslice->[1] - $subslice->[0],
      colour    => $colour,
      absolutey => 1
    }));
  }
  
  ## Now draw the exons themselves
  foreach my $exon (@exons) { 
    next unless defined $exon; # Skip this exon if it is not defined (can happen w/ genscans)
    
    # We are finished if this exon starts outside the slice
    my ($box_start, $box_end);
    
    # only draw this exon if is inside the slice
    $box_start = $exon->[0];
    $box_start = 1 if $box_start < 1 ; 
    $box_end   = $exon->[1];
    $box_end   = $length if $box_end > $length;
    
    # Calculate and draw the coding region of the exon
    my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
    my $filled_end   = $box_end   > $coding_end   ? $coding_end   : $box_end;
    
    # only draw the coding region if there is such a region
    if ($filled_start <= $filled_end) {
      # Draw a filled rectangle in the coding region of the exon
      $self->push($self->Rect({
        x         => $filled_start -1,
        y         => 0,
        width     => $filled_end - $filled_start + 1,
        height    => $h,
        colour    => $colour,
        title     => $exon->[2]->stable_id,
        href      => $self->href($transcript, $exon->[2], %highlights),
        absolutey => 1
      }));
    }
    
    if($box_start < $coding_start || $box_end > $coding_end ) {
      # The start of the transcript is before the start of the coding
      # region OR the end of the transcript is after the end of the
      # coding regions.  Non coding portions of exons, are drawn as
      # non-filled rectangles
      
      # Draw a non-filled rectangle around the entire exon
      $self->push($self->Rect({
        x            => $box_start - 1 ,
        y            => 0,
        width        => $box_end - $box_start + 1,
        height       => $h,
        bordercolour => $colour,
        absolutey    => 1,
        title        => $exon->[2]->stable_id,
        href         => $self->href($transcript, $exon->[2], %highlights),
      }));
    } 
  }
}

sub href {
  my ($self, $transcript, $exon,) = @_;

  my $tid  = $transcript->stable_id;
  my $eid  = $exon->stable_id;
  my $href = $self->_url({
    type   => 'Transcript',
    action => 'VariationTranscript',
    vt     => $tid,
    e      => $eid,
  });
  
  return $href;
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY . ' transcripts'; }

1;
