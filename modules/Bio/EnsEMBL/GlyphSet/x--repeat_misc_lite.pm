package Bio::EnsEMBL::GlyphSet::repeat_misc_lite;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );
sub my_label { return "Repeats (Misc.)"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( 'misc', $self->glob_bp() );
}
