package Bio::EnsEMBL::GlyphSet::est2genome_all;

use strict;
use warnings;
no warnings 'uninitialized';

use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::est2genome;
@ISA = qw(Bio::EnsEMBL::GlyphSet::est2genome);

sub my_label { return "ESTs"; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_DnaAlignFeatures("est2genome_human", 80),
           $self->{'container'}->get_all_DnaAlignFeatures("est2genome_mouse", 80),
           $self->{'container'}->get_all_DnaAlignFeatures("est2genome_other", 80);
}

1;

