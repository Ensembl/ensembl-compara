package Bio::EnsEMBL::GlyphSet::intronlesstranscript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub init_label {
  my ($self) = @_;
  return; 
}

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;

  return unless $self->strand() == -1;
  my $offset = $self->{'container'}->chr_start - 1;
  my $Config        = $self->{'config'};
  my $chr_name = $self->{'container'}->chr_name();
    
  my @transcripts   = $Config->{'transcripts'};
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my $colours       = $self->colours();

  my $fontname      = "Tiny";    
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;
    
  my $voffset = 0;
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
  my @TRANS = @{$Config->{'transcripts'}};
  my $strand = $TRANS[0]{'exons'}[0][2]->strand;
  if( $strand == 1 ) { @TRANS = reverse @TRANS; }
  foreach my $trans_ref (@TRANS) {
    my $gene = $trans_ref->{'gene'};
    my $transcript = $trans_ref->{'transcript'};
    my @exons = sort {$a->[0] <=> $b->[0]} @{$trans_ref->{'exons'}};
    # Skip if no exons for this transcript
    next if (@exons == 0);
    # If stranded diagram skip if on wrong strand
    # For exon_structure diagram only given transcript
    my $Composite = new Sanger::Graphics::Glyph::Composite({'y'=>0,'height'=>$h});
      # $Composite->{'href'} = $self->href( $gene, $transcript, %highlights );
      # $Composite->{'zmenu'} = $self->zmenu( $gene, $transcript ) unless $Config->{'_href_only'};
    my($colour, $hilight) = $self->colour( $gene, $transcript, $colours, %highlights );
    my $coding_start = $trans_ref->{'coding_start'};
    my $coding_end   = $trans_ref->{'coding_end'  };
    my $Composite2 = new Sanger::Graphics::Glyph::Composite({'y'=>0,'height'=>$h});
    foreach my $exon (@exons) { 
      next unless defined $exon; #Skip this exon if it is not defined (can happen w/ genscans) 
        # We are finished if this exon starts outside the slice
      my($box_start, $box_end);
        # only draw this exon if is inside the slice
      $box_start = $exon->[0];
      $box_start = 1 if $box_start < 1 ;
      $box_end   = $exon->[1];
      $box_end = $length if$box_end > $length;
      if($box_start < $coding_start || $box_end > $coding_end ) {
         # The start of the transcript is before the start of the coding
         # region OR the end of the transcript is after the end of the
         # coding regions.  Non coding portions of exons, are drawn as
         # non-filled rectangles
         #Draw a non-filled rectangle around the entire exon
         $Composite2->push(new Sanger::Graphics::Glyph::Rect({
           'x'         => $box_start -1 ,
           'y'         => 0,
           'width'     => $box_end-$box_start +1,
           'height'    => $h,
           'bordercolour' => $colour,
           'absolutey' => 1,
          }));
      } 
        # Calculate and draw the coding region of the exon
      my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
      my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
             # only draw the coding region if there is such a region
      if( $filled_start <= $filled_end ) {
      #Draw a filled rectangle in the coding region of the exon
        $Composite2->push( new Sanger::Graphics::Glyph::Rect({
          'x' => $filled_start -1,
          'y'         => 0,
          'width'     => $filled_end - $filled_start + 1,
          'height'    => $h,
          'colour'    => $colour,
          'absolutey' => 1
        }));
      }
    } #we are finished if there is no other exon defined

    foreach my $subslice (@{$Config->{'subslices'}}) {
      $Composite2->push( new Sanger::Graphics::Glyph::Rect({
        'x' => $subslice->[0]+$subslice->[2]-1, 'y' => $h/2, 'h'=>1, 'width'=>$subslice->[1]-$subslice->[0], 'colour'=>$colour, 'absolutey'=>1
      }));
    }
    $Composite->push($Composite2);
    my $bump_height = 0;
    if( $Config->{'_add_labels'} ) { 
      my $H = 0;
      my  $T = length( $transcript->stable_id );
      my $name =  ' '.$transcript->external_name;
      $T = length( $name ) if length( $name ) > $T ;
      foreach my $text_label ( $transcript->stable_id, $name ) {
        next unless $text_label;
        next if $text_label eq ' ';
        my $width_of_label = $font_w_bp * ( $T+2 );
        my $tglyph = new Sanger::Graphics::Glyph::Text({
          'x'         => - $width_of_label,
          'y'         => $H,
          'height'    => $font_h_bp,
          'width'     => $width_of_label,
          'font'      => $fontname,
          'colour'    => $colour,
          'text'      => $text_label,
          'absolutey' => 1,
        });
        $H += $font_h_bp + 1;
        $Composite->push($tglyph);
      }
      $bump_height = $H;
    } 

    my @bitmap;
    my $max_row = -1;
    my @tmp;
    foreach my $snpref ( @{$Config->{'snps'}} ) {
      my $location = int( ($snpref->[0]+$snpref->[1])/2 );
      my $snp = $snpref->[2];
      my $cod_snp = $trans_ref->{'snps'}->{$snp->dbID().":".($snp->start+$offset) };
      next if $snp->end < $transcript->start - 100;
      next if $snp->start > $transcript->end + 100;
      my( $colour, $label );
      if( $cod_snp->{'type'} eq '01:syn' ) { ## Synonymous
        $colour = 'chartreuse1';
        if( $cod_snp->{'aa_alt'} ) {
          @tmp = ( "02:Amino acid: $cod_snp->{'aa_wt'} -> $cod_snp->{'aa_alt'}", '' );
          $label  = "$cod_snp->{'aa_wt'}-$cod_snp->{'aa_alt'}";
        } else {
          @tmp = ( "02:Amino acid: $cod_snp->{'aa_wt'}", '' );
          $label  = $cod_snp->{'aa_wt'};
        }
      } elsif( $cod_snp->{'type'} eq '01:non-syn' ) { ## Non-synonymous 
        $colour = 'coral';
        $label  = "$cod_snp->{'aa_wt'}-$cod_snp->{'aa_alt'}";
        @tmp = ( "02:Amino acid: $cod_snp->{'aa_wt'} -> $cod_snp->{'aa_alt'}",'' );
      } elsif( $cod_snp->{'type'} eq '01:prem-stop' || $cod_snp->{'type'} eq '01:no-stop' ) { ## Prem-stop
        $colour = 'red';
        $label  = "$cod_snp->{'aa_wt'}-$cod_snp->{'aa_alt'}";
        @tmp = ( "02:Amino acid: $cod_snp->{'aa_wt'} -> $cod_snp->{'aa_alt'}",'' );
      } elsif( $cod_snp->{'type'} eq '01:coding' ) { ## Coding SNP
        $colour = 'gold';
        $label = ' ';
      } elsif( $cod_snp->{'type'} eq '02:utr' ) { ## UTR SNP
        $colour = 'cadetblue3';  
        $label = ' ';
      } elsif( $cod_snp->{'type'} eq '03:intron' ) {
        $colour = 'grey65';
        $label = ' ';
      } else {
        $colour = 'grey80';
        $label = ' ';
      }
      my $S =  ( $snpref->[0]+$snpref->[1] - $font_w_bp * length( $label ) )/2;
      my $W = $font_w_bp * length( $label );
      my $tglyph = new Sanger::Graphics::Glyph::Text({
        'x'         => $S,
        'y'         => $h + 3,
        'height'    => $font_h_bp,
        'width'     => $W,
        'font'      => $fontname,
        'colour'    => 'black',
        'text'      => $label,
        'absolutey' => 1,
      });

      my $allele =  $snp->alleles;
      my $chr_start = $snp->start() + $offset;
      my $chr_end   = $snp->end() + $offset;
      my $pos =  $chr_start;
      if($snp->{'range_type'} eq 'between' ) {
         $pos = "between&nbsp;$chr_start&nbsp;&amp;&nbsp;$chr_end";
      } elsif($snp->{'range_type'} ne 'exact' ) {
         $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      }

     my $href = "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=$@{[$snp->id]}&source=@{[$snp->source_tag]}&chr=$chr_name&vc_start=$chr_start";

      my $bglyph = new Sanger::Graphics::Glyph::Rect({
       'x'         => $S - $font_w_bp / 2,
       'y'         => $h + 2,
       'height'    => $h,
       'width'     => $W + $font_w_bp,
       'colour'    => $colour,
       'absolutey' => 1,
       'zmenu' => {
         'caption' => 'SNP '.$snp->id,
         "01:".substr($cod_snp->{'type'},3) => '',
         @tmp,
         '11:SNP properties' => $href,
         "12:bp $pos" => '',
         "13:class: ".$snp->snpclass => '',
         "14:amiguity code: ".$snp->{'_ambiguity_code'} => '',
         "15:alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => ''
       }
      });

      my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
         $bump_start = 0 if ($bump_start < 0);

      my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
         $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
      my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
      $max_row = $row if $row > $max_row;
      $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$h) ) + 1 );
      $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$h) ) + 1 );
      $self->push( $bglyph, $tglyph );
    }

    my $t_bump_height = ( $h + 2 ) * ( $max_row + 2.5 ) ;

    my $max_row_2 = -1;
    @bitmap = undef;
    foreach my $domain_ref ( @{$trans_ref->{'pfam_hits'}||[]} ) {
      my($domain,@pairs) = @$domain_ref;
      my $Composite3 = new Sanger::Graphics::Glyph::Composite({
           'y'         => 0,
           'height'    => $h
      });
      while( my($S,$E) = splice( @pairs,0,2 ) ) {
        $Composite3->push( new Sanger::Graphics::Glyph::Rect({
          'x' => $S,
          'y' => 0,
          'width' => $E-$S,
          'height' => $h,
          'colour' => 'purple4',
          'absolutey' => 1
        }));
      }
      $Composite3->push( new Sanger::Graphics::Glyph::Rect({
        'x' => $Composite3->{'x'},
        'width' => $Composite3->{'width'},
        'y' => $h/2,
        'height' => 0,
        'colour' => 'purple4',
        'absolutey' => 1
      }));
      my $text_label = $domain->feature2->seqname;
      my $width_of_label = length( "$text_label " ) * $font_w_bp;
      $Composite3->push( new Sanger::Graphics::Glyph::Text({
       'x'         => $Composite3->{'x'},
       'y'         => $h+2,
       'height'    => $font_h_bp,
       'width'     => $width_of_label,
       'font'      => $fontname,
       'colour'    => 'purple4',
       'text'      => $text_label,
       'absolutey' => 1,
      }));
      $text_label = $domain->idesc;
      $width_of_label = length( "$text_label " ) * $font_w_bp;
      $Composite3->push( new Sanger::Graphics::Glyph::Text({
       'x'         => $Composite3->{'x'},
       'y'         => $h+4 + $font_h_bp,
       'height'    => $font_h_bp,
       'width'     => $width_of_label,
       'font'      => $fontname,
       'colour'    => 'purple4',
       'text'      => $text_label,
       'absolutey' => 1,
      }));
      my $bump_start = int($Composite3->{'x'} * $pix_per_bp);
         $bump_start = 0 if ($bump_start < 0);

      my $bump_end = $bump_start + int($Composite3->width()*$pix_per_bp) +1;
         $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
      my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
      $max_row_2 = $row if $row > $max_row_2;

      $Composite3->y( $voffset + $Composite3->{'y'} + $t_bump_height + $row * ($h+$font_h_bp*2+5) );
      $self->push( $Composite3 );
    }

    $t_bump_height += ( $h + $font_h_bp * 2 + 5 ) * ($max_row_2+1) ;
 
    $bump_height = $t_bump_height if $t_bump_height > $bump_height;
    ########## bump it baby, yeah! bump-nology!
    ########## shift the composite container by however much we're bumped
    ## Now we draw the amino acid changes for all coding SNPs...
    $Composite->y($Composite->y() + $voffset );
    $voffset += $bump_height ;
    $Composite->colour($hilight) if(defined $hilight);
    $self->push($Composite);
  }
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return $Config->get('intronlesstranscript','colours');
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;

    my $genecol = $colours->{ "_".$transcript->external_status } || 'black';

    if( $transcript->external_status eq '' and ! $transcript->translation->stable_id ) {
       $genecol = $colours->{'_pseudogene'};
    }
    if(exists $highlights{$transcript->stable_id()}) {
      return ($genecol, $colours->{'superhi'});
    } elsif(exists $highlights{$transcript->external_name()}) {
      return ($genecol, $colours->{'superhi'});
    } elsif(exists $highlights{$gene->stable_id()}) {
      return ($genecol, $colours->{'hi'});
    }
      
    return ($genecol, undef);
}

sub href {
    my ($self, $gene, $transcript, %highlights ) = @_;

    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();
    
    return ( $self->{'config'}->get('transcript_lite','_href_only') eq '#tid' && exists $highlights{$gene->stable_id()} ) ?
        "#$tid" : 
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid);

}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $pid = $transcript->translation->stable_id(),
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
    my $zmenu = {
        'caption'                       => EnsWeb::species_defs->AUTHORITY." Gene",
        "00:$id"			=> "",
	"01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid&db=core",
        "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid&db=core",                	
        '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid&db=core);
    $zmenu->{'05:Export Peptide'}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    return $zmenu;
}

sub error_track_name { return EnsWeb::species_defs->AUTHORITY.' transcripts'; }

1;
