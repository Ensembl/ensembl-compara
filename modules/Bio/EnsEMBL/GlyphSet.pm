package Bio::EnsEMBL::GlyphSet;
use strict;
use lib "../../../../bioperl-live";
use Bio::Root::RootI;
use Exporter;
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Exporter Bio::Root::RootI);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

#########
# constructor
#
sub new {
    my ($class, $VirtualContig, $Config, $highlights, $strand) = @_;
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
	'container'  => $VirtualContig,
	'config'     => $Config,
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
    my ($this) = @_;
    print STDERR qq($this unimplemented\n);
}

#########
# return our list of glyphs
#
sub glyphs {
    my ($this) = @_;
    return @{$this->{'glyphs'}};
}

#########
# push either a Glyph or a GlyphSet on to our list
#
sub push {
    my ($this, $Glyph) = @_;

    my ($gx, $gw, $gy, $gh);

	#########
	# if we've got a single glyph:
	#
	push @{$this->{'glyphs'}}, $Glyph;

	$gx = $Glyph->x();
	$gw = $Glyph->width();
	$gy = $Glyph->y();
	$gh = $Glyph->height();

    $this->minx($gx) if(!defined $this->minx());
    $this->maxx($gx) if(!defined $this->maxx());
    $this->miny($gy) if(!defined $this->miny());
    $this->maxy($gy) if(!defined $this->maxy());

    #########
    # track max and min dimensions
    #
    # x
    #
    if($gx < $this->minx()) {
	$this->minx($gx);
    } elsif(($gx + $gw) > $this->maxx()) {
	$this->maxx($gx + $gw);
    }

    # y
    # 
    if($gy < $this->miny()) {
	$this->miny($gy);
    } elsif(($gy + $gh) > $this->maxy()) {
	$this->maxy($gy + $gh);
    }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
    my ($this, $Glyph) = @_;

    my ($gx, $gw, $gy, $gh);

    if($Glyph->isa('Bio::EnsEMBL::Glyph')) {
	#########
	# if we've got a single glyph:
	#
	unshift @{$this->{'glyphs'}}, $Glyph;

	$gx = $Glyph->x();
	$gw = $Glyph->width();
	$gy = $Glyph->y();
	$gh = $Glyph->height();

    }

    $this->minx($gx) if(!defined $this->minx());
    $this->maxx($gx) if(!defined $this->maxx());
    $this->miny($gy) if(!defined $this->miny());
    $this->maxy($gy) if(!defined $this->maxy());

    #########
    # track max and min dimensions
    #
    # x
    #
    if($gx < $this->minx()) {
	$this->minx($gx);
    } elsif(($gx + $gw) > $this->maxx()) {
	$this->maxx($gx + $gw);
    }

    # y
    # 

    if($gy < $this->miny()) {
	$this->miny($gx);
    } elsif(($gy + $gh) > $this->maxy()) {
	$this->maxy($gy + $gh);
    }
}

#########
# pop a Glyph off our list
# needs to shrink glyphset dimensions if the glyph/glyphset we pop off 
#
sub pop {
    my ($this) = @_;
    return pop @{$this->{'glyphs'}};
}

#########
# shift a Glyph off our list
#
sub shift {
    my ($this) = @_;
    return shift @{$this->{'glyphs'}};
}

#########
# return the length of our list
#
sub length {
    my ($this) = @_;
    return scalar @{$this->{'glyphs'}};
}

#########
# read-only start x position (should usually be 0)
# 
sub x {
    my ($this) = @_;
    return $this->{'x'};
}

#########
# read-only start y position (should usually be 0)
#
sub y {
    my ($this) = @_;
    return $this->{'y'};
}

#########
# read-only highlights ('|'-separated ids to colour)
#
sub highlights {
    my ($this) = @_;
    return $this->{'highlights'};
}

sub minx {
    my ($this, $minx) = @_;
    $this->{'minx'} = $minx if(defined $minx);
    return $this->{'minx'};
}

sub miny {
    my ($this, $miny) = @_;
    $this->{'miny'} = $miny if(defined $miny);
    return $this->{'miny'};
}

sub maxx {
    my ($this, $maxx) = @_;
    $this->{'maxx'} = $maxx if(defined $maxx);
    return $this->{'maxx'};
}

sub maxy {
    my ($this, $maxy) = @_;
    $this->{'maxy'} = $maxy if(defined $maxy);
    return $this->{'maxy'};
};

sub strand {
    my ($this, $strand) = @_;
    $this->{'strand'} = $strand if(defined $strand);
    return $this->{'strand'};
}

sub height {
    my ($this) = @_;
    my $h = $this->{'maxy'} - $this->{'miny'};
    $h *=-1 if($h < 0);
    return $h;
}

sub width {
    my ($this) = @_;
    my $w = $this->{'maxx'} - $this->{'minx'};
    $w *=-1 if($w < 0);
    return $w;
}

sub label {
    my ($this, $val) = @_;
    $this->{'label'} = $val if(defined $val);
    return $this->{'label'};
}

1;
