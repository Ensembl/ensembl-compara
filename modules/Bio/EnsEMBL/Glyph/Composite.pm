package Bio::EnsEMBL::Glyph::Composite;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::Glyph::Rect;
@ISA = qw(Bio::EnsEMBL::Glyph::Rect);

sub push {
    my ($this, $glyph) = @_;

    return if (!defined $glyph);

    push @{$this->{'composite'}}, $glyph;

    my $gx = $glyph->x();
    my $gw = $glyph->width();
    my $gy = $glyph->y();
    my $gh = $glyph->height();

    #########
    # track max and min dimensions
    #
    # x
    #
    $this->x($gx) if(!defined($this->x()));
    $this->y($gy) if(!defined($this->y()));
    $this->width($gw) if(!defined($this->width()));
    $this->height($gh) if(!defined($this->height()));

    if($gx < $this->x()) {
	$this->x($gx);
	$this->width($this->x() - $gx + $this->width());
    } elsif(($gx + $gw) > ($this->x() + $this->width())) {
	# x unchanged
	$this->width(($gx + $gw) - $this->x());
    }
    # y
    #
    if($gy < $this->y()) {
	$this->y($gy);
	$this->height($this->y() - $gy + $this->height());
    } elsif(($gy + $gh) > ($this->y() + $this->height())) {
	# y unchanged
	$this->height(($gy + $gh) - $this->y());
    }
}

1;
