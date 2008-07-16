package Bio::EnsEMBL::GlyphSet::TSE_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
#@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub init_label {
  my ($self) = @_;
  my $sample = $self->{'config'}->{'id'};
  $self->init_label_text( $sample );
}

sub _init {
	my ($self) = @_;
	my $Config  = $self->{'config'};
	my $h       = 8;   #Increasing this increases glyph height

	my $colours     = $self->colours();
	my $pix_per_bp  = $Config->transform->{'scalex'};
	my $length      = $Config->container_width();

	my $trans_ref = $Config->{'transcript'};
	my $coding_start = $trans_ref->{'coding_start'};
	my $coding_end   = $trans_ref->{'coding_end'  };
	my $strand = $trans_ref->{'exons'}[0][2]->strand;
	my $transcript = $trans_ref->{'transcript'};
	my $tsi = $transcript->stable_id;
	my @introns_and_exons = @{$trans_ref->{'introns_and_exons'}};

	my %highlights;
	@highlights{$self->highlights} = ();    # build hashkeys of highlight list
	my($colour, $label, $hilight) = $self->colour( $transcript, $colours, %highlights );
	$colour ||= 'blue';

	my $tags;

	foreach my $obj (@introns_and_exons) {
		#if we're working with an exon then draw a box
		if ( $obj->[2] ) {

			my $exon_start = $obj->[0];
			my $exon_end   = $obj->[1];

			#set the exon boundries to the image boundries in case anything odd has happened
			$exon_start    = 1 if $exon_start < 1 ;
			$exon_end      = $length if $exon_end > $length;

			my $t_url =  $trans_ref->{'web_transcript'}->_url({
				'type'   => 'Transcript',
				'action' => 'Evidence',
				't'      => $tsi,
			});
			warn "me too ",Dumper($t_url);

			##the following is very verbose and will be rewritten, but it does do the job!
			my $col1 = $Config->get('TSE_transcript','col');
			my $col2 = $Config->get('TSE_transcript','col2');
			my ($G,$tag);
			#draw and tag completely non-coding exons
			if ( ($exon_end < $coding_start) || ($exon_start > $coding_end) ) {
				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $exon_start -1 ,
					'y'         => 0.5*$h,
					'width'     => $exon_end-$exon_start +1,
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
				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $exon_start -1,
					'y'         => 0,
					'width'     => $exon_end - $exon_start + 1,
					'height'    => 2*$h,
					'colour'    => $colour,
					'absolutey' => 1,
					'title'     => $obj->[2]->stable_id,
					'href'      => $t_url,
				});
				$tag = "@{[$exon_end]}:@{[$exon_start]}";
				push @{$tags}, ["X:$tag",$col2];
				$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
				$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
				$self->push( $G );
			}

			elsif ( ($exon_start < $coding_start) && ($exon_end > $coding_start) ) {
				##draw and tag partially coding transcripts left hand)
				#non coding part
				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $exon_start -1 ,
					'y'         => 0.5*$h,
					'width'     => $coding_start-$exon_start +1,
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

				my $width = ($exon_end > $coding_end) ? $coding_end - $coding_start + 1 : $exon_end - $coding_start + 1;
					


				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $coding_start -1,
					'y'         => 0,
					'width'     => $width,
					'height'    => 2*$h,
					'colour'    => $colour,
					'absolutey' => 1,
					'title'     => $obj->[2]->stable_id,
					'href'      => $t_url,
				});
				$tag = "@{[$exon_end]}:@{[$coding_start]}";
				push @{$tags}, ["X:$tag",$col2];
				$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
				$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
				$self->push( $G );

				#draw non-coding part if there's one of these as well
				if ($exon_end > $coding_end) {
					$G = new Sanger::Graphics::Glyph::Rect({
						'x'         => $coding_end -1,
						'y'         => 0.5*$h,
						'width'     => $exon_end-$coding_end+1,
						'height'    => $h,
						'bordercolour'    => $colour,
						'absolutey' => 1,
						'title'     => $obj->[2]->stable_id,
						'href'      => $t_url,
					});
					$tag = "@{[$exon_end]}:@{[$coding_start]}";
					push @{$tags}, ["X:$tag",$col2];
					$self->join_tag( $G, "X:$tag", 0,  0, $col2, 'fill', -99 );
					$self->join_tag( $G, "X:$tag", 1,  0, $col2, 'fill', -99  );
					$self->push( $G );
				}
			}

			elsif ( ($exon_end > $coding_end) && ($exon_start < $coding_end) ) {
				##draw and tag partially coding transcripts left hand)

				#coding part
				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $exon_start -1,
					'y'         => 0,
					'width'     => $coding_end - $exon_start + 1,
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
				$G = new Sanger::Graphics::Glyph::Rect({
					'x'         => $coding_end -1 ,
					'y'         => 0.5*$h,
					'width'     => $exon_end-$coding_end +1,
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
			my $G = new Sanger::Graphics::Glyph::Line({
				'x'        => $obj->[0],
				'y'        => $h,
				'h'        =>1,
				'width'    =>$obj->[1]-$obj->[0]-1/$pix_per_bp,
				'colour'   => $colour,
				'absolutey'=>1,
			});
			$self->push($G);
		}
	}

	#draw a direction arrow
	$self->push(new Sanger::Graphics::Glyph::Line({
		'x'         => 0,
		'y'         => -4,
		'width'     => $length,
		'height'    => 0,
		'absolutey' => 1,
		'colour'    => $colour
	}));
	if($strand == 1) {
		$self->push( new Sanger::Graphics::Glyph::Poly({
			'points' => [
				$length - 4/$pix_per_bp,-2,
				$length                ,-4,
				$length - 4/$pix_per_bp,-6],
			'colour'    => $colour,
			'absolutey' => 1,
		}));
	} else {
		$self->push(new Sanger::Graphics::Glyph::Poly({
			'points'    => [ 4/$pix_per_bp,-6,
							 0            ,-4,
							 4/$pix_per_bp,-2],
			'colour'    => $colour,
			'absolutey' => 1,
		}));
	}
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('TSE_transcript','colours');
}

sub colour {
  my ($self,  $transcript, $colours, %highlights) = @_;
  my $genecol = $colours->{ $transcript->analysis->logic_name."_".$transcript->biotype."_".$transcript->status } || [];
#  warn $transcript->stable_id,' ',$transcript->analysis->logic_name."_".$transcript->biotype."_".$transcript->status;
  if(exists $highlights{lc($transcript->stable_id)}) {
    return (@$genecol, $colours->{'hi'});
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    return (@$genecol, $colours->{'hi'});
  }
 # warn @$genecol;
  return (@$genecol, undef);

}

sub href {
    my ($self, $transcript, $exon, %highlights ) = @_;

    my $tid = $transcript->stable_id();

    return "#$tid" ;
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
#	"01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
        "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",                	
        "04:Exon:$eid"    	        => "",
        '11:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
        
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=core);
    $zmenu->{'12:Export Peptide'}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);	
    }
    return $zmenu;
}

sub text_label {
	warn "drawing label";
	return 'name';
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
