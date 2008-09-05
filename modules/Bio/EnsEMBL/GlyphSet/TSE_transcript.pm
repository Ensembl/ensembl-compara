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
    my $Config  = $self->{'config'};
    my $h       = 8;   #Increasing this increases glyph height

    my $pix_per_bp  = $Config->transform->{'scalex'};
    my $length      = $Config->container_width();

    my $colour = $self->my_colour;
    my $trans_ref    = $Config->{'transcript'};
    my $coding_start = $trans_ref->{'coding_start'};
    my $coding_end   = $trans_ref->{'coding_end'  };
    my $transcript   = $trans_ref->{'transcript'};
    my $strand       = $transcript->strand;
    my $tsi          = $transcript->stable_id;

    my @introns_and_exons = @{$trans_ref->{'introns_and_exons'}};

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

	    ##the following is very verbose and will be rewritten, but it does do the job!
	    my ($G,$tag);
	    #draw and tag completely non-coding exons
	    if ( ($exon_end < $coding_start) || ($exon_start > $coding_end) ) {
		$G = $self->Rect({
		    'x'         => $exon_start ,
		    'y'         => 0.5*$h,
		    'width'     => $exon_end - $exon_start,
		    'height'    => $h,
		    'bordercolour' => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
		$tag = "@{[$exon_end]}:@{[$exon_start]}";
		push @{$tags}, ["X:$tag",$col1];
		$self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
		$self->push( $G );
	    }			
	    elsif ( ($exon_start >= $coding_start) && ($exon_end <= $coding_end) ) {
		##draw and tag completely coding exons
		$G = $self->Rect({
		    'x'         => $exon_start,
		    'y'         => 0,
		    'width'     => $exon_end - $exon_start,
		    'height'    => 2*$h,
		    'colour'    => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
#		warn "drawing exon_box from $exon_start to $exon_end";
		$tag = "@{[$exon_end]}:@{[$exon_start]}";
		push @{$tags}, ["X:$tag",$col2];
		$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
		$self->push( $G );
	    }

	    elsif ( ($exon_start < $coding_start) && ($exon_end > $coding_start) ) {
		##draw and tag partially coding transcripts on left hand
		#non coding part
		$G = $self->Rect({
		    'x'         => $exon_start,
		    'y'         => 0.5*$h,
		    'width'     => $coding_start-$exon_start,
		    'height'    => $h,
		    'bordercolour' => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
		$tag = "@{[$coding_start]}:@{[$exon_start]}";
		push @{$tags}, ["X:$tag",$col1];
		$self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
		$self->push( $G );
		
		#coding part		
		my $width = ($exon_end > $coding_end) ? $coding_end - $coding_start : $exon_end - $coding_start;
		my $y_pos = ($exon_end > $coding_end) ? $coding_end : $exon_end;
		$G = $self->Rect({
		    'x'         => $coding_start,
		    'y'         => 0,
		    'width'     => $width,
		    'height'    => 2*$h,
		    'colour'    => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
		$tag = "@{[$y_pos]}:@{[$coding_start]}";
		push @{$tags}, ["X:$tag",$col2];
		$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
		$self->push( $G );
		
		#draw non-coding part if there's one of these as well
		if ($exon_end > $coding_end) {
		    $G = $self->Rect({
			'x'         => $coding_end,
			'y'         => 0.5*$h,
			'width'     => $exon_end-$coding_end,
			'height'    => $h,
			'bordercolour'    => $colour,
			'absolutey' => 1,
			'title'     => $obj->[2]->stable_id,
			'href'      => $t_url,
		    });
		    $tag = "@{[$exon_end]}:@{[$coding_end]}";
		    push @{$tags}, ["X:$tag",$col1];
		    $self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
		    $self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
		    $self->push( $G );
		}
	    }
	    
	    elsif ( ($exon_end > $coding_end) && ($exon_start < $coding_end) ) {
		##draw and tag partially coding transcripts on the right hand
		
		#coding part
		$G = $self->Rect({
		    'x'         => $exon_start,
		    'y'         => 0,
		    'width'     => $coding_end - $exon_start,
		    'height'    => 2*$h,
		    'colour'    => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
		$tag = "@{[$coding_end]}:@{[$exon_start]}";
		push @{$tags}, ["X:$tag",$col2];
		$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
		$self->push( $G );

		#non coding part
		$G = $self->Rect({
		    'x'         => $coding_end,
		    'y'         => 0.5*$h,
		    'width'     => $exon_end-$coding_end,
		    'height'    => $h,
		    'bordercolour' => $colour,
		    'absolutey' => 1,
		    'title'     => $obj->[2]->stable_id,
		    'href'      => $t_url,
		});
		$tag = "@{[$exon_end]}:@{[$coding_end]}";
		push @{$tags}, ["X:$tag",$col1];
		$self->join_tag( $G, "X:$tag", 0,  0, $col1, 'fill', -99 );
		$self->join_tag( $G, "X:$tag", 1,  0, $col1, 'fill', -99  );
		$self->push( $G );
		
	    }
	    $Config->{'tags'} = $tags;				
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
