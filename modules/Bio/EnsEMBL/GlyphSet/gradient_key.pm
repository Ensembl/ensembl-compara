package Sanger::Graphics::GlyphSet::MVP_gradient;
#########
# Author: avc
# Maintainer: avc
#
use strict;
use vars qw(@ISA);
use Sanger::Graphics::GlyphSet;
@ISA = qw(Sanger::Graphics::GlyphSet);
use Sanger::Graphics::Bump;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = Sanger::Graphics::Glyph::Text->new({
                                                  'text'      => "Methylation (%)",
                                                  'font'      => 'Small',
                                                  'absolutey' => 1,
                                                 });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $container  = $self->{'container'};
    my $length     = $container->length();
    my $Config     = $self->{'config'};
    my $im_width   = $Config->image_width();

    return if ($length > $Config->get('MVP_gradient', 'cutoff'));

    my $start      = $container->start();
    my $end        = $container->end()+1;
    my $pix_per_bp = $Config->transform->{'scalex'};
    my $fontname        = "Tiny";
    my $fontwidth_bp    = $Config->texthelper->width($fontname),
    my ($fontwidth, $fontheight)       = $Config->texthelper->px2bp($fontname),

    my $coloursteps     = 100;
    my $colours         = $Config->get('MVP_gradient', 'colours') || [qw( yellow2 green3 blue)];
    my @range = $self->{'config'}->colourmap->build_linear_gradient($coloursteps, @{$colours});
    
    my $glyph_width_bp  = $length/$coloursteps;
    
    my $h = 7;
    
    for (my $i = 0; $i < $coloursteps; $i++) {
 
        my $colour          = $range[int($i)];
        
        my $grad = Sanger::Graphics::Glyph::Rect->new({
            'x'         => ($i * $glyph_width_bp),
            'y'         => 0,
            'width'     => $glyph_width_bp,
            'height'    => $h,
            'colour'    => $colour,
            'border'    => 1,
            'bordercolour'    => 'black',
            'absolutey' => 1,
			'zmenu'     => {
				            'caption'           => "Score: " . sprintf("%d", $i + 1),
				           },
        });
        $self->push($grad);
        
    }
    
    $h = 9;
    foreach my $i (0,20,40,60,80) {
        my $text    = "$i%";
        my $x       = $length * ($i/100);
        my $textg   = Sanger::Graphics::Glyph::Text->new({
                            'x'             => $x,
                            'y'             => $h,
                            'height'        => $fontheight,
                            'font'          => $fontname,
                            'colour'        => 'black',
                            'text'          => $text,
                            'absolutey'     => 1,
						     });
        $self->push($textg);
    }
    
    my $text    = "100%";
    my $textg   = Sanger::Graphics::Glyph::Text->new({
                        'x'             => 97 * $glyph_width_bp,
                        'y'             => $h,
                        'height'        => $fontheight,
                        'font'          => $fontname,
                        'colour'        => 'black',
                        'text'          => $text,
                        'absolutey'     => 1,
						 });
    $self->push($textg);
}
1;
