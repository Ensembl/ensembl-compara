package Bio::EnsEMBL::GlyphSet::contig;
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
	'text'      => 'DNA(contigs)',
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
    return unless ($self->strand() == 1);

	# This sucks hard. We already have a map DB connection, can anyone find it?
    my $mapdb   = new Bio::EnsEMBL::Map::DBSQL::Obj(   
                        -user   => $ENSEMBL_DBUSER, 
                        -dbname => $ENSEMBL_MAP,
                        -host   => $ENSEMBL_HOST,
                        -port   => $ENSEMBL_HOST_PORT,
                        -ensdb  => $ENSEMBL_DB,
                        );
    my $fpc_map = $mapdb->get_Map( 'FPC' );

    my $col   = undef;
    my $cmap  = new ColourMap;
    my $col1  = $cmap->id_by_name('contigblue1');
    my $col2  = $cmap->id_by_name('contigblue2');
    my $col3  = $cmap->id_by_name('black');
    my $white = $cmap->id_by_name('white');
    my $black = $cmap->id_by_name('black');
    my $red   = $cmap->id_by_name('red');

    my $ystart = 75;
    my $im_width = $self->{'config'}->image_width();
	my ($w,$h) = $self->{'config'}->texthelper()->px2bp('Tiny');
	my $length = $self->{'container'}->length();

    my $gline = new Bio::EnsEMBL::Glyph::Rect({
    	'x'      => 1,
    	'y'      => $ystart+7,
    	'width'  => $im_width,
    	'height' => 0,
    	'colour' => $cmap->id_by_name('grey1'),
		'absolutey' => 1,
		'absolutex' => 1,
    });
    $self->push($gline);


    my @map_contigs = ();
	@map_contigs = $self->{'container'}->_vmap->each_MapContig();
    if (@map_contigs){
		my $start = $map_contigs[0]->start();
    	my $end   = $map_contigs[-1]->end();
    	my $tot_width = $end - $start;


    	my $i = 0;

    	foreach my $temp_rawcontig ( @map_contigs ) {
			if($i%2 == 0){
	    		$col = $col2;
			} else {
	    		$col = $col1;
			}
			$i++;
			my $rend = $temp_rawcontig->end();
			my $rstart = $temp_rawcontig->start();
			my $rid = $temp_rawcontig->contig->id();
			my $clone = $temp_rawcontig->contig->cloneid();

    		my $c = $self->{'container'}->dbobj()->get_Clone($clone);
			my $fpc = $fpc_map->get_Clone_by_name($c->embl_id);
			my $fpc_id;
			if( defined $fpc ) {
			   $fpc_id= $fpc->name();
			   $fpc_id ||= "unknown";
			} else {
			   $fpc_id = "unknown";
			}
			

			my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'      => $rstart,
	    		'y'      => $ystart+2,
	    		'width'  => $rend - $rstart,
	    		'height' => 10,
	    		'colour' => $col,
	    		'absolutey'  => 1,
	    		'zmenu' => {
					'caption' => $rid,
					'Contig information'     => "/perl/seqentryview?seqentry=$clone&contigid=$rid",
					"FPC clone ID: $fpc_id"     	 => "",
					"Request clone $fpc_id"     => "http://www.sanger.ac.uk/Teams/Team63/CloneRequest/",
	    		},
			});
			$self->push($glyph);

			my $bp_textwidth = $w * length($clone) * 1.1; # add 10% for scaling text
			unless ($bp_textwidth > ($rend - $rstart)){
	    		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
				'x'      => $rstart + int(($rend - $rstart)/2 - ($bp_textwidth)/2),
				'y'      => $ystart+4,
				'font'   => 'Tiny',
				'colour' => $white,
				'text'   => $clone,
				'absolutey'  => 1,
	    		});
	    		$self->push($tglyph);
			}
    	}
    } else {
		# we are in the great void of golden path gappiness..
		my $text = "Golden path gap - no contigs to display!";
		my $bp_textwidth = $w * length($text);
	    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		'x'      => int(($length)/2 - ($bp_textwidth)/2),
		'y'      => $ystart+4,
		'font'   => 'Tiny',
		'colour' => $red,
		'text'   => $text,
		'absolutey'  => 1,
	    });
	    $self->push($tglyph);
	}
    my $gline = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => 0,
	'y'      => $ystart,
	'width'  => $im_width,
	'height' => 0,
	'colour' => $col3,
	'absolutey'  => 1,
	'absolutex'  => 1,
    });
    $self->push($gline);
    
    my $gline = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => 0,
	'y'      => $ystart+14,
	'width'  => $im_width,
	'height' => 0,
	'colour' => $col3,
	'absolutey'  => 1,
	'absolutex'  => 1,
    });
    $self->push($gline);
    
	## pull in our subclassed methods if necessary
	if ($self->can('add_arrows')){
		$self->add_arrows($im_width, $black, $ystart);
	}

    my $tick;
    my $interval = int($im_width/10);
    for (my $i=1; $i <=9; $i++){
	my $pos = $i * $interval;
	# the forward strand ticks
	$tick = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => 0 + $pos,
	    'y'      => $ystart-2,
	    'width'  => 0,
	    'height' => 1,
	    'colour' => $col3,
	    'absolutey'  => 1,
	    'absolutex'  => 1,
	});
	$self->push($tick);
	# the reverse strand ticks
	$tick = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => $im_width - $pos,
	    'y'      => $ystart+15,
	    'width'  => 0,
	    'height' => 1,
	    'colour' => $col3,
	    'absolutey'  => 1,
	    'absolutex'  => 1,
	});
	$self->push($tick);
    }
    # The end ticks
    $tick = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => 0,
	'y'      => $ystart-2,
	'width'  => 0,
	'height' => 1,
	'colour' => $col3,
	'absolutey'  => 1,
	'absolutex'  => 1,
    });
    $self->push($tick);
    # the reverse strand ticks
    $tick = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => $im_width - 1,
	'y'      => $ystart+15,
	'width'  => 0,
	'height' => 1,
	'colour' => $col3,
	'absolutey'  => 1,
	'absolutex'  => 1,
    });
    $self->push($tick);
    
	my $vc_size_limit = $self->{'config'}->get('contigviewtop','_settings','default_top_vc_size');
	#print STDERR "VC size limit: $vc_size_limit\n";
	#print STDERR "VC size: ", $self->{'container'}->length(), "\n";

	# only draw a red box if we are in contigview top and there is a detailed display
	if ($self->{'config'}->script() eq "contigviewtop" && ($length <= $vc_size_limit+1)){
		# only draw focus box on the correct display...
    	my $boxglyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => $self->{'config'}->{'_wvc_start'} - $self->{'container'}->_global_start(),
		'y'      => $ystart - 4 ,
		'width'  => $self->{'config'}->{'_wvc_end'} - $self->{'config'}->{'_wvc_start'},
		'height' => 22,
		'bordercolour' => $red,
		'absolutey'  => 1,
		'id'	=> 'enigma',
		'zmenu'     => { foo => 'foo' },
    	});
    	$self->push($boxglyph);

    	my $boxglyph2 = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => $self->{'config'}->{'_wvc_start'} - $self->{'container'}->_global_start(),
		'y'      => $ystart - 3 ,
		'width'  => $self->{'config'}->{'_wvc_end'} - $self->{'config'}->{'_wvc_start'},
		'height' => 20,
		'bordercolour' => $red,
		'absolutey'  => 1,
		'id'	=> 'enigma',
		'zmenu'     => { foo => 'foo' },
    	});
    	$self->push($boxglyph2);
	}

}


1;
