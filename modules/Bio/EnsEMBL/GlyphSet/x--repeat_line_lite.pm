package Bio::EnsEMBL::GlyphSet::repeat_line_lite;
use strict;
use vars qw(@ISA);
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );
sub my_label { return "Repeats (LINE)"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures_lite( 'line', $self->glob_bp() );
}
