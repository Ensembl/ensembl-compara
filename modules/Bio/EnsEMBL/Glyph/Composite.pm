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

    #########
    # make the glyph coords relative to the composite container
    #
    $glyph->x($gx - $this->x());
    $glyph->y($gy - $this->y());
}

sub first {
    my ($this) = @_;
    return if(!defined $this->{'composite'});
    return @{$this->{'composite'}}[0];
}

sub last {
    my ($this) = @_;
    return if(!defined $this->{'composite'});
    my $len = scalar @{$this->{'composite'}};
    return undef if($len == 0);
    return @{$this->{'composite'}}[$len - 1];
}

1;
