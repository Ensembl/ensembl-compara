package Bio::EnsEMBL::GlyphSet::repeat_mir_lite;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );
sub my_label { return "Repeats (MIR)"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( 'mir', $self->glob_bp() );
}
