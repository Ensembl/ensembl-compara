package Bio::EnsEMBL::GlyphSet;
use strict;
use lib "../../../../bioperl-live";
use Bio::Root::RootI;
use Exporter;
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Exporter Bio::Root::RootI);

#########
# constructor
#
sub new {
    my ($class, $VirtualContig, $Config, $highlights, $strand) = @_;
    my $self = {
	'glyphs'     => [],
	'x'          => 0,
	'y'          => 0,
	'width'      => 0,
	'height'     => 0,
	'highlights' => $highlights,
	'strand'     => $strand,
	'minx'       => undef,
	'miny'       => undef,
	'maxx'       => undef,
	'maxy'       => undef,
    };

    bless($self, $class);
    $self->_init($VirtualContig, $Config);

    return $self;
}

#########
# _init creates masses of Glyphs from a data source.
# It should executes bumping and globbing on the fly and also
# keep track of x,y,width,height as it goes.
#
sub _init {
    my ($this, $VirtualContig, $Config) = @_;
    print STDERR qq(Bio::EnsEMBL::GlyphSetI::_init unimplemented\n);
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

    if($Glyph->isa('Bio::EnsEMBL::Glyph')) {
	#########
	# if we've got a single glyph:
	#
	push @{$this->{'glyphs'}}, $Glyph;

    } elsif($Glyph->isa('Bio::EnsEMBL::GlyphSet')) {
	#########
	# if we've got a glyphs 
	#
	push @{$this->{'glyphs'}}, @{$Glyph->glyphs()};
    }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
    my ($this, $Glyph) = @_;
    
    if($Glyph->isa('Bio::EnsEMBL::Glyph')) {
	#########
	# if we've got a single glyph:
	#
	unshift @{$this->{'glyphs'}}, $Glyph;
	
    } elsif($Glyph->isa('Bio::EnsEMBL::GlyphSet')) {
	#########
	# if we've got a glyphs 
	#
	unshift @{$this->{'glyphs'}}, @{$Glyph->glyphs()};
    }
}

#########
# pop a Glyph off our list
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
# read-only width
#
sub width {
    my ($this) = @_;
    return $this->{'width'};
}

#########
# read-only height
#
sub height {
    my ($this) = @_;
    return $this->{'height'};
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
    return $this->{'minx'}
}

sub miny {
    my ($this, $miny) = @_;
    $this->{'miny'} = $miny if(defined $miny);
    return $this->{'miny'}
}

sub maxx {
    my ($this, $maxx) = @_;
    $this->{'maxx'} = $maxx if(defined $maxx);
    return $this->{'maxx'}
}

sub maxy {
    my ($this, $maxy) = @_;
    $this->{'maxy'} = $maxy if(defined $maxy);
    return $this->{'maxy'}
}

sub strand {
    my ($this, $strand) = @_;
    $this->{'strand'} = $strand if(defined $strand);
    return $this->{'strand'}
}

1;
