package Bio::EnsEMBL::GlyphSet::generic_vega_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub logic_name {
    my $self = shift;
    return $self->my_config('logic_name');
}

sub zmenu_caption {
    my $self = shift;
    return $self->my_config('zmenu_caption');
}





1;
