package Bio::EnsEMBL::GlyphSet::trace;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

	return unless ($self->strand() == -1);
    my $y          = 0;
    my $h          = 8;
    my $highlights = $self->highlights();
	my $trace_col = $Config->get($Config->script(),'trace','col');

    my @bitmap      = undef;
    my ($im_width, $im_height) = $Config->dimensions();
    my $bitmap_length = $VirtualContig->length();
    my $type = $Config->get($Config->script(),'gene','src');
    my @xf=$VirtualContig->get_all_ExternalFeatures();
	my @trace;
	
	foreach my $f (@xf){
		if ($f->isa("Bio::EnsEMBL::FeaturePair")) {
			# An Exonerate trace match
			if ($f->analysis->dbID == 7) { # its an exonerate mouse trace match
				push (@trace, $f);
					print SDTERR "$f\n"
			}
		}	
	}

	my $rect;
	my $colour;
    foreach my $s (@trace) {
		my $x = $s->start();
		my $x1 = $s->end();
		print STDERR "Trace start: ", $x, " ID:", $s->id(),  "\n";
		my $traceglyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      => $x,
			'y'      => 0,
			'width'  => $x1-$x,
			'height' => $h,
			'colour' => $trace_col,
			'absolutey'  => 1,
			'zmenu'     => { caption => $s->id() },
		});
		$self->push($traceglyph);
	}

}

1;
