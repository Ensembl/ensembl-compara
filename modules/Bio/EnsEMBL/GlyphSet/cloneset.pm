package Bio::EnsEMBL::GlyphSet::cloneset;
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
	'text'      => '1MB cloneset',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);
    
    my $vc   		    = $self->{'container'};
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
    my $dep                     = $Config->get('cloneset', 'dep');
    my $col1                    = $Config->get('cloneset', 'col1');
    my $col2                    = $Config->get('cloneset', 'col2');
    my $lab1                    = $Config->get('cloneset', 'lab1');
    my $lab2                    = $Config->get('cloneset', 'lab2');
	my $blue = $Config->colourmap->id_by_name('contigblue1');
	my $green = $Config->colourmap->id_by_name('black');

	my $cloneset = $self->{'container'}->dbobj->_db_handle->selectall_arrayref(
		"select cs_c.cloneid, cs_c.name
		   from cloneset as cs, cloneset_clone as cs_c
		  where cs_c.clonesetid = cs.clonesetid
		    and cs.name = ?", {} , '1MB'
	);
	my %hash;
	%hash = map { @$_ } @$cloneset;

    my @asm_clones = $vc->get_all_FPCClones( 'FISH' );

	my @cloneset_clones = map { exists $hash{$_->embl_acc} ? ([$_, $hash{$_->embl_acc}]) : () }
		@asm_clones;

	my $vc_start = $vc->_global_start;
    my @fish_clones;
    if (@cloneset_clones){

	foreach my $clone_ref ( @cloneset_clones	 ) {
        my $fish_clone;
		my $clone   = $clone_ref->[0];
		my $synonym = $clone_ref->[1];
	    my $id    	= $clone->name();		
	    my $start	= $clone->start();
	    $start      = 0 if ($start < 0);
	    my $end	= $clone->end();
	    $end        = $length if ($end > $length);

	    if ($i%2 == 0){
			$col  = $col1;
			$lab  = $lab1;
	    } else {
			$col  = $col2;
			$lab  = $lab2;
	    }
			
        my $fish = $clone->FISHmap(); $fish = "$fish";
	    my $Composite = new Bio::EnsEMBL::Glyph::Composite({
		'y'            => 0,
		'x'            => $start,
		'absolutey'    => 1,
		'zmenu'     => {
			'caption' 				 => "$id",
			"EMBL ID: ".$clone->embl_acc() => '',
			"synonym: $synonym" 	 => '',
			'Jump to Contigview' =>
			"/$ENV{'ENSEMBL_SPECIES'}/contigview?cloneid=".$clone->embl_acc,
			"loc: ".($clone->start()+$vc_start-1).'-'.($clone->end()+$vc_start-1) => '',
			"length: ".($clone->length())=> '',
            "FISH: $fish" => ''

		}
	    });

	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'         => $start,
		'y'         => $ystart+2,
		'width'     => $end - $start,
		'height'    => 7,
		'colour'    => $col,
		'absolutey' => 1
	    });
	    $Composite->push($glyph);
        if($fish ne '') {
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

	    my $bp_textwidth = $w * length($synonym) * 1.1; # add 10% for scaling text
	    unless ($bp_textwidth > ($end - $start)){
		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		    'x'          => $start + int(($end - $start)/2 - ($bp_textwidth)/2),
		    'y'          => $ystart+2,
		    'width'      => $bp_textwidth,
		    'height'     => $h,
		    'font'       => 'Tiny',
		    'colour'     => $lab,
		    'text'       => $synonym,
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
        push @fish_clones, $fish_clone if($fish_clone);
    
	    $self->push($Composite); 			
	    $i++;
    	}
        foreach( @fish_clones ) { $self->push($_); }		
		
    }
}


1;
