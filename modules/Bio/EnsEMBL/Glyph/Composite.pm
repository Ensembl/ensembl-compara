package Glyph::Composite;
use strict;
use vars qw(@ISA);
use lib "..";
use Glyph::Rect;
@ISA = qw(Glyph::Rect);

sub push {
    my ($this, $glyph) = @_;

    return if (!defined $glyph);

    push @{$this->{'composite'}}, $glyph;

    $this->x($glyph->x()) if(!defined $this->x() || $glyph->x() < $this->x());
    $this->y($glyph->y()) if(!defined $this->y() || $glyph->y() < $this->y());

    $this->width($this->width()   + $glyph->width());
    $this->height($glyph->height()) if(!defined $this->height() || $glyph->height() > $this->height());
}

1;
