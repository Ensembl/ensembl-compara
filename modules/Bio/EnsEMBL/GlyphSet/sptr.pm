package Bio::EnsEMBL::GlyphSet::sptr;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
use ExtURL;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "SpTrEMBL"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("sptr",80,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    my $ext_url = ExtURL->new;
    return {
        'caption' => "$id",
        "Protein homology" =>
            $ext_url->get_url( $id=~/^NP/ ? 'REFSEQPROTEIN' : 'SWISSFETCH', $id )
    };
}
1;
