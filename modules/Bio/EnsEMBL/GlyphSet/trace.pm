package Bio::EnsEMBL::GlyphSet::trace;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Mouse trace',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my $highlights    = $self->highlights();
    my $trace_col     = $Config->get('trace','col');
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type          = $Config->get('gene','src');
#	print STDERR "repeat.pm: ".$self->glob_bp()." *\n";	
    my @xf            = $VirtualContig->get_all_ExternalFeatures( $self->glob_bp() );
    my @trace;
    
    foreach my $f (@xf){
		#print STDERR "$f ", $f->id(), " ", $f->source_tag(), "\n";
		if ($f->isa("Bio::EnsEMBL::Ext::FeaturePair") || $f->isa("Bio::EnsEMBL::FeaturePair")) {
	    	if ($f->source_tag() eq "trace") { # its an exonerate_gapped mouse trace match
				#print STDERR "\tsaved", $f->id(),"\n";
				push (@trace, $f);
	    	}
		}	
    }
    
    my $rect;
    my $colour;
    foreach my $s (@trace) {
	my $x = $s->start();
	my $x1 = $s->end();
	my $id = $s->id();
	#print STDERR "Trace start: ", $x, " ID:", $s->id(),  "\n";
	my $traceglyph = new Bio::EnsEMBL::Glyph::Rect({
	    'x'        => $x,
	    'y'        => 0,
	    'width'    => $x1-$x,
	    'height'   => $h,
	    'colour'   => $trace_col,
	    'absolutey'=> 1,
	    'zmenu'    => { 
		'caption'    => "$id",
		'View trace' => "http://trace.ensembl.org/perl/traceview?tracedb=0&traceid=$id",		
	    },
	});
	$self->push($traceglyph);
    }
}

1;
