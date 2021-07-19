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

package EnsEMBL::Draw::GlyphSet::geneexon_bgtrack;

### Draws background "tent" stripes on images that zoom in on a
### single gene, e.g. Gene/Splice, Gene/Variation/Image

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};  
  my $strand_flag = $self->my_config('strand'); 
  my $strand  = $self->strand(); 
  return if ( $strand_flag eq 'f' && $strand != 1 ) || ( $strand_flag eq 'r'  && $strand == 1 );
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'}; 
  my $target_gene   = $Config->{'geneid'} || $Config->{'geneid2'}; 
    
  my $h             = 1;
    
  my @bitmap        = undef;
  my $colour = $self->my_config('colours');

  my $fontname      = "Tiny";    
  my $pix_per_bp    = $Config->transform_object->scalex;
  #$my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp); 
  my $bitmap_length = int($Config->container_width() * $pix_per_bp); 

  my $length  = $container->length; 
    
  my %exons = ();
  if( $Config->{'fakeslice'} ) { 
    foreach my $transcript ( @{$Config->{'transcripts'}}  ) { 
      foreach my $exon ( @{$transcript->{'exons'}} ) {
        my $tag = "@{[$exon->[2]->start]}:@{[$exon->[2]->end]}"; 
        $exons{"$exon->[0]:$exon->[1]:$tag"}++; 
      }
    }
  } else {
    my $offset  = $container->start - 1;
    my $features =  $self->{'container'}->get_all_Genes(
      undef,
     # $Config->get('geneexon_bgtrack','opt_db')
      $self->my_config('opt_db')
    );
    foreach my $gene ( @$features ) { 
      next if $target_gene && ($gene->stable_id() ne $target_gene);
      foreach my $transcript (@{$gene->get_all_Transcripts()}) {
        foreach my $exon (@{$transcript->get_all_Exons()}) {
          my $tag = "@{[$exon->start]}:@{[$exon->end]}"; 
          my $tag2 = "@{[$exon->start+$offset]}:@{[$exon->end+$offset]}";
          $exons{ "$tag:$tag2" }++; 
        }
      }
    } 
  } 
  #my $tag = $Config->get( 'geneexon_bgtrack', 'tag' );
  my $tag = $self->my_config('tag'); 
  $tag ++ if $strand == -1;
  my $start = $container->start(); 
  my @exons = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } map { [ split /:/, $_ ] } keys %exons;
  my $T = $strand == 1 ? 1 : 0;
  foreach my $EXON ( @exons ) {
    my( $S,$E,$S2,$E2 ) = @$EXON;
    next if $E<1;
    next if $S>$length;
    my $tag_root = "@{[$S2]}:@{[$E2]}";
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $tglyph = $self->Rect({
      'x' => $S-1,
      'y' => 0,
      'height' => 0,
      'width'  => $E-$S+1,
      'colour' => $colour,
    });
    $self->join_tag( $tglyph, "X:$tag_root-0", 1-$T,0, $colour, 'fill', -99 );
    $self->join_tag( $tglyph, "X:$tag_root-0", $T,0, $colour, 'fill', -99  );
    $self->join_tag( $tglyph, "X:$tag_root=$tag", 1-$T,0, $colour, 'fill', -99 );
    $self->join_tag( $tglyph, "X:$tag_root=$tag", $T,0, $colour, 'fill', -99 );
    $self->push( $tglyph );
  }
}


1;
