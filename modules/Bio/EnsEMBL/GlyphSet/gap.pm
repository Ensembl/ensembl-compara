package Bio::EnsEMBL::GlyphSet::gap;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use SiteDefs;
use Sanger::Graphics::ColourMap;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
	    'text'      => 'Gaps',
    	'font'      => 'Small',
	    'absolutey' => 1,
        'href'      => qq[javascript:X=window.open(\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#gap\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)],

        'zmenu'     => {
            'caption'                     => 'HELP',
            "01:Track information..."     =>
qq[javascript:X=window.open(\\\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#gap\\\',\\\'helpview\\\',\\\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\\\');X.focus();void(0)]
        }
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    #########
    # only draw contigs once - on one strand
    #
#    return unless ($self->strand() == 1);
    my $type = $self->check();
    return unless defined $type;


	my $vc = $self->{'container'};
    my $vc_start = $vc->_global_start();
    my $useAssembly;
    eval { ## Assembly contigs don't work - don't know enough about gaps!
        $useAssembly = $vc->has_AssemblyContigs;
        return if $useAssembly;
    };

    my $length   = $vc->length() +1;
    my $Config   = $self->{'config'};
	my $module = ref($self);
	$module = $1 if $module=~/::([^:]+)$/;
    my $threshold_navigation    = ($Config->get($module, 'threshold_navigation') || 2e6)*1001;
	my $show_navigation = $length < $threshold_navigation;
    my $highlights = join('|', $self->highlights() ) ;
    $highlights = $highlights ? "&highlight=$highlights" : '';
    my $cmap     = $Config->colourmap();
    my $col1     = $cmap->id_by_name('black');
    my $col2     = $cmap->id_by_name('grey1');
    my $col3     = $cmap->id_by_name('grey2');
    my $col4     = $cmap->id_by_name('grey3');
    my $white    = $cmap->id_by_name('white');
    my $black    = $cmap->id_by_name('black');
    my $green    = $cmap->id_by_name('green');
    my $red      = $cmap->id_by_name('red');
    my $ystart   = 3;
    my $im_width = $Config->image_width();
    my ($w,$h)   = $Config->texthelper()->real_px2bp('Tiny');
    my $clone_based = $Config->get('_settings','clone_based') eq 'yes';
    my $clone       = $Config->get('_settings','clone');
    my $param_string   = $clone_based ? "seqentry=1&clone=$clone" : ("chr=".$vc->_chr_name());
    my $global_start   = $clone_based ? $Config->get('_settings','clone_start') : $vc->_global_start();
    my $global_end     = $global_start + $length - 1;
    
    $w *= $length/($length-1);

    my $gline = new Sanger::Graphics::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart+7,
        'width'     => $length,
        'height'    => 0,
        'colour'    => $cmap->id_by_name('grey1'),
        'absolutey' => 1,
    });
    $self->push($gline);

    
    my @map_contigs = sort { $a->start <=> $b->start } $vc->_vmap->each_MapContig();

    my $i = 1;
    
    if (!@map_contigs) {
## Draw a warning track....
        ## We will have to do a clever hack to get the previous and next contig....
            my $glyph = new Sanger::Graphics::Glyph::Rect({
                'x'         => 1,
                'y'         => $ystart,
                'width'     => $length,
                'height'    => 11,
                'colour'    => $col2,
                'absolutey' => 1,
                'zmenu'     => {
                    'caption' => "Golden path gap",
                    "Location: --" => '',
                }
			});
            $self->push($glyph);
    } else { ## THIS IS THE REAL STUFF FOR HUMAN
        my $type = 'unknown';
        my $first_contig = shift @map_contigs;
        ## does the first contig start at the beginning of the VC?
        if($first_contig->start > 1) {
            ## We have a gap
            my $col = $col4;
            if( $first_contig->is_first_contig() ) {
                $type = "inter-clone?";
                $col = $col2;
            }            
            my $glyph = new Sanger::Graphics::Glyph::Rect({
                'x'         => 1,
                'y'         => $ystart,
                'width'     => $first_contig->start-1,
                'height'    => 11,
                'colour'    => $col,
                'absolutey' => 1,
                'zmenu'     => {
                    'caption' => "$type gap",
                    "Location: --".($first_contig->start + $vc_start - 2) => '',
                }
			});
            $self->push($glyph);
        }
        foreach my $temp_rawcontig ( @map_contigs ) {
            my $type = 'intra-clone';
            my $col = $col1;
            if( $first_contig->fpcctg_name() ne $temp_rawcontig->fpcctg_name() ) {
                $col = $col3;
                $type = "inter super-contig";
            } elsif( $first_contig->is_last_contig() && $temp_rawcontig->is_first_contig() ) {
                $type = "inter-clone";
                $col = $col2;
            }
            if( ($first_contig->end +1) != $temp_rawcontig->start ) {
                my $glyph = new Sanger::Graphics::Glyph::Rect({
                    'x'         => $first_contig->end + 1,
                    'y'         => $ystart,
                    'width'     => $temp_rawcontig->start - $first_contig->end,
                    'height'    => 11,
                    'colour'    => $col,
                    'absolutey' => 1,
                    'zmenu'     => {
                        'caption' => "$type gap",
                        "Location: ".($first_contig->end+$vc_start)."-".($temp_rawcontig->start + $vc_start - 2) => '',
                    }
	    		});
                $self->push($glyph);
            }
            $first_contig = $temp_rawcontig;
        }
        if($first_contig->end < ($length-1) ) {
            ## We have a gap...
            my $type = 'unknown';
            my $col = $col4;
            if( $first_contig->is_last_contig() ) {
                $type = "inter-clone?";
                $col = $col2;
            }            
            my $glyph = new Sanger::Graphics::Glyph::Rect({
                'x'         => $first_contig->end+1,
                'y'         => $ystart,
                'width'     => $length - $first_contig->end,
                'height'    => 11,
                'colour'    => $col,
                'absolutey' => 1,
                'zmenu'     => {
                    'caption' => "$type gap",
                    "Location: ".($first_contig->end+$vc_start)."--" => '',
                }
			});
            $self->push($glyph);
        }
    }
}

1;
