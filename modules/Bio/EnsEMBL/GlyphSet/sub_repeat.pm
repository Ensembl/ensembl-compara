package Bio::EnsEMBL::GlyphSet::sub_repeat;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );

sub my_label { return $self->{'extra'}->{'label'}; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( $self->{'extra'}->{'name'}, $self->glob_bp() );
}
