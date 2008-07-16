package Bio::EnsEMBL::GlyphSet::TSE_background_exon;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Line;
use Bio::EnsEMBL::GlyphSet;
use Data::Dumper;
  
@Bio::EnsEMBL::GlyphSet::TSE_background_exon::ISA = qw(Bio::EnsEMBL::GlyphSet);

#needed for drawing vertical lines on supporting evidence view
sub _init {
	my ($self) = @_;
	my $Config = $self->{'config'};
    my $flag   = $self->my_config('flag');

	#retrieve tag locations and colours calculated by TSE_transcript track
	my $tags   = $Config->{'tags'};

	foreach my $tag (@{$tags}) {
		my ($extra,$e,$s) = split ':', $tag->[0];
		my $col = $tag->[1];
		my $tglyph = new Sanger::Graphics::Glyph::Space({
			'x' => $s-1,
			'y' => 0,
			'height' => 0,
			'width'  => $e-$s,
			'colour' => '$col',
		});
		$self->join_tag( $tglyph, $tag->[0], $flag,  0, $col, 'fill', -99 );
		$self->join_tag( $tglyph, $tag->[0], 1-$flag,0, $col, 'fill', -99  );
		$self->push( $tglyph );
	}
}
1;
