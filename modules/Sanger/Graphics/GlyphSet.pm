package Sanger::Graphics::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Space;

#########
# constructor
#
sub new {
    my ($class, $Container, $Config, $highlights, $strand, $extra_config) = @_;
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
	'container'  => $Container,
	'config'     => $Config,
	'extras'     => $extra_config,
    };

    bless($self, $class);
    $self->init_label() if($self->can('init_label'));
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
    my $pixels = $self->{'config'}->get( '_settings' ,'width' );
    return (defined $pixels && $pixels) ? $self->{'container'}->length() / $pixels : undef; 
}    

sub glob_bp {
    my ($self) = @_;
    return int( $self->basepairs_per_pixel()*2 );
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
    	CORE::push @{$self->{'glyphs'}}, $Glyph;

    	$gx  =       $Glyph->x();
    	$gx1 = $gx + $Glyph->width();
	$gy  =       $Glyph->y();
    	$gy1 = $gy + $Glyph->height();

    ######### track max and min dimensions
        $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
        $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
        $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
        $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
    }
}

#########
# unshift a Glyph or GlyphSet onto our list
#
sub unshift {
    my $self = shift;

    my ($gx, $gx1, $gy, $gy1);
    
    foreach my $Glyph (reverse @_) {
        CORE::unshift @{$self->{'glyphs'}}, $Glyph;

      	$gx  =       $Glyph->x();
       	$gx1 = $gx + $Glyph->width();
        $gy  =       $Glyph->y();
       	$gy1 = $gy + $Glyph->height();
    
        $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
        $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
        $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
        $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
    }
}

########## pop/shift a Glyph off our list
# needs to shrink glyphset dimensions if the glyph/glyphset we pop off 

sub pop {
    my ($self) = @_;
    return CORE::pop @{$self->{'glyphs'}};
}

sub shift {
    my ($self) = @_;
    return CORE::shift @{$self->{'glyphs'}};
}

########## read-only getters
sub x {
    my ($self) = @_;
    return $self->{'x'};
}

sub y {
    my ($self) = @_;
    return $self->{'y'};
}

sub highlights {
    my ($self) = @_;
    return defined $self->{'highlights'} ? @{$self->{'highlights'}} : ();
}

########## read-write get/setters...

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

##
## additional derived functions
##

sub height {
    my ($self) = @_;
    return abs($self->{'maxy'}-$self->{'miny'});
}

sub width {
    my ($self) = @_;
    return abs($self->{'maxx'}-$self->{'minx'});
}

sub length {
    my ($self) = @_;
    return scalar @{$self->{'glyphs'}};
}

sub transform {
    my ($self) = @_;
    my $T = $self->{'config'}->{'transform'};
    foreach( @{$self->{'glyphs'}} ) {
	$_->transform($T);
    }
}

sub errorTrack {
    my ($self, $message) = @_;
    my $length   = $self->{'container'}->length() +1;
    my ($w,$h)   = $self->{'config'}->texthelper()->real_px2bp('Tiny');
    my $red      = $self->{'config'}->colourmap()->id_by_name('red');
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
    	'x'         => int( ($length - $w * length($message))/2 ),
        'y'         => int( ($h2-$h)/2 ),
    	'height'    => $h2,
        'font'      => 'Tiny',
        'colour'    => $red,
        'text'      => $message,
        'absolutey' => 1,
    }) );
    
    return;
}

1;
