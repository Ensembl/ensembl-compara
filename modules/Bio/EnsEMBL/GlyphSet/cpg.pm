package Bio::EnsEMBL::GlyphSet::cpg;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "CpG island"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_above_score(
        "cpg",25,$self->glob_bp()
    );
}

sub zmenu {
    my ($self, $id ) = @_;
    return undef;
}
1;
