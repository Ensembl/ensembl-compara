package Bio::EnsEMBL::GlyphSet::restrict;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Composite;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
    	'text'      => "Restr.Enzymes",
    	'font'      => 'Small',
    	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $PADDING = 60;
    my $col    = undef;
    my $vc     = $self->{'container'}
    my $config = $self->{'config'};
    my $cmap   = $config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');
    my $length = $vc->length;
    my $seq = $vc->subseq(-$PADDING,$length+2*$PADDING);
    my $filename = $EnsWeb::species_defs->ENSEMBL_TMP_DIR."/".&Digest::MD5::md5_hex(rand()).".restrict";
    
    open O, ">$filename.in";
    print O $seq;
    close O;
    `restrict -enzymes all -sitelen 4 -seq $filename.in -outfile $filename.out`;
    open I, "$filename.out";
    while(<I>) {
        if( my( $st, $en, $score, $name, $seq, $s_3p, $s_5p, $s_3pr, $s_5pr ) =
            /^\s*(\d+)\s*(\d+)\s*(\d+)\s*(\w+)\s*(\w+)\s*([.\d]+)\s*([.\d]+)\s*([.\d]+)\s*([.\d]+)/ ) {
            $s_3pr = -10000 if $s_3pr eq '.';
            $s_5pr = -10000 if $s_5pr eq '.';
            $s_3p = -10000 if $s_3p eq '.';
            $s_5p = -10000 if $s_5p eq '.';
            $st -= $PADDING;
            $en -= $PADDING;
            $s_3p -= $PADDING;
            $s_5p -= $PADDING;
            $s_3pr -= $PADDING;
            $s_5pr -= $PADDING;
            next if $s_3pr < 1 && $s_5pr < 1 && $s_3p < 1 && $s_5p < 1 && $st < 1 && $en < 1 ;
            next if $s_3pr > $length && $s_5pr > $length && $s_3p  > $length &&
                    $s_5p  > $length && $st    > $length && $en    > $length ;
            push @features, {
                'start' => $st,
                'end'   => $en,
                'name'  => $name,
                'seq'   => $seq,
                '3p'    => $s_3p < -10000 ? '' : $s_3p,
                '5p'    => $s_5p < -10000 ? '' : $s_5p,
                '3pr'   => $s_3pr < -10000 ? '' : $s_3pr,
                '5pr'   => $s_5pr < -10000 ? '' : $s_5pr,
            };
        }
    }
    close I;
    foreach my $f ( @features ) {
        my $start = $f->{'start'} < 1 ? 1 : $f->{'start'};
        my $end   = $f->{'end'} > $length ? $length : $f->{'end'};
        my $Composite = new Sanger::Graphics::Glyph::Composite({
            'zmenu'    => {
                'caption' => $f->{'name'},
                "Seq: $f->{'seq'}" => ''
            },
	        'x' => $start
	        'y' => 0
        });
        $Composite->push( new Sanger::Graphics::Glyph::Rect({
    	    'x'      => $start -1 ,
    	    'y'      => 0,
    	    'width'  => $end - $start +1 ,
    	    'height' => 10,
    	    'colour' => 'red',
    	    'absolutey' => 1,
    	}));
        my %points = (
            '3p' => [ 6, 10 ],
            '5p' => [ 6, 10 ],
            '3p_r' => [ 0, 0 ],
            '5p_r' => [ 0, 0 ],
        );
        foreach my $tag { keys %points } {
            my $X = $f->{ $tag };
            my $h1 = $points{ $tag }[0];
            my $h2 = $points{ $tag }[1];
            if( $X < $f->{'start'} ) { ## LH tag
                unless($f->{'start'}<1) {
                    if($X<1) { ## DO NOT DRAW DOWN TAG
                        $X = 1;
                    } else {
                        $Composite->push( new Sanger::Graphics::Glyph::Rect({
                    	    'x'      => $X -1 ,
                    	    'y'      => $h1,
                    	    'width'  => 0,
                    	    'height' => 4,
                    	    'colour' => 'black',
                    	    'absolutey' => 1,
                    	}));
                    }
                    $Composite->push( new Sanger::Graphics::Glyph::Rect({
                        'x'      => $X -1 ,
                    	'y'      => $h2,
                    	'width'  => $f->{'start'} - $X + 1,
                    	'height' => 0,
                    	'colour' => 'black',
                    	'absolutey' => 1,
                    }));
                }
            } elsif( $X >= $f->{'end'} ) { ## RH tag
                unless($f->{'end'}>$length) {
                    if($X>$length) { ## DO NOT DRAW DOWN TAG
                        $X = $length;
                    } else {
                        $Composite->push( new Sanger::Graphics::Glyph::Rect({
                    	    'x'      => $X -1 ,
                    	    'y'      => $h1,
                    	    'width'  => 0,
                    	    'height' => 4,
                    	    'colour' => 'black',
                    	    'absolutey' => 1,
                    	}));
                    }
                    $Composite->push( new Sanger::Graphics::Glyph::Rect({
                        'x'      => $f->{'end'} ,
                    	'y'      => $h2,
                    	'width'  => $X - $f->{'end'} + 1,
                    	'height' => 0,
                    	'colour' => 'black',
                    	'absolutey' => 1,
                    }));
                }
            } else { ## Withing site...
                unless($X<1 || $X>$length) {
                $Composite->push( new Sanger::Graphics::Glyph::Rect({
                    'x'      => $X -1 ,
                    'y'      => $h1,
                    'width'  => 0,
                    'height' => 4,
                    'colour' => 'black',
                    'absolutey' => 1,
                }));
            }
            my $bump_start = int($Composite->{'start'} * $pix_per_bp);
               $bump_start--; 
               $bump_start = 0 if $bump_start < 0;
            my $bump_end   = int($Composite->{'end'} * $pix_per_bp);
               $bump_end   = $bitmap_length if $bump_end > $bitmap_length;
            my $row = & Sanger::Graphics::Bump::bump_row(
                $bump_start,    $bump_end,    $bitmap_length,    \@bitmap
            );
            $Composite->y( $Composite->y() - 18 * $row * $strand );
            $self->push($Composite);
        }
    }
}

1;
