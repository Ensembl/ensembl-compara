package Bio::EnsEMBL::GlyphSet::repeat_mlt_lite;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );
sub my_label { return "Repeats (MLT)"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( 'mir', $self->glob_bp() );
}
