package Sanger::Graphics::Glyph::Circle;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::Glyph;
@ISA = qw(Bio::EnsEMBL::Glyph);

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
