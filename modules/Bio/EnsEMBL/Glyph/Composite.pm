package Bio::EnsEMBL::Glyph::Composite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::Glyph::Rect;
@ISA = qw(Bio::EnsEMBL::Glyph::Rect);

sub push {
    my ($self, $glyph) = @_;

    return if (!defined $glyph);

    my $gx = $glyph->x();
    my $gw = $glyph->width();
    my $gy = $glyph->y();
    my $gh = $glyph->height();

    #########
    # track max and min dimensions
    #
    # x
    #
    $self->x($gx) if(!defined($self->x()));
    $self->y($gy) if(!defined($self->y()));
    $self->width($gw) if(!defined($self->width()));
    $self->height($gh) if(!defined($self->height()));

    if($gx < $self->x()) {
	my $offset = $self->x() - $gx;
	$self->x($gx);
	$self->width($self->x() - $gx + $self->width());

	#########
	# if the new glyph is set outside LHS boundary, then the composite stretches
	# and all glyphs already inside need to be offset by the difference
	#
	for my $offset_glyph (@{$self->{'composite'}}) {
	    $offset_glyph->x($offset_glyph->x() + $offset);
	}

    } elsif(($gx + $gw) > ($self->x() + $self->width())) {
	# x unchanged
	$self->width(($gx + $gw) - $self->x());
    }
    # y
    #
    if($gy < $self->y()) {
	my $offset = $self->y() - $gy;
	$self->y($gy);
	$self->height($self->y() - $gy + $self->height());

	#########
	# if the new glyph is set outside TOP boundary, then the composite stretches
	# and all glyphs already inside need to be offset by the difference
	#
	for my $offset_glyph (@{$self->{'composite'}}) {
	    $offset_glyph->y($offset_glyph->y() + $offset);
	}

    } elsif(($gy + $gh) > ($self->y() + $self->height())) {
	# y unchanged
	$self->height(($gy + $gh) - $self->y());
    }

    #########
    # make the glyph coords relative to the composite container
    # NOTE: watch out for this if you're creating glyphsets! - don't do this twice
    #
    $glyph->x($gx - $self->x()) unless(defined $glyph->absolutex());
    $glyph->y($gy - $self->y()) unless(defined $glyph->absolutey());

    push @{$self->{'composite'}}, $glyph;
}

sub first {
    my ($self) = @_;
    return if(!defined $self->{'composite'});
    return @{$self->{'composite'}}[0];
}

sub last {
    my ($self) = @_;
    return if(!defined $self->{'composite'});
    my $len = scalar @{$self->{'composite'}};
    return undef if($len == 0);
    return @{$self->{'composite'}}[$len - 1];
}

sub glyphs {
    my ($self) = @_;
    return @{$self->{'composite'}};
}

sub transform {
    my ($self, $transform_ref) = @_;

    $self->SUPER::transform($transform_ref);

    for my $sg (@{$self->{'composite'}}) {
		my %tmp_transform = %{$transform_ref};
		$tmp_transform{'translatex'} = $self->pixelx()+1;
		$tmp_transform{'translatey'} = $self->pixely();
		$sg->transform(\%tmp_transform);
    }
}

1;
