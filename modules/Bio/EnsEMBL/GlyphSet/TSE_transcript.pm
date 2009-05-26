package Bio::EnsEMBL::GlyphSet::TSE_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
#@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub _init {
  my ($self) = @_;
  my $wuc  = $self->{'config'};
  my $h       = 8;   #Increasing this increases glyph height

  my $pix_per_bp  = $wuc->transform->{'scalex'};
  my $length      = $wuc->container_width();

  my $trans_obj    = $self->cache('trans_object');
  my $coding_start = $trans_obj->{'coding_start'};
  my $coding_end   = $trans_obj->{'coding_end'  };

  #need both gene and transcript to get the colour
  my $transcript   = $trans_obj->{'transcript'};
  my $gene         = $trans_obj->{'web_transcript'}->core_objects->gene;
  my $colour_key   = $self->transcript_key($transcript,$gene);
  my $colour       = $self->my_colour($colour_key);

  my $strand       = $transcript->strand;
  my $tsi          = $transcript->stable_id;

  my @introns_and_exons = @{$trans_obj->{'introns_and_exons'}};

  my $tags;
  foreach my $obj (@introns_and_exons) {
    #if we're working with an exon then draw a box
    if ( $obj->[2] ) {
      my $exon_start = $obj->[0];
      my $exon_end   = $obj->[1];

      #set the exon boundries to the image boundries in case anything odd has happened
      $exon_start    = 1 if $exon_start < 1 ;
      $exon_end      = $length if $exon_end > $length;

      my $t_url =  $self->_url({
	'type'   => 'Transcript',
	'action' => 'Evidence',
	't'      => $tsi,
      });

      my $col1 = $self->my_colour('noncoding_join','join' );
      my $col2 = $self->my_colour('coding_join','join' );

      my ($G,$G2,$tag);
      my $G = $self->Rect({
	'bordercolour' => $colour,
	'absolutey'    => 1,
	'title'        => $obj->[2]->stable_id,
	'href'         => $t_url,
      });

      #draw and tag completely non-coding exons
      if ( ($exon_end < $coding_start) || ($exon_start > $coding_end) ) {
	$G->{'x'}      = $exon_start;
	$G->{'y'}      = 0.5*$h;
	$G->{'width'}  = $exon_end - $exon_start;
	$G->{'height'} = $h;
	$tag = "@{[$exon_end]}:@{[$exon_start]}";
	push @{$tags}, ["X:$tag",$col1];
	$self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
	$self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
	$self->push( $G );
      }			
      elsif ( ($exon_start >= $coding_start) && ($exon_end <= $coding_end) ) {
	##draw and tag completely coding exons
	$G->{'x'}      = $exon_start;
	$G->{'y'}      = 0;
	$G->{'width'}  = $exon_end - $exon_start;
	$G->{'height'} = 2*$h;
	$G->{'colour'} = $colour;
	$tag = "@{[$exon_end]}:@{[$exon_start]}";
	push @{$tags}, ["X:$tag",$col2];
	$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
	$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
	$self->push( $G );
      }

      elsif ( ($exon_start < $coding_start) && ($exon_end > $coding_start) ) {
	$G2 =  $self->Rect({
	  'bordercolour' => $G->{'bordercolour'},
	  'absolutey'    => $G->{'absolutey'},
	  'title'        => $G->{'title'},
	  'href'         => $G->{'href'},
	});
	##draw and tag partially coding transcripts on left hand
	#non coding part
	$G2->{'x'}      = $exon_start;
	$G2->{'y'}      = 0.5*$h;
	$G2->{'width'}  = $coding_start-$exon_start;
	$G2->{'height'} = $h;
	
	$tag = "@{[$coding_start]}:@{[$exon_start]}";
	push @{$tags}, ["X:$tag",$col1];
	$self->join_tag( $G2, "X:$tag", 0,  0, $col1, 'fill', -99 );
	$self->join_tag( $G2, "X:$tag", 1,  0, $col1, 'fill', -99  );
	$self->push( $G2 );
	
	#coding part
	my $G3 =  $self->Rect({
	  'bordercolour' => $G->{'bordercolour'},
	  'absolutey'    => $G->{'absolutey'},
	  'title'        => $G->{'title'},
	  'href'         => $G->{'href'},
	});		
	my $width = ($exon_end > $coding_end) ? $coding_end - $coding_start : $exon_end - $coding_start;
	my $y_pos = ($exon_end > $coding_end) ? $coding_end : $exon_end;
	$G3->{'x'}      = $coding_start;
	$G3->{'y'}      = 0;
	$G3->{'width'}  = $width;
	$G3->{'height'} = 2*$h;
	$G3->{'colour'} = $colour;
	$tag = "@{[$y_pos]}:@{[$coding_start]}";
	push @{$tags}, ["X:$tag",$col2];
	$self->join_tag( $G3, "X:$tag", 0,  0, $col2, 'fill', -99 );
	$self->join_tag( $G3, "X:$tag", 1,  0, $col2, 'fill', -99  );
	$self->push( $G3 );
	
	#draw non-coding part if there's one of these as well
	if ($exon_end > $coding_end) {
	  my $G4 =  $self->Rect({
	    'bordercolour' => $G->{'bordercolour'},
	    'absolutey'    => $G->{'absolutey'},
	    'title'        => $G->{'title'},
	    'href'         => $G->{'href'},
	  });
	  $G4->{'x'}      = $coding_end;
	  $G4->{'y'}      = 0.5*$h;
	  $G4->{'width'}  = $exon_end-$coding_end;
	  $G4->{'height'} = $h;
	  $tag = "@{[$exon_end]}:@{[$coding_end]}";
	  push @{$tags}, ["X:$tag",$col1];
	  $self->join_tag( $G4, "X:$tag", 0,  0, $col1, 'fill', -99 );
	  $self->join_tag( $G4, "X:$tag", 1,  0, $col1, 'fill', -99  );
	  $self->push( $G4 );
	}
      }
      elsif ( ($exon_end > $coding_end) && ($exon_start < $coding_end) ) {
	##draw and tag partially coding transcripts on the right hand
	$G2 =  $self->Rect({
	  'bordercolour' => $G->{'bordercolour'},
	  'absolutey'    => $G->{'absolutey'},
	  'title'        => $G->{'title'},
	  'href'         => $G->{'href'},
	});		
	#coding part
	$G2->{'x'}      = $exon_start;
	$G2->{'y'}      = 0;
	$G2->{'width'}  = $coding_end-$exon_start;
	$G2->{'height'} = 2*$h;
	$G2->{'colour'} = $colour;
	$tag = "@{[$coding_end]}:@{[$exon_start]}";
	push @{$tags}, ["X:$tag",$col2];
	$self->join_tag( $G2, "X:$tag", 0,  0, $col2, 'fill', -99 );
	$self->join_tag( $G2, "X:$tag", 1,  0, $col2, 'fill', -99  );
	$self->push( $G2 );
	
	#non coding part
	$G->{'x'}      = $coding_end;
	$G->{'y'}      = 0.5*$h;
	$G->{'width'}  = $exon_end-$coding_end;
	$G->{'height'} = $h;
	$tag = "@{[$exon_end]}:@{[$coding_end]}";
	push @{$tags}, ["X:$tag",$col1];
	$self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
	$self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
	$self->push( $G );
	
      }
      $wuc->cache('vertical_tags', $tags);
    }
    else {
      #otherwise draw a line to represent the intron context
      my $G = $self->Line({
	'x'        => $obj->[0]+1/$pix_per_bp,
	'y'        => $h,
	'h'        => 1,
	'width'    => $obj->[1] - $obj->[0] - 2/$pix_per_bp,
	'colour'   => $colour,
	'absolutey'=>1,
      });
      $self->push($G);
    }
  }

  #draw a direction arrow
  $self->push($self->Line({
    'x'         => 0,
    'y'         => -4,
    'width'     => $length,
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => $colour
  }));
  if($strand == 1) {
    $self->push( $self->Poly({
      'points' => [
	$length - 4/$pix_per_bp,-2,
	$length                ,-4,
	$length - 4/$pix_per_bp,-6],
      'colour'    => $colour,
      'absolutey' => 1,
    }));
  } else {
    $self->push($self->Poly({
      'points'    => [ 4/$pix_per_bp,-6,
		       0            ,-4,
		       4/$pix_per_bp,-2],
      'colour'    => $colour,
      'absolutey' => 1,
    }));
  }
}

1;
