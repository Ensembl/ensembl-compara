package Bio::EnsEMBL::GlyphSet::ruler;
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

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Length',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config        = $self->{'config'};

    return unless ($self->strand() == 1);
    my $len = $self->{'container'}->length();
    my $global_start = $self->{'container'}->_global_start();
    my $global_end = $self->{'container'}->_global_end();
    my $highlights = $self->highlights();
    my $im_width    = $Config->image_width();
    my $feature_colour 	= $Config->get($Config->script(),'ruler','col');

    my $fontname = "Tiny";
    my $fontheight = $Config->texthelper->height($fontname),
    my ($w,$h) = $Config->texthelper->px2bp($fontname),


	my $text = int($global_end - $global_start);		
	$text = bp_to_nearest_unit($text);		
	my $bp_textwidth = $w * length($text);
	    
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	'x'      	=> int($len/2) - int($bp_textwidth/2),
	'y'      	=> 2,
	'height'	=> $fontheight,
	'font'   	=> $fontname,
	'colour' 	=> $feature_colour,
	'text'   	=> $text,
	'absolutey' => 1,
	});
	$self->push($tglyph);

	my $bp_textwidth = $w * (length($text)+3);
	my $lglyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => 0,
	    'y'      => 6,
	    'width'  => int($len/2) - int($bp_textwidth/2),
	    'height' => 0,
	    'colour' => $feature_colour,
	    'absolutey'  => 1,
	});
	$self->push($lglyph);

	my $bp_textwidth = $w * (length($text)+3);
	my $rglyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => int($len/2) + int($bp_textwidth/2),
	    'y'      => 6,
	    'width'  => int($len) - (int($len/2) + int($bp_textwidth/2)),
	    'height' => 0,
	    'colour' => $feature_colour,
	    'absolutey'  => 1,
	});
	$self->push($rglyph);
 	
	# to get aroung px->postion problems we make each arrow head
	# exactly 2 text chars long
	# add the left arrow head....
    my $gtriagl = new Bio::EnsEMBL::Glyph::Poly({
        'points'       => [0,6, ($w*2),3, ($w*2),9],
        'colour'       => $feature_colour,
        'absolutey'    => 1,
    });    
    $self->push($gtriagl);
	
	# add the right arrow head....
    my $gtriagr = new Bio::EnsEMBL::Glyph::Poly({
        'points'       => [$len,6, ($len-$w*2),3, ($len-$w*2),9],
        'colour'       => $feature_colour,
        'absolutey'    => 1,
    });
    $self->push($gtriagr);
    
}


1;

sub bp_to_nearest_unit {
    my $bp = shift;
    my @units = qw( bp Kb Mb Gb Tb );
    
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];
    my $unit_str;

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    if ( $unit ne "bp"  ){
	$unit_str = sprintf( "%.2f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), $unit );
    }else{
	$unit_str = $value. $unit;
    }

    return $unit_str;
}
