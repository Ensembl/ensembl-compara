package Bio::EnsEMBL::GlyphSet::tilepath;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
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
    my $threshold_navigation    = ($Config->get('tilepath', 'threshold_navigation') || 2e6)*1001;
	my $show_navigation = $length < $threshold_navigation;
	
    my @asm_clones = $vc->get_all_FPCClones();
	my $vc_start   = $vc->_global_start();
    if (@asm_clones){

	foreach my $clone ( @asm_clones ) {

	    my $id    	= $clone->name();		
	    my $start	= $clone->start();
	    $start      = 0 if ($start < 0);
	    my $end	= $clone->end();
	    $end        = $length if ($end > $length);

		($col,$lab) = $i ? ($col1,$lab1) : ($col2,$lab2);

	    my $Composite = new Bio::EnsEMBL::Glyph::Composite({
			'y'            => 0,
			'x'            => $start,
			'absolutey'    => 1
		});
		
		$Composite->{'zmenu'} = {
				'caption' => $id,
				'EMBL id: '.$clone->embl_acc => '',
				'Jump to Contigview' => "/$ENV{'ENSEMBL_SPECIES'}/contigview?cloneid=".$clone->embl_acc,
				"loc: ".($clone->start()+$vc_start-1).'-'.($clone->end()+$vc_start-1) => '',
				"length: ".($clone->length())
	    } if $show_navigation;

	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'         => $start,
		'y'         => $ystart+2,
		'width'     => $end - $start,
		'height'    => 7,
		'colour'    => $col,
		'absolutey' => 1,
	    });
	    $Composite->push($glyph);

	    my $bp_textwidth = $w * length($id) * 1.1; # add 10% for scaling text
	    unless ($bp_textwidth > ($end - $start)){
		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		    'x'          => $start + int(($end - $start)/2 - ($bp_textwidth)/2),
		    'y'          => $ystart+2,
		    'width'      => $bp_textwidth,
		    'height'     => $h,
		    'font'       => 'Tiny',
		    'colour'     => $lab,
		    'text'       => $id,
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
	    }

	    $self->push($Composite); 			
	    $i = 1-$i;
    	}
		
    }
}


1;
