package Bio::EnsEMBL::GlyphSet;
use strict;
use Bio::Root::RootI;
use Exporter;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Space;

use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Exporter Bio::Root::RootI);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

#########
# constructor
#
sub new {
    my ($class, $VirtualContig, $Config, $highlights, $strand, $extra_config) = @_;
    my $self = {
	'glyphs'     => [],
	'x'          => undef,
	'y'          => undef,
	'width'      => undef,
	'highlights' => $highlights,
	'strand'     => $strand,
	'minx'       => undef,
	'miny'       => undef,
	'maxx'       => undef,
	'maxy'       => undef,
	'label'      => undef,
    'bumped'     => undef,
    'bumpbutton' => undef,
	'label2'     => undef,	
	'container'  => $VirtualContig,
	'config'     => $Config,
	'extras'     => $extra_config,
    };

    bless($self, $class);
    $self->init_label() if($self->can('init_label'));

#    &eprof_start(qq(glyphset_$class));
#    $self->_init($VirtualContig, $Config);
#    &eprof_end(qq(glyphset_$class));

    return $self;
}

#########
# _init creates masses of Glyphs from a data source.
# It should executes bumping and globbing on the fly and also
# keep track of x,y,width,height as it goes.
#
sub _init {
    my ($self) = @_;
    print STDERR qq($self unimplemented\n);
}

# Gets the number of Base Pairs per pixel
sub basepairs_per_pixel {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $pixels = $Config->get( '_settings' ,'width' );
    return (defined $pixels && $pixels) ? $self->{'container'}->length() / $pixels : undef; 
}    

sub glob_bp {
    my ($self) = @_;
    return int($self->basepairs_per_pixel()*2);
}
#########
# return our list of glyphs
#
sub glyphs {
    my ($self) = @_;
    return @{$self->{'glyphs'}};
}

#########
# push either a Glyph or a GlyphSet on to our list
#
sub push {
    my $self = shift;
    my ($gx, $gx1, $gy, $gy1);
    
    foreach my $Glyph (@_) {
	#########
	# if we've got a single glyph:
	#
    	push @{$self->{'glyphs'}}, $Glyph;

    	$gx  = $Glyph->x();
    	$gx1 = $gx + $Glyph->width();
	    $gy  = $Glyph->y();
    	$gy1 = $gy + $Glyph->height();

        $self->minx($gx)  unless defined $self->minx();
        $self->maxx($gx1) unless defined $self->maxx();
        $self->miny($gy)  unless defined $self->miny();
        $self->maxy($gy1) unless defined $self->maxy();

    #########
    # track max and min dimensions
        $self->minx($gx)  if $gx  < $self->minx();
	    $self->maxx($gx1) if $gx1 > $self->maxx();
        $self->miny($gy)  if $gy  < $self->miny();
        $self->maxy($gy1) if $gy1 > $self->maxy();
    }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
    my $self = shift;

    my ($gx, $gx1, $gy, $gy1);
    
    foreach my $Glyph (reverse @_) {
	#########
	# if we've got a single glyph:
	#
    	if($Glyph->isa('Bio::EnsEMBL::Glyph')) {
            unshift @{$self->{'glyphs'}}, $Glyph;

        	$gx  = $Glyph->x();
        	$gx1 = $gx + $Glyph->width();
    	    $gy  = $Glyph->y();
        	$gy1 = $gy + $Glyph->height();
    
            $self->minx($gx)  unless defined $self->minx();
            $self->maxx($gx1) unless defined $self->maxx();
            $self->miny($gy)  unless defined $self->miny();
            $self->maxy($gy1) unless defined $self->maxy();

    #########
    # track max and min dimensions
            $self->minx($gx)  if $gx  < $self->minx();
    	    $self->maxx($gx1) if $gx1 > $self->maxx();
            $self->miny($gy)  if $gy  < $self->miny();
            $self->maxy($gy1) if $gy1 > $self->maxy();
        }
    }
}

#########
# pop a Glyph off our list
# needs to shrink glyphset dimensions if the glyph/glyphset we pop off 
#
sub pop {
    my ($self) = @_;
    return pop @{$self->{'glyphs'}};
}

#########
# shift a Glyph off our list
#
sub shift {
    my ($self) = @_;
    return shift @{$self->{'glyphs'}};
}

#########
# return the length of our list
#
sub length {
    my ($self) = @_;
    return scalar @{$self->{'glyphs'}};
}

#########
# read-only start x position (should usually be 0)
# 
sub x {
    my ($self) = @_;
    return $self->{'x'};
}

#########
# read-only start y position (should usually be 0)
#
sub y {
    my ($self) = @_;
    return $self->{'y'};
}

#########
# read-only highlights (list)
#
sub highlights {
    my ($self) = @_;
    return defined $self->{'highlights'} ? @{$self->{'highlights'}} : ();
}

sub minx {
    my ($self, $minx) = @_;
    $self->{'minx'} = $minx if(defined $minx);
    return $self->{'minx'};
}

sub miny {
    my ($self, $miny) = @_;
    $self->{'miny'} = $miny if(defined $miny);
    return $self->{'miny'};
}

sub maxx {
    my ($self, $maxx) = @_;
    $self->{'maxx'} = $maxx if(defined $maxx);
    return $self->{'maxx'};
}

sub maxy {
    my ($self, $maxy) = @_;
    $self->{'maxy'} = $maxy if(defined $maxy);
    return $self->{'maxy'};
};

sub strand {
    my ($self, $strand) = @_;
    $self->{'strand'} = $strand if(defined $strand);
    return $self->{'strand'};
}

sub height {
    my ($self) = @_;
    my $h = $self->{'maxy'} - $self->{'miny'};
    $h *=-1 if($h < 0);
    return $h;
}

sub width {
    my ($self) = @_;
    my $w = $self->{'maxx'} - $self->{'minx'};
    $w *=-1 if($w < 0);
    return $w;
}

sub label {
    my ($self, $val) = @_;
    $self->{'label'} = $val if(defined $val);
    return $self->{'label'};
}

sub bumped {
    my ($self, $val) = @_;
    $self->{'bumped'} = $val if(defined $val);
    return $self->{'bumped'};
}

sub bumpbutton {
    my ($self, $val) = @_;
    $self->{'bumpbutton'} = $val if(defined $val);
    return $self->{'bumpbutton'};
}

sub label2 {
    my ($self, $val) = @_;
    $self->{'label2'} = $val if(defined $val);
    return $self->{'label2'};
}

sub transform {
    my ($self) = @_;
    for my $glyph (@{$self->{'glyphs'}}) {
	$glyph->transform($self->{'config'}->{'transform'});
    }
}

###
### gene_specific functions 
###
sub virtualGene_details {
    my ($self, $vg, %highlights) = @_;

    my $highlight = 0;
    my $genetype  = 'unknown';
    my $label     = "NOVEL";
    if ($vg->gene->is_known) {
        $genetype = 'known';
        my @temp_geneDBlinks = $vg->gene->each_DBLink();
    # find a decent label:
        $label = $vg->id();
        $highlight = 1 if exists $highlights{$label}; # check for highlighting
        ( $label, $highlight ) = $self->_label_highlight( $label, $highlight, \%highlights, \@temp_geneDBlinks );
        
    }
    return ( $genetype, $label, $highlight, $vg->start(), $vg->end() );
}

sub _label_highlight {
    my ($self,$label,$highlight,$highlights,$dblinks) = @_;
    my $max_pref = 0;
    my %db_names = ( # preference for naming scheme!
        'FlyBase'       => 110, 'HUGO'          => 100,
        'SP'            =>  90,
        'SWISS-PROT'    =>  80, 'SPTREMBL'      =>  70,
        'SCOP'          =>  60, 'LocusLink'     =>  50,
        'RefSeq'        =>  40 
    );

    foreach ( @$dblinks ) {
        my $db = $_->database();
        # reset if precedence is higher!
        #print STDERR "_l_h:\t".ref($self)."\t$db\t$db_names{$db}\t".$_->display_id()."\t|\n";
        if( $db_names{$db} ) {
            $highlight = 1 if exists $highlights->{$_->display_id()}; # check for highlighting
            # if this is a more prefered label then we will use it!
            if( $db_names{$db}>$max_pref) {
                $label = $_->display_id();
                $max_pref = $db_names{$db};
            }
        }
    }
    return($label, $highlight);
}

sub errorTrack {
	my ($self, $message) = @_;
	my $length = $self->{'container'}->length() +1;
    my ($w,$h) = $self->{'config'}->texthelper()->real_px2bp('Tiny');
    my $red    = $self->{'config'}->colourmap()->id_by_name('red');
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
	my $bp_textwidth = $w * length($message);
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
    	'x'         => int(($length - $bp_textwidth)/2),
        'y'         => int(($h2-$h)/2),
    	'height' 	=> $h2,
        'font'      => 'Tiny',
        'colour'    => $red,
        'text'      => $message,
        'absolutey' => 1,
	});
	$self->push($tglyph);
	return;
}

sub externalGene_details {
    my ($self, $vg, $vc_id, %highlights) = @_;

    my $highlight = 0;
    my $label     = "NOVEL";
    my $start;
    my $end;
    
    my $genetype   = ($vg->type() =~ /pseudo/) ? 'pseudo' : 'ext';

    foreach my $trans ($vg->each_Transcript){
        foreach my $exon ( $trans->get_all_Exons ) {
            if($exon->seqname eq $vc_id) {
                $start = $exon->start if ( $exon->start < $start || !defined $start );
                $end   = $exon->end   if ( $exon->end   > $end   || !defined $end );
	    }
    	}
    }
    $label  = $vg->stable_id;
    $highlight = 1 if exists $highlights{$label};
    $label  =~ s/gene\.//;
    $highlight = 1 if exists $highlights{$label};
    my @temp_geneDBlinks = $vg->each_DBLink();
    ( $label, $highlight ) = $self->_label_highlight( $label, $highlight, \%highlights, \@temp_geneDBlinks );
    return ( $genetype, $label, $highlight, $start, $end );
}

## Stuff copied out of scalebar.pm so that contig.pm can use it!
##

sub zoom_URL {
    my( $self, $PART, $interval_middle, $width, $factor, $highlights ) = @_;
    my $start = int( $interval_middle - $width / 2 / $factor);
    my $end   = int( $interval_middle + $width / 2 / $factor);        
    return qq(/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?$PART&vc_start=$start&vc_end=$end&$highlights);
}

sub zoom_zmenu {
    my ($self, $chr, $interval_middle, $width, $highlights) = @_;
    return { 
            'caption'                          => "Navigation",
            '01:Zoom in (x10)'                 => $self->zoom_URL($chr, $interval_middle, $width, 10  , $highlights),
            '02:Zoom in (x5)'                  => $self->zoom_URL($chr, $interval_middle, $width,  5  , $highlights),
            '03:Zoom in (x2)'                  => $self->zoom_URL($chr, $interval_middle, $width,  2  , $highlights),
            '04:Centre on this scale interval' => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights), 
            '05:Zoom out (x0.5)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.5, $highlights), 
            '06:Zoom out (x0.2)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.2, $highlights), 
            '07:Zoom out (x0.1)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.1, $highlights)                 
    };
}


1;
