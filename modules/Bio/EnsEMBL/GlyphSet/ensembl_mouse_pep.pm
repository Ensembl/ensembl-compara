package Bio::EnsEMBL::GlyphSet::ensembl_mouse_pep;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Ens. Mouse pep."; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("ensembl_mouse_pep",1,$self->glob_bp,$self->strand());
}

sub href {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return $self->{'config'}->{'ext_url'}->get_url( 'ENS_MOUSEPEP', $id );
}
sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology
    return {
        'caption' => "$id",
            "Protein homology" =>  $self->href($id)

    };
}
1;
