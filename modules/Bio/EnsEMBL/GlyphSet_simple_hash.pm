package Bio::EnsEMBL::GlyphSet_simple_hash;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $HELP_LINK = $self->check();
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
        'href'      => qq[javascript:X=window.open(\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)],

        'zmenu'     => {
            'caption'                     => 'HELP',
            "01:Track information..."     =>
qq[javascript:X=window.open(\\\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\\\',\\\'helpview\\\',\\\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\\\');X.focus();void(0)]
        }
    });
    $self->label($label);
}

sub my_label {
    my ($self) = @_;
    return 'Missing label';
}

sub features {
    my ($self) = @_;
    return ();
} 

sub _init {
    my ($self) = @_;
    my $type = $self->check();
    return unless defined $type;
    
    my $VirtualContig   = $self->{'container'};
    my $Config          = $self->{'config'};
    my $strand          = $self->strand();
    my $strand_flag     = $Config->get($type, 'str');

## If only displaying on one strand skip IF not on right strand....
    return if( $strand_flag eq 'r' && $strand != -1 ||
               $strand_flag eq 'f' && $strand != 1 );

# Get information about the VC - length, and whether or not to
# display track/navigation               
    my $vc_length      = $VirtualContig->length( );
    my $max_length     = $Config->get( $type, 'threshold' ) || 200000000;
    my $navigation     = $Config->get( $type, 'navigation' ) || 'on';
    my $max_length_nav = $Config->get( $type, 'navigation_threshold' ) || 15000000;

## VC to long to display featues dump an error message
    if( $vc_length > $max_length *1001 ) {
        $self->errorTrack( "$type only displayed for less than $max_length Kb.");
        return;
    }

## Decide whether we are going to include navigation (independent of switch) 
    $navigation = ($navigation eq 'on') && ($vc_length <= $max_length_nav *1001);
    
    my $h              = $Config->get( $type, 'track_height' ) || 8;
## Get highlights...
    my %highlights;
    @highlights{$self->highlights()} = ();
## Set up bumping bitmap    
    my @bitmap         = undef;
## Get information about bp/pixels    
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
## And the colours
       $self->{'colours'} = $Config->get($type, 'colours');
    my $feature_colour    = $Config->get($type, 'col') || $self->{'colours'} && $self->{'colours'}{'col'};
    my $label_colour      = $Config->get($type, 'lab') || $self->{'colours'} && $self->{'colours'}{'lab'};
    my $part_to_colour    = '';
    my $hi_colour         = $Config->get($type, 'hi')  || $self->{'colours'} && $self->{'colours'}{'hi'};

    my $dep            = $Config->get($type, 'dep');

    my $flag           = 1;
    foreach my $f ( $self->features ) {
## Check strand for display ##
        next if( $strand_flag eq 'b' && $strand != $f->{'strand'} );
## Check start are not outside VC.... ##
        my $start = $f->{'start'};
        next if $start>$vc_length; ## Skip if totally outside VC
        $start = 1 if $start < 1;
## Check end are not outside VC.... ##
        my $end   = $f->{'end'};
        next if $end<1;            ## Skip if totally outside VC
        $end   = $vc_length if $end>$vc_length;

        $flag = 0;
        my @tag_glyphs;
        ($feature_colour, $label_colour, $part_to_colour) = $self->colour( $f ) if $self->can('colour');
        
        my $composite = new Bio::EnsEMBL::Glyph::Composite();
        my $glyph;
        if($part_to_colour eq 'line') {
            
     #       print STDERR "PUSHING LINE\n"; 
            $composite->push( new Bio::EnsEMBL::Glyph::Space({
                'x'          => $start,
                'y'          => 0,
                'width'      => $end - $start + 1,
                'height'     => $h,
                "colour"     => $feature_colour,
                'absolutey'  => 1
            }));
            $composite->push( new Bio::EnsEMBL::Glyph::Rect({
                'x'          => $start,
                'y'          => $h/2,
                'width'      => $end - $start + 1,
                'height'     => 0,
                "colour"     => $feature_colour,
                'absolutey'  => 1
            }));
        } else {
            $composite->push( new Bio::EnsEMBL::Glyph::Rect({
                'x'          => $start,
                'y'          => 0,
                'width'      => $end - $start + 1,
                'height'     => $h,
                $part_to_colour."colour" => $feature_colour,
                'absolutey'  => 1
            }) );
        }
        my $rowheight = $h * 1.5;
        if( $self->can('tag')) {
            foreach my $tag ( $self->tag($f) ) {
                if($tag->{'style'} eq 'left-end' && $start == $f->start) {
                    my $line = new Bio::EnsEMBL::Glyph::Rect({
                        'x'          => $start,
                        'y'          => 0,
                        'width'      => 0,
                        'height'     => $h,
                        "colour"     => $tag->{'colour'},
                        'absolutey'  => 1
                    });
                    $composite->push($line);
                } elsif($tag->{'style'} eq 'right-end' && $end == $f->end) {
                    my $line = new Bio::EnsEMBL::Glyph::Rect({
                        'x'          => $end,
                        'y'          => 0,
                        'width'      => 0,
                        'height'     => $h,
                        "colour"     => $tag->{'colour'},
                        'absolutey'  => 1
                    });
                    $composite->push($line);
                } elsif($tag->{'style'} eq 'left-triangle') {
                    my $triangle_end =  $start + 3/$pix_per_bp;
                    $triangle_end = $end if( $triangle_end > $end);
    	            my $triangle = new Bio::EnsEMBL::Glyph::Poly({
                        'points'    => [ $start, 0,
                                         $start, 3,
                                         $triangle_end, 0  ],
        	    	    'colour'    => $tag->{'colour'},
            	    	'absolutey' => 1,
        	        });
                    push @tag_glyphs, $triangle;
                } elsif($tag->{'style'} eq 'triangle') {
                    my $triangle_start =  $start - 4/$pix_per_bp;
                    my $triangle_end   =  $start + 4/$pix_per_bp;
    	            my $line = new Bio::EnsEMBL::Glyph::Space({
                        'x'          => $triangle_start,
                        'y'          => $h,
                        'width'      => 8/$pix_per_bp,
                        'height'     => 0,
                        "colour"     => $tag->{'colour'},
                        'absolutey'  => 1
                    });
    	            my $triangle = new Bio::EnsEMBL::Glyph::Poly({
                        'points'    => [ $triangle_start, $h,
                                         $start, 0,
                                         $triangle_end, $h  ],
        	    	    'colour'    => $tag->{'colour'},
            	    	'absolutey' => 1,
        	        });
                    $composite->push($line);
                    push @tag_glyphs, $triangle;
                } elsif($tag->{'style'} eq 'right-triangle') {
                    my $triangle_start =  $end - 3/$pix_per_bp;
                    $triangle_start = $start if( $triangle_start < $start);
    	            my $triangle = new Bio::EnsEMBL::Glyph::Poly({
                        'points'    => [ $end, 0,
                                         $end, 3,
                                         $triangle_start, 0  ],
        	    	    'colour'    => $tag->{'colour'},
            	    	'absolutey' => 1,
        	        });
                    push @tag_glyphs, $triangle;
                } elsif($tag->{'style'} eq 'underline') {
                    my $underline_start = $tag->{'start'} || $start ;
                    my $underline_end   = $tag->{'end'}   || $end ;
                    $underline_start = 1          if $underline_start < 1;
                    $underline_end   = $vc_length if $underline_end   > $vc_length;
                    my $line = new Bio::EnsEMBL::Glyph::Rect({
                        'x'          => $underline_start,
                        'y'          => $h,
                        'width'      => $underline_end - $underline_start + 1,
                        'height'     => 0,
                        "colour"     => $tag->{'colour'},
                        'absolutey'  => 1
                    });
                    $composite->push($line);
                }
            }
        }

        if( $self->can('image_label')) {
            my ($label,$style) = $self->image_label( $f );
            my ($w,$th) = $Config->texthelper()->px2bp('Tiny');
            my $bp_textwidth = $w * length($label) * 1.1; # add 10% for scaling text
            
            if( $style eq 'overlaid' ) {
    	        if($bp_textwidth < ($end - $start)){
        		    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        		        'x'          => int(( $end + $start - $bp_textwidth)/2),
            		    'y'          => 2,
            		    'width'      => $bp_textwidth,
        	    	    'height'     => $th,
        		        'font'       => 'Tiny',
        		        'colour'     => $label_colour,
            		    'text'       => $label,
            		    'absolutey'  => 1,
        	    	});
                    $composite->push($tglyph);
                } 
            } else {
                $rowheight += $th;
                my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        		        'x'          => $start,
            		    'y'          => -2-$th,
            		    'width'      => $bp_textwidth,
        	    	    'height'     => $th,
        		        'font'       => 'Tiny',
        		        'colour'     => $label_colour,
            		    'text'       => $label,
            		    'absolutey'  => 1,
                });
                $composite->push($tglyph);
            }
	    }
## Lets see if we can Show navigation ?...
        if($navigation) {
            $composite->{'zmenu'} = $self->zmenu( $f ) if $self->can('zmenu');
            $composite->{'href'}  = $self->href(  $f ) if $self->can('href');
        }

## Are we going to bump ?
        if ($dep > 0){ # we bump
            my $bump_start = int($composite->x() * $pix_per_bp);
            $bump_start    = 0 if $bump_start < 0;
            my $bump_end = $bump_start + ($composite->width() * $pix_per_bp);
            $bump_end    = $bitmap_length if $bump_end > $bitmap_length;
            my $row = &Bump::bump_row(
                $bump_start,    $bump_end,    $bitmap_length,    \@bitmap
            );
            next if $row > $dep;
            $composite->y( $composite->y() - $row * $rowheight * $strand );
            foreach(@tag_glyphs) {
                $_->y_transform( - $row * $rowheight * $strand );
            }
        }
        $self->push($composite);
        $self->push(@tag_glyphs);

## Are we going to highlight this item...
        if(exists $highlights{$f->{'id'}}) {
            my $high = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $composite->x() - 1/$pix_per_bp,
                'y'         => $composite->y() - 1,
                'width'     => $composite->width() + 2/$pix_per_bp,
                'height'    => $h + 2,
                'colour'    => $hi_colour,
                'absolutey' => 1,
            });
            $self->unshift($high);
        }
    }
## No features show "empty track line" if option set....  ##
    $self->errorTrack( "No ".$self->my_label." in this region" )
        if( $Config->get('_settings','opt_empty_tracks')==1 && $flag );
}

1;
