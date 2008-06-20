package Bio::EnsEMBL::GlyphSet::non_can_intron;
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
  my $sample = 'Non-canonical splicing';
  $self->init_label_text( $sample );
}

sub _init {
	my ($self) = @_;
	my $Config  = $self->{'config'};
	my $length  = $Config->container_width();
	my $colour  = $Config->get('non_can_intron','col');

#	my $strand = $trans_ref->{'exons'}[0][2]->strand;
	my $trans_ref = $Config->{'transcript'};
	my @introns = @{$trans_ref->{'non_con_introns'}};

	##draw the introns themselves....	
	foreach my $intron (@introns) { 
		next unless defined $intron; #Skip this exon if it is not defined (can happen w/ genscans) 
		my($box_start, $box_end);
		my $exon_names = $intron->[4];
		# only draw this exon if is inside the slice
		$box_start = $intron->[0];
		$box_start = 1 if $box_start < 1 ;
		$box_end   = $intron->[1];
		$box_end    = $length if $box_end > $length;
		
		#Draw an I-bar covering the intron
		my $G = new Sanger::Graphics::Glyph::Line({
			'x'         => $box_start -1 ,
			'y'         => 0,
			'width'     => $box_end-$box_start +1,
			'height'    => 0,
			'colour'    => $colour,
			'absolutey' => 1,
			'title'     => "$exon_names",
			'href'      => '',
		});
		$self->push( $G );
		$G = new Sanger::Graphics::Glyph::Line({
			'x'         => $box_start -1 ,
			'y'         => -3,
			'width'     => 0,
			'height'    => 6,
			'colour'    => $colour,
			'absolutey' => 1,
			'title'     => "$exon_names",
			'href'      => '',
		});
		$self->push( $G );
		$G = new Sanger::Graphics::Glyph::Line({
			'x'         => $box_end ,
			'y'         => -3,
			'width'     => 0,
			'height'    => 6,
			'colour'    => $colour,
			'absolutey' => 1,
			'title'     => "$exon_names",
			'href'      => '',
		});	
		$self->push( $G )
	}
}


1;
