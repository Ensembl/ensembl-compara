package Bio::EnsEMBL::GlyphSet::TSE_background_exon;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Line;
use Bio::EnsEMBL::GlyphSet;
use Data::Dumper;
  
@Bio::EnsEMBL::GlyphSet::TSE_background_exon::ISA = qw(Bio::EnsEMBL::GlyphSet);
sub _init {
	my ($self) = @_;
	my $Config        = $self->{'config'};
	my $container     = $self->{'container'};
	my $length  = $container->length;
	my $start = $container->start();
	my $colour        = $Config->get('TSE_background_exon_1','col' );
	my $pix_per_bp    = $Config->transform->{'scalex'};
	
	my $tag = $Config->get('TSE_background_exon_1','tag');	
    my $flag=$self->my_config('flag');

	#retrieve each exon and sort by start / end
	my $trans_ref = $Config->{'transcript'};
	my %exons = ();
	foreach my $exon (@{$trans_ref->{'exons'}}) {
		my $tag = "@{[$exon->[2]->start]}:@{[$exon->[2]->end]}";
		$exons{"$exon->[0]:$exon->[1]:$tag"}++; 
	}
	my @exons = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } map { [ split /:/, $_ ] } keys %exons;

	#draw spacer glyphs and add tags
	foreach my $exon (@exons) {
		my( $S,$E,$S2,$E2 ) = @$exon;
		next if $E<1;
		next if $S>$length;
		my $tag = "@{[$E2]}:@{[$S2]}";
		$S = 1 if $S < 1;
		$E = $length if $E > $length;
		my $tglyph = new Sanger::Graphics::Glyph::Space({
			'x' => $S-1,
			'y' => 0,
			'height' => 0,
			'width'  => $E-$S+1,
			'colour' => '$colour',
		});
		$self->join_tag( $tglyph, "X:$tag", $flag,  0, $colour, 'fill', -99 );
		$self->join_tag( $tglyph, "X:$tag", 1-$flag,0, $colour, 'fill', -99  );
		$self->push( $tglyph );
	}
}
1;
