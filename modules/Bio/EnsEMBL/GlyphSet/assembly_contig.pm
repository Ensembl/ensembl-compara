package Bio::EnsEMBL::GlyphSet::assembly_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Space;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	    'text'      => 'Assembly Ctgs',
    	'font'      => 'Small',
	    'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    ########## only draw contigs once - on one strand
    return unless ($self->strand() == -1);
	my $vc = $self->{'container'};
    my $useAssembly;
    eval {
        $useAssembly = $vc->has_AssemblyContigs;
    };
    print STDERR "Using assembly $useAssembly\n";
    return unless $useAssembly;
    my $length   = $vc->length() +1;
    my $Config   = $self->{'config'};
	my $module = ref($self);
	$module = $1 if $module=~/::([^:]+)$/;
    my $threshold_navigation    = ($Config->get($module, 'threshold_navigation') || 2e6)*1001;
	my $show_navigation = $length < $threshold_navigation;
    my $highlights = join('|', $self->highlights() ) ;
    $highlights = $highlights ? "&highlight=$highlights" : '';
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
    my $clone_based = $Config->get('_settings','clone_based') eq 'yes';
    my $clone       = $Config->get('_settings','clone');
    my $param_string   = $clone_based ? "seqentry=1&clone=$clone" : ("chr=".$vc->_chr_name());
    my $global_start   = $clone_based ? $Config->get('_settings','clone_start') : $vc->_global_start();
    my $global_end     = $global_start + $length - 1;
    
    $w *= $length/($length-1);

    my $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,
        'y'         => $ystart+7,
        'width'     => $length,
        'height'    => 0,
        'colour'    => $cmap->id_by_name('grey1'),
        'absolutey' => 1,
    });
    $self->push($gline);

    my @map_contigs = $vc->each_AssemblyContig;
    if (@map_contigs) {
        my $start   = $map_contigs[0]->chr_start - 1;
        my $end     = $map_contigs[-1]->chr_end;
        my $tot_width = $end - $start;
        my $i = 1;
        my %colours = ( $i  => $col1, !$i => $col2 );

        foreach my $temp_rawcontig ( @map_contigs ) {
            my $col = $colours{$i};
            $i      = !$i;
            my $cend   = $temp_rawcontig->chr_end;
            my $cstart = $temp_rawcontig->chr_start -1;
            my $rend   = $temp_rawcontig->chr_end - $vc->_global_start + 1;
            my $rstart = $temp_rawcontig->chr_start - $vc->_global_start + 1;
            my $rid    = $temp_rawcontig->display_id;
            my $strand = $temp_rawcontig->orientation;
            $rend   = $length if $rend>$length;
            $rstart = 1       if $rstart<1;
            my $glyph = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $rstart,
                'y'         => $ystart+2,
                'width'     => $rend - $rstart,
                'height'    => 10,
                'colour'    => $col,
                'absolutey' => 1,
			});
            my $cid = $rid;
            $cid=~s/^([^\.]+\.[^\.]+)\..*/$1/;
            my $MINLEN = 100000;
            if($cend-$cstart < $MINLEN) {
                $cstart = int(($cend+$cstart-$MINLEN)/2);
                $cend   = $cstart + $MINLEN -1;
            }
            $glyph->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=".
                        $vc->_chr_name()."&vc_start=$cstart&vc_end=$cend";
			$glyph->{'zmenu'} = {
                    'caption' => $rid,
                    '02:Centre on contig' => $glyph->{'href'}
			} if $show_navigation;
			
            $self->push($glyph);

            $clone = $strand > 0 ? $rid."->" : "<-$rid";
        
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
}

