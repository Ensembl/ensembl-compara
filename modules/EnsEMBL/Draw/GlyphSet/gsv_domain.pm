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

package EnsEMBL::Draw::GlyphSet::gsv_domain;

### Draws protein domains on Gene/Variation_Gene/Image

use strict;

use EnsEMBL::Draw::Utils::Bump;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  my $type = $self->type;
  return unless defined $type; 
  
  return unless $self->strand() == -1;  
  my $key = lc($type).'_hits';
  $key =~s/domain_//;


  my $Config        = $self->{'config'};
  my $trans_ref = $Config->{'transcript'}; 
  my $offset = $self->{'container'}->start - 1;
    
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform_object->scalex;
  
  #my $bitmap_length = $Config->image_width(); 
   my $bitmap_length = int($Config->container_width() * $pix_per_bp); 

  my $length  = $Config->container_width(); 
  my $transcript_drawn = 0;
    
  my $voffset = 0;
  my $strand = $trans_ref->{'exons'}[0][2]->strand;  
    my $gene = $trans_ref->{'gene'};
    my $transcript = $trans_ref->{'transcript'}; 

  my @bitmap = undef; 
  foreach my $domain_ref ( @{$trans_ref->{$key}||[]} ) { 
    my($domain,@pairs) = @$domain_ref;  
    my $Composite3 = $self->Composite({
      'y'         => 0,
      'height'    => $h,
      'href'  => $self->_url({ 'type' => 'Transcript', 'action' => 'ProteinSummary', 'pf_id' => $domain->dbID, 'translation_id' => $domain->seqname }),
    });
    while( my($S,$E) = splice( @pairs,0,2 ) ) {  
      $Composite3->push( $self->Rect({
        'x' => $S,
        'y' => 0,
        'width' => $E-$S,
        'height' => $h,
        'colour' => 'purple4',
        'absolutey' => 1,
      }));
    }
    $Composite3->push( $self->Rect({
      'x' => $Composite3->{'x'},
      'width' => $Composite3->{'width'},
      'y' => $h/2,
      'height' => 0,
      'colour' => 'purple4',
      'absolutey' => 1
    }));
    my $text_label = $domain->hseqname;  
    my @res = $self->get_text_width( 0, $text_label, '', 'font' => $fontname, 'ptsize' => $fontsize );
    $Composite3->push( $self->Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h,
      'height'    => $th,
      'width'     => $res[2]/$pix_per_bp,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left', 
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));
    $text_label = $domain->idesc; 
    my @res = $self->get_text_width( 0, $text_label, '', 'font' => $fontname, 'ptsize' => $fontsize );
    $Composite3->push( $self->Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h+2 + $th,
      'height'    => $th,
      'width'     => $res[2]/$pix_per_bp,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left', 
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));

    
    my $bump_start = int($Composite3->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($Composite3->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & EnsEMBL::Draw::Utils::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );

    $Composite3->y( $voffset + $Composite3->{'y'} + $row * ($h+$th*2+5) );
    $self->push( $Composite3 );
  }

}

1;
