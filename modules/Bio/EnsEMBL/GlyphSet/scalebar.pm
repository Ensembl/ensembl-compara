package Bio::EnsEMBL::GlyphSet::scalebar;
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

    #return unless ($self->strand() == -1);
    my $h          = 0;
    my $highlights = $self->highlights();

    my $feature_colour 	= $Config->get($Config->script(),'scalebar','col');

	my $len = $VirtualContig->length();
	my $divs = 0;
	$divs = set_scale_division($len);
	#print "Div size: $divs\n";
	#print "Number divs: ", int($len/$divs), "($len)<BR>\n";

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
	$Composite->x(0);
	$Composite->y(0);

	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      	=> 0,
		'y'      	=> 4,
		'width'  	=> $len,
		'height' 	=> $h,
		'colour' 	=> $feature_colour,
		'absolutey' => 1,
	});
	$Composite->push($glyph);

	for (my $i=0;$i<int($len/$divs); $i++){

		my $tick = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'      => $i * $divs,
	    		'y'      => 4,
	    		'width'  => 0,
	    		'height' => 2,
	    		'colour' => $feature_colour,
			'absolutey'  => 1,
		});
		$Composite->push($tick);

		my $text = $i * $divs + $VirtualContig->_global_start();
		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	    	'x'      	=> $i * $divs,
	    	'y'      	=> 8,
			'font'   	=> 'Tiny',
	    	'colour' 	=> $feature_colour,
			'text'   	=> $text,
			'absolutey' => 1,
		});
		$Composite->push($tglyph);
	}

    my $im_width = $Config->image_width();
	my $tick = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => $im_width - 1,
	    	'y'      => 4,
	    	'width'  => 0,
	    	'height' => 2,
	    	'colour' => $feature_colour,
		'absolutex'  => 1,
		'absolutey'  => 1,
	});
	$Composite->push($tick);

	$self->push($Composite);

}

1;


sub set_scale_division {

  my ($full_length) = @_;

  #return;

  my $num_of_digits = length( int( $full_length / 10 ) );
  $num_of_digits--;
  my $division = 10**$num_of_digits;
  my $first_division = $division;

  my $num_of_divs = int( $full_length / $division );
  my $i=2;
  #print "NUM OF DIVISIONS: $num_of_divs<BR>\n";
  until ( $num_of_divs < 12 ) {
    $division = $first_division * $i;
    $num_of_divs = int( $full_length / $division );
    #print "NUM OF DIVISIONS: $num_of_divs<BR>\n";
    $i += 2;
  }
  return $division;

} 
