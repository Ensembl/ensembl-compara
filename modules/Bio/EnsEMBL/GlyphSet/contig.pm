package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	    'text'      => 'DNA(contigs)',
    	'font'      => 'Small',
	    'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    #########
    # only draw contigs once - on one strand
    #
    return unless ($self->strand() == 1);

    # This sucks hard. We already have a map DB connection, can anyone find it?
#    my $mapdb   = new Bio::EnsEMBL::Map::DBSQL::Obj(   
#                            -user   => $ENSEMBL_DBUSER, 
#                            -dbname => $ENSEMBL_MAP,
#                            -host   => $ENSEMBL_HOST,
#                            -port   => $ENSEMBL_HOST_PORT,
#                            -ensdb  => $ENSEMBL_DB,
#                            );
#    my $fpc_map = $mapdb->get_Map( 'FPC' );
	my $vc = $self->{'container'};
    my $length   = $vc->length() +1;
    my $Config   = $self->{'config'};
	my $module = ref($self);
	$module = $1 if $module=~/::([^:]+)$/;
    my $threshold_navigation    = ($Config->get($module, 'threshold_navigation') || 2e6)*1001;
	my $show_navigation = $length < $threshold_navigation;
    my $cmap     = $Config->colourmap();
    my $col1     = $cmap->id_by_name('contigblue1');
    my $col2     = $cmap->id_by_name('contigblue2');
    my $col3     = $cmap->id_by_name('black');
    my $white    = $cmap->id_by_name('white');
    my $black    = $cmap->id_by_name('black');
    my $red      = $cmap->id_by_name('red');
    my $ystart   = 0;
    my $im_width = $Config->image_width();
    my ($w,$h)   = $Config->texthelper()->real_px2bp('Tiny');
    $w *= $length/($length-1);

    my $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart+7,
        'width'     => $self->{'container'}->length(),
        'height'    => 0,
        'colour'    => $cmap->id_by_name('grey1'),
        'absolutey' => 1,
    });
    $self->push($gline);

    my @map_contigs = ();
    @map_contigs = $vc->_vmap->each_MapContig();
    if (@map_contigs) {
        my $start     = $map_contigs[0]->start() -1;
        my $end       = $map_contigs[-1]->end();
        my $tot_width = $end - $start;
    
        my $i = 1;
    
        my %colours = (
               $i  => $col1,
               !$i => $col2,
        );
        foreach my $temp_rawcontig ( @map_contigs ) {
            my $col = $colours{$i};
            $i      = !$i;
        
            my $rend   = $temp_rawcontig->end();
            my $rstart = $temp_rawcontig->start() -1;
            my $rid    = $temp_rawcontig->contig->id();
            my $clone  = $temp_rawcontig->contig->cloneid();
            my $strand = $temp_rawcontig->strand();
        
            my $c      = $self->{'container'}->dbobj()->get_Clone($clone);
#        my $fpc    = $fpc_map->get_Clone_by_name($c->embl_id);
#        my $fpc_id = "unknown";
#        $fpc_id    = $fpc->name() if(defined $fpc);
#
#        my @matching = grep { /$rid|$clone|$fpc_id/ } $self->highlights();
#        if(scalar @matching > 0) {
#        $col = $Config->get('contig', 'hi');
#        }

            my $glyph = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $rstart,
                'y'         => $ystart+2,
                'width'     => $rend - $rstart,
                'height'    => 10,
                'colour'    => $col,
                'absolutey' => 1,
			});
			$glyph->{'zmenu'} = {
                    'caption' => $rid,
                    'Contig information'     => "/$ENV{'ENSEMBL_SPECIES'}/seqentryview?seqentry=$clone&contigid=$rid",
#            "FPC ID: $fpc_id"  => "",
#            "Request clone (FPC ID: $fpc_id)"  =>
#            "http://www.sanger.ac.uk/cgi-bin/humace/CloneRequest?clone=$fpc_id&query=Requested%20via%20Ensembl",
			} if $show_navigation;
			
            $self->push($glyph);

            $clone = $strand > 0 ? $clone."->" : "<-$clone";
        
            my $bp_textwidth = $w * length($clone) * 1.2; # add 20% for scaling text
            unless ($bp_textwidth > ($rend - $rstart)){
                my $tglyph = new Bio::EnsEMBL::Glyph::Text({
                    'x'          => int( ($rend + $rstart - $bp_textwidth)/2),
                    'y'          => $ystart+4,
                    'font'       => 'Tiny',
                    'colour'     => $white,
                    'text'       => $clone,
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
            'x'         => int(($length - $bp_textwidth)/2),
            'y'         => $ystart+4,
            'font'      => 'Tiny',
            'colour'    => $red,
            'text'      => $text,
            'absolutey' => 1,
        });
        $self->push($tglyph);
    }

    $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart,
        'width'     => $im_width,
        'height'    => 0,
        'colour'    => $col3,
        'absolutey' => 1,
        'absolutex' => 1,
    });
    $self->push($gline);
    
    $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart+14,
        'width'     => $im_width,
        'height'    => 0,
        'colour'    => $col3,
        'absolutey' => 1,
        'absolutex' => 1,    
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
            'x'         => 0 + $pos,
            'y'         => $ystart-2,
            'width'     => 0,
            'height'    => 1,
            'colour'    => $col3,
            'absolutey' => 1,
            'absolutex' => 1,
        });
        $self->push($tick);
        # the reverse strand ticks
        $tick = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $im_width - $pos,
            'y'         => $ystart+15,
            'width'     => 0,
            'height'    => 1,
            'colour'    => $col3,
            'absolutey' => 1,
            'absolutex' => 1,
        });
        $self->push($tick);
    }
    # The end ticks
    $tick = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart-2,
        'width'     => 0,
        'height'    => 1,
        'colour'    => $col3,
        'absolutey' => 1,
        'absolutex' => 1,
    });
    $self->push($tick);
    # the reverse strand ticks
    $tick = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => $im_width - 1,
        'y'         => $ystart+15,
        'width'     => 0,
        'height'    => 1,
        'colour'    => $col3,
        'absolutey' => 1,
        'absolutex' => 1,
    });
    $self->push($tick);
    
    my $vc_size_limit = $Config->get('_settings', 'default_vc_size');

    # only draw a red box if we are in contigview top and there is a detailed display
    if ($Config->script() eq "contigviewtop" && ($length <= $vc_size_limit+2)){

    # only draw focus box on the correct display...
        my $boxglyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'            => $Config->{'_wvc_start'} - $self->{'container'}->_global_start(),
            'y'            => $ystart - 4 ,
            'width'        => $Config->{'_wvc_end'} - $Config->{'_wvc_start'},
            'height'       => 22,
            'bordercolour' => $red,
            'absolutey'    => 1,
        });
        $self->push($boxglyph);

        my $boxglyph2 = new Bio::EnsEMBL::Glyph::Rect({
            'x'            => $Config->{'_wvc_start'} - $self->{'container'}->_global_start(),
            'y'            => $ystart - 3 ,
            'width'        => $Config->{'_wvc_end'} - $Config->{'_wvc_start'},
            'height'       => 20,
            'bordercolour' => $red,
            'absolutey'    => 1,
        });
        $self->push($boxglyph2);
    }
}

1;
