package Bio::EnsEMBL::GlyphSet_simple;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
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
    
    my $h              = 9;
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
    my $hi_colour         = $Config->get($type, 'hi')  || $self->{'colours'} && $self->{'colours'}{'hi'};

    my $dep            = $Config->get($type, 'dep');

    my $flag           = 1;
    foreach my $f ( $self->features ) {
## Check strand for display ##
        next if( $strand_flag eq 'b' && $strand != $f->strand );
## Check start are not outside VC.... ##
        my $start = $f->start();
        next if $start>$vc_length; ## Skip if totally outside VC
        $start = 1 if $start < 1;
## Check end are not outside VC.... ##
        my $end   = $f->end();
        next if $end<1;            ## Skip if totally outside VC
        $end   = $vc_length if $end>$vc_length;

        $flag = 0;
        ($feature_colour, $label_colour) = $self->colour( $f ) if $self->can('colour');
        
        my $glyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'          => $start,
            'y'          => 0,
            'width'      => $end - $start + 1,
            'height'     => $h,
            'colour'     => $feature_colour,
            'absolutey'  => 1
        });
## Lets see about placing labels on objects...        
        my $composite;
        my $rowheight = int($h * 1.5);
        if( $self->can('image_label')) {
            my ($label,$style) = $self->image_label( $f );
            my ($w,$th) = $Config->texthelper()->px2bp('Tiny');
            my $bp_textwidth = $w * length($label) * 1.1; # add 10% for scaling text
            
            if( $style eq 'overlaid' ) {
    	        if($bp_textwidth > ($end - $start)){
                    $composite = $glyph;
                } else {
                    print STDERR "X: $label - $label_colour\n";
        		    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        		        'x'          => int(( $end + $start - $bp_textwidth)/2),
            		    'y'          => 1,
            		    'width'      => $bp_textwidth,
        	    	    'height'     => $th,
        		        'font'       => 'Tiny',
        		        'colour'     => $label_colour,
            		    'text'       => $label,
            		    'absolutey'  => 1,
        	    	});
                    $composite = new Bio::EnsEMBL::Glyph::Composite();
                    $composite->push($glyph,$tglyph);
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
                $composite = new Bio::EnsEMBL::Glyph::Composite();
                $composite->push($glyph,$tglyph);
            }
	    } else {
            $composite = $glyph;
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
            my $bump_end = $bump_start + 1 + ($composite->width() * $pix_per_bp);
            $bump_end    = $bitmap_length if $bump_end > $bitmap_length;
            my $row = &Bump::bump_row(
                $bump_start,    $bump_end,    $bitmap_length,    \@bitmap
            );
            next if $row > $dep;
            $composite->y( $composite->y() - $row * $rowheight * $strand );
        }
        $self->push($composite);
## Are we going to highlight this item...
        if(exists $highlights{$f->id()}) {
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
