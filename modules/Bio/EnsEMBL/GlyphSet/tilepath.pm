package Bio::EnsEMBL::GlyphSet::tilepath;
use strict;
use Bump;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Tile Path',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);
    
	my $vc              = $self->{'container'};
    my $length   		= $vc->length();
    my $Config 			= $self->{'config'};
    my @bitmap         		= undef;
    my $pix_per_bp  		= $Config->transform->{'scalex'};
    my $bitmap_length 		= int($length * $pix_per_bp);

    my $ystart   		= 0;
    my $im_width 		= $Config->image_width();
    my ($w,$h)   		= $Config->texthelper()->px2bp('Tiny');
    my ($col, $lab) 	        = ();
    my $i 			= 1;
    my $dep                     = $Config->get('tilepath', 'dep');
    my $col1                    = $Config->get('tilepath', 'col1');
    my $col2                    = $Config->get('tilepath', 'col2');
    my $lab1                    = $Config->get('tilepath', 'lab1');
    my $lab2                    = $Config->get('tilepath', 'lab2');
    my $include_fish            = $Config->get('tilepath', 'fish' );
    my $threshold_navigation    = ($Config->get('tilepath', 'threshold_navigation') || 2e6)*1001;
	my $show_navigation = $length < $threshold_navigation;
	my $blue = $Config->colourmap->id_by_name('contigblue1');
	my $green = $Config->colourmap->id_by_name('black');
    my @asm_clones = $vc->get_all_FPCClones( $include_fish );
	my $vc_start   = $vc->_global_start();
    if (@asm_clones){

    my @fish_clones;
	foreach my $clone ( @asm_clones ) {

	    my $id    	= $clone->name();		
	    my $start	= $clone->start();
	    $start      = 0 if ($start < 0);
	    my $end	= $clone->end();
	    $end        = $length if ($end > $length);

		($col,$lab) = $i ? ($col1,$lab1) : ($col2,$lab2);

        my $fish_clone = undef;
	    my $Composite = new Bio::EnsEMBL::Glyph::Composite({
			'y'            => 0,
			'x'            => $start,
			'absolutey'    => 1
		});
		
	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
    		'x'         => $start,
	    	'y'         => $ystart+2,
    		'width'     => $end - $start,
    		'height'    => 7,
    		'colour'    => $col,
    		'absolutey' => 1,
	    });
	    $Composite->push($glyph);

        if($show_navigation) {
    		$Composite->{'zmenu'} = {
				'caption' => $id || $clone->embl_acc,
				'02:EMBL id: '.$clone->embl_acc => '',
				"03:loc: ".($clone->start()+$vc_start-1).'-'.($clone->end()+$vc_start-1) => '',
				"04:length: ".($clone->length()) => '',
            };
            $Composite->{'zmenu'}->{'06:Jump to Contigview'} = "/$ENV{'ENSEMBL_SPECIES'}/contigview?clone=".$clone->embl_acc
                if $ENV{'ENSEMBL_SCRIPT'} ne 'contigview' ;
	    } 

        if( $include_fish eq 'FISH' ) {
            my $fish = $clone->FISHmap();
            if($fish ne '') {
            	$Composite->{'zmenu'}->{"05:FISH: $fish"} = '' if( $show_navigation);
                my $triangle_end =  $start + 3/$pix_per_bp;
                $triangle_end = $end if( $triangle_end > $end);
    	        $fish_clone = new Bio::EnsEMBL::Glyph::Poly({
                    'points'    => [ $start, $ystart+2,
                                     $start, $ystart+5,
                                     $triangle_end, $ystart+2  ],
    	    	    'colour'    => $fish=~/^\*/ ? $green : $blue,
        	    	'absolutey' => 1,
    
        	    });
            }
        }



	    my $bp_textwidth = $w * length($id || $clone->embl_acc) * 1.1; # add 10% for scaling text
	    unless ($bp_textwidth > ($end - $start)){
    		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
    		    'x'          => int(( $end + $start - $bp_textwidth)/2),
    		    'y'          => $ystart+2,
    		    'width'      => $bp_textwidth,
    		    'height'     => $h,
    		    'font'       => 'Tiny',
    		    'colour'     => $lab,
    		    'text'       => $id || $clone->embl_acc,
    		    'absolutey'  => 1,
    		});
	    	$Composite->push($tglyph);
	    }
        
	    if ($dep > 0) { # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);

            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = &Bump::bump_row(
			    $bump_start,
				$bump_end,
				$bitmap_length,
				\@bitmap
            );
    		next if ($row > $dep);
            $Composite->y($Composite->y() + (1.4 * $row * $h));
            if($fish_clone) {
                $fish_clone->transform( {'translatey' => (1.4 * $row * $h)} );
            }
	    }

	    $self->push($Composite); 			
	    $i = 1-$i;
    	    push @fish_clones,$fish_clone if($fish_clone);
    	}
        foreach( @fish_clones ) { $self->push($_); }		
    }
}


1;
