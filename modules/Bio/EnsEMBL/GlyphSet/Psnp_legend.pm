package Bio::EnsEMBL::GlyphSet::Psnp_legend;
use strict;
no warnings "uninitialized";
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Poly;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'SNP legend',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $BOX_HEIGHT    = 6;
    my $BOX_WIDTH     = 6;
    my $FONTNAME      = "Tiny";
	
    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};

    my $im_width      = $Config->image_width();
	my $TEXT_WIDTH 	  = $Config->texthelper->width($FONTNAME);
	my $TEXT_HEIGHT 	  = $Config->texthelper->height($FONTNAME);
	my %key;
    
    my ($x,$y) = (0,0);
	
    my $snps = $vc->{'image_snps'};
	for my $int (@$snps) {
		$key{$int->{'type'}} = 1;
	}
	if ($key{'insert'}){
	  $self->push(new Sanger::Graphics::Glyph::Poly({
					'points'    => [ $x, $BOX_HEIGHT,
                                     ($BOX_WIDTH/2), $y,
                                     $BOX_WIDTH, $BOX_HEIGHT  ],
                    'colour'    => $Config->get('Pprot_snp','insert'),
                    'absolutex' => 1,
					'absolutey' => 1,
					'absolutewidth' => 1,
					
                }));	
	   $self->push(new Sanger::Graphics::Glyph::Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y,
                'height'    => $TEXT_HEIGHT,
                'font'      => $FONTNAME,
                'colour'    => 'black',
                'text'      => 'Insert',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH + ($TEXT_WIDTH * 13);
	}
	if ($key{'deletion'}){
	$self->push(new Sanger::Graphics::Glyph::Poly({
					'points'    => [ $x, $y,
                                     $x+($BOX_WIDTH/2), $BOX_HEIGHT,
                                     $x+$BOX_WIDTH, $y   ],
                    'colour'    => $Config->get('Pprot_snp', 'deletion'),
                    'absolutex' => 1,
					'absolutey' => 1,
					'absolutewidth' => 1,
					
                }));	
	   $self->push(new Sanger::Graphics::Glyph::Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y,
                'height'    => $TEXT_HEIGHT,
                'font'      => $FONTNAME,
                'colour'    => 'black',
                'text'      => 'Deletion',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH +($TEXT_WIDTH * 17);
	}
	if ($key{'syn'}){
	$self->push(new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'width'    => $BOX_WIDTH,
		'height'   => $BOX_HEIGHT,
		'colour'   =>  $Config->get('Pprot_snp', 'syn'),
		'absolutex' => 1,
		'absolutey' => 1,
		'absolutewidth' => 1,}));
		
	$self->push(new Sanger::Graphics::Glyph::Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y ,
                'height'    => $TEXT_HEIGHT,
                'font'      => $FONTNAME,
                'colour'    => 'black',
                'text'      => 'Synonymous',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH +($TEXT_WIDTH * 18);
	}
	if ($key{'snp'}){
	$self->push(new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'width'    => $BOX_WIDTH,
		'height'   => $BOX_HEIGHT,
		'colour'   =>  $Config->get('Pprot_snp', 'snp'),
		'absolutex' => 1,
		'absolutey' => 1,
		'absolutewidth' => 1,}));
	$self->push(new Sanger::Graphics::Glyph::Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y ,
                'height'    => $TEXT_HEIGHT,
                'font'      => $FONTNAME,
                'colour'    => 'black',
                'text'      => 'Non-Synonymous',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH +($TEXT_WIDTH * 22);
	}
               
}

1;
        
