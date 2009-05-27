package Bio::EnsEMBL::GlyphSet::Psnp_legend;

use strict;

no warnings "uninitialized";

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $BOX_HEIGHT    = 6;
    my $BOX_WIDTH     = 6;
	
    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};

    my $im_width      = $Config->image_width();
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];

    my %key;
    
    my ($x,$y) = (0,0);
	
    my $snps = $vc->{'image_snps'};
	for my $int (@$snps) {
		$key{$int->{'type'}} = 1;
	}
	if ($key{'insert'}){
	  $self->push($self->Poly({
					'points'    => [ $x, $BOX_HEIGHT,
                                     ($BOX_WIDTH/2), $y,
                                     $BOX_WIDTH, $BOX_HEIGHT  ],
                    'colour'    => $Config->get('Pprot_snp','insert'),
                    'absolutex' => 1,
					'absolutey' => 1,
					'absolutewidth' => 1,
					
                }));	
           my @res = $self->get_text_width( 0, 'Insert', '', 'font'=>$fontname, 'ptsize' => $fontsize );
	   $self->push($self->Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y,
                'height'    => $h,
                'font'      => $fontname,
                'ptsize'      => $fontsize,
                'halign'     => 'left',
                'colour'    => 'black',
                'text'      => 'Insert',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH * 4 + $res[2];
	}
	if ($key{'deletion'}){
	$self->push($self->Poly({
					'points'    => [ $x, $y,
                                     $x+($BOX_WIDTH/2), $BOX_HEIGHT,
                                     $x+$BOX_WIDTH, $y   ],
                    'colour'    => $Config->get('Pprot_snp', 'deletion'),
                    'absolutex' => 1,
					'absolutey' => 1,
					'absolutewidth' => 1,
					
                }));	
           my @res = $self->get_text_width( 0, 'Deletion', '', 'font'=>$fontname, 'ptsize' => $fontsize );
	   $self->push($self->Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y,
                'height'    => $h,
                'font'      => $fontname,
                'ptsize'      => $fontsize,
                'halign'     => 'left',
                'colour'    => 'black',
                'text'      => 'Deletion',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH * 4 + $res[2];
	}
	if ($key{'syn'}){
	$self->push($self->Rect({
		'x'        => $x,
                'y'        => 4,
		'width'    => $BOX_WIDTH,
		'height'   => $BOX_HEIGHT,
		'colour'   =>  $Config->get('Pprot_snp', 'syn'),
		'absolutex' => 1,
		'absolutey' => 1,
		'absolutewidth' => 1,}));
		
        my @res = $self->get_text_width( 0, 'Synonymous', '', 'font'=>$fontname, 'ptsize' => $fontsize );
	$self->push($self->Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y ,
                'height'    => $h,
                'font'      => $fontname,
                'ptsize'      => $fontsize,
                'halign'     => 'left',
                'colour'    => 'black',
                'text'      => 'Synonymous',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH * 4 + $res[2];
	}
	if ($key{'snp'}){
	$self->push($self->Rect({
		'x'        => $x,
                'y'        => 4,
		'width'    => $BOX_WIDTH,
		'height'   => $BOX_HEIGHT,
		'colour'   =>  $Config->get('Pprot_snp', 'snp'),
		'absolutex' => 1,
		'absolutey' => 1,
		'absolutewidth' => 1,}));
        my @res = $self->get_text_width( 0, 'Non-Synonymous', '', 'font'=>$fontname, 'ptsize' => $fontsize );
	$self->push($self->Text({
                'x'         => $x + $BOX_WIDTH +5,
                'y'         => $y ,
                'height'    => $h,
                'font'      => $fontname,
                'ptsize'      => $fontsize,
                'halign'     => 'left',
                'colour'    => 'black',
                'text'      => 'Non-Synonymous',
                'absolutey' => 1,
                'absolutex' => 1,
				'absolutewidth'=>1,
            }));
	$x = $x + $BOX_WIDTH * 4 + $res[2];
	}
               
}

1;
        
