package Bio::EnsEMBL::GlyphSet::tsv_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type; 
  return unless $self->strand() == -1;
  my $offset = $self->{'container'}->start - 1;
  my $Config        = $self->{'config'};  
  my @transcripts   = $Config->{'transcripts'};  
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  #my $colours       = $self->colours(); ;
  my $pix_per_bp    = $Config->transform->{'scalex'}; 
  my $bitmap_length = int($Config->container_width() * $pix_per_bp); ;

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;
    
  my $voffset = 0; 
  my $trans_ref = $Config->{'transcript'};
  my $sample = $Config->{'transcript'}->{'sample'};
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my $strand = $trans_ref->{'exons'}[0][2]->strand;
  my $transcript = $trans_ref->{'transcript'};
  my $gene = $self->{'config'}->core_objects->gene;
  my @exons = sort {$a->[0] <=> $b->[0]} @{$trans_ref->{'exons'}};
  # If stranded diagram skip if on wrong strand
  # For exon_structure diagram only given transcript
  my $Composite = $self->Composite({'y'=>0,'height'=>$h});
  my $colour = $self->my_colour($self->transcript_key( $transcript, $gene));
  my $coding_start = $trans_ref->{'coding_start'};
  my $coding_end   = $trans_ref->{'coding_end'  };

  ## First of all draw the lines behind the exons.....
  foreach my $subslice (@{$Config->{'subslices'}}) {
    $self->push( $self->Rect({
      'x' => $subslice->[0]+$subslice->[2]-1, 'y' => $h/2, 'h'=>1, 'width'=>$subslice->[1]-$subslice->[0], 'colour'=>$colour, 'absolutey'=>1
    }));
  }
  ## Now draw the exons themselves....

  foreach my $exon (@exons) { 
    next unless defined $exon; #Skip this exon if it is not defined (can happen w/ genscans) 
      # We are finished if this exon starts outside the slice
    my($box_start, $box_end);
      # only draw this exon if is inside the slice
    $box_start = $exon->[0];
    $box_start = 1 if $box_start < 1 ;
    $box_end   = $exon->[1];
    $box_end = $length if$box_end > $length;
    # Calculate and draw the coding region of the exon
    my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
    my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
             # only draw the coding region if there is such a region
    if( $filled_start <= $filled_end ) {
    #Draw a filled rectangle in the coding region of the exon
      $self->push( $self->Rect({
        'x' => $filled_start -1,
        'y'         => 0,
        'width'     => $filled_end - $filled_start + 1,
        'height'    => $h,
        'colour'    => $colour,
        'absolutey' => 1
      }));
    }
    if($box_start < $coding_start || $box_end > $coding_end ) {
      # The start of the transcript is before the start of the coding
      # region OR the end of the transcript is after the end of the
      # coding regions.  Non coding portions of exons, are drawn as
      # non-filled rectangles
      #Draw a non-filled rectangle around the entire exon
      my $G = $self->Rect({
        'x'         => $box_start -1 ,
        'y'         => 0,
        'width'     => $box_end-$box_start +1,
        'height'    => $h,
        'bordercolour' => $colour,
        'absolutey' => 1,
        'title'     => $exon->[2]->stable_id,
        'href'     => $self->href(  $transcript, $exon->[2], %highlights ),
      });
      $G->{'zmenu'} = $self->zmenu( $transcript, $exon->[2] ) unless $Config->{'_href_only'};
      $self->push( $G );
    } 
  } #we are finished if there is no other exon defined

#  if( $Config->{'_add_labels'} ){
#    my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $sample, '', 'ptsize' => $fontsize, 'font' => $fontname );
#    my $tglyph = $self->Text({
#      'x'         => -105,
#      'y'         => -($th/2), 
#      'height'    => $th,
#      'width'     => $w / $pix_per_bp,
#      'font'      => $fontname,
#      'ptsize'    => $fontsize,
#      'colour'    => $colour,
#      'text'      => $sample,
#      'halign'     => 'left',
#      'absolutey' => 1,
#      'absolutex' => 1,
#    });
#    $self->push($tglyph);
#  }
}

sub href {
    my ($self, $transcript, $exon,) = @_;

    my $tid = $transcript->stable_id();
    my $eid =  $exon->stable_id;
    my $href = $self->_url({
      'type'   => 'Transcript',
      'action' => 'Variation_transcript',
      'vt'      => $tid,
      'e'      => $eid,
    });

  return $href;
}

sub zmenu {
  my ($self, $transcript, $exon, %highlights) = @_;
  my $eid = $exon->stable_id();
  my $tid = $transcript->stable_id();
  my $pid = $transcript->translation ? $transcript->translation->stable_id() : '';
  #my $gid = $gene->stable_id();
  my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
  my $zmenu = {
    'caption'                       => $self->species_defs->AUTHORITY." Gene",
    "00:$id"			=> "",
#	"01:Gene:$gid"                  => "/@{[$self->{container}{web_species}]}/geneview?gene=$gid;db=core",
        "02:Transcr:$tid"    	        => "/@{[$self->{container}{web_species}]}/transview?transcript=$tid;db=core",                	
        "04:Exon:$eid"    	        => "",
        '11:Export cDNA'                => "/@{[$self->{container}{web_species}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
        
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/@{[$self->{container}{web_species}]}/protview?peptide=$pid;db=core);
    $zmenu->{'12:Export Peptide'}=
    	qq(/@{[$self->{container}{web_species}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);	
    }
    return $zmenu;
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
