package Bio::EnsEMBL::GlyphSet::tilepath;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

sub init_label {
    my ($this) = @_;
    
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Tile Path',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    #########
    # only draw contigs once - on one strand
    #
    return unless ($self->strand() == -1);
    
    my $Config 			= $self->{'config'};
    my $cmap  = new ColourMap;
    my $white = $cmap->id_by_name('white');
    my $black = $cmap->id_by_name('black');

    my @bitmap         	= undef;
    my $pix_per_bp  	= $Config->transform->{'scalex'};
    my $bitmap_length 	= int($self->{'container'}->length * $pix_per_bp);

    my $ystart   = 0;
    my $im_width = $self->{'config'}->image_width();
    my ($w,$h)   = $self->{'config'}->texthelper()->px2bp('Tiny');
    my $length   = $self->{'container'}->length();
	my ($col, $lab) = ();
	
    my @asm_clones = $self->{'container'}->get_all_FPCClones();
    if (@asm_clones){

    	my $i = 1;
		if ($i%2 == 0){
		       $col  => $Config->get($Config->script(),'tilepath','col1'),
		       $lab  => $Config->get($Config->script(),'tilepath','lab1'),
		} else {
		       $col  => $Config->get($Config->script(),'tilepath','col2'),		
		       $lab  => $Config->get($Config->script(),'tilepath','lab2'),
		}
	   	foreach my $clone ( @asm_clones ) {

	    	my $id    	= $clone->name();		
			my $start	= $clone->start();
			$start = 0 if ($start < 0);
    		my $end		= $clone->end();
			$end = $self->{'container'}->length if ($end > $self->{'container'}->length);

        	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
					'absolutey' => 1,
			});

	    	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
				'x'         => $start,
				'y'         => $ystart+2,
				'width'     => $end - $start,
				'height'    => 7,
				'colour'    => $col,
				'absolutey' => 1,
				'zmenu'     => {
		    		'caption' => $id,
				},
	    	});
	    	$Composite->push($glyph);

	    	my $bp_textwidth = $w * length($id) * 1.1; # add 10% for scaling text
	    	unless ($bp_textwidth > ($end - $start)){
			my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		    	'x'          => $start + int(($end - $start)/2 - ($bp_textwidth)/2),
		    	'y'          => $ystart+2,
		    	'font'       => 'Tiny',
		    	'colour'     => $lab,
		    	'text'       => $id,
		    	'absolutey'  => 1,
			});
	    	$Composite->push($tglyph);
	    	}
			
        	if ($Config->get($Config->script(), 'tilepath', 'dep') > 0){ # we bump
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
				next if ($row > $Config->get($Config->script(), 'tilepath', 'dep'));
            	$Composite->y($Composite->y() + (1.4 * $row * $h));
				#$Composite->bordercolour($black);
        	}
        	$self->push($Composite);
 			
    	}
		$i++;
		
	}
}


1;
