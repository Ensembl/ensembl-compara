package Glyph::Circle;
use strict;
use vars qw(@ISA);
use lib "..";
use GlyphI;
@ISA = qw(GlyphI);

sub diameter {
    my ($self, $val) = @_;
    $self->width($val) if(defined $val);
    $self->height($self->width());
    return $self->width();
}

sub radius {
    my ($self, $val) = @_;
    $self->width($val * 2) if(defined $val);
    $self->height($self->width());

    return ($self->width() / 2);
}

1;
