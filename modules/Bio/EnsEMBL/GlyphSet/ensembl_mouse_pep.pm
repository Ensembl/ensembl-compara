package Bio::EnsEMBL::GlyphSet::ensembl_mouse_pep;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Ens. Mouse pep."; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_ProteinAlignFeatures("BLASTX_ENS_MUS",1,);
}

sub href {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return $self->ID_URL( 'ENS_MM_PEP', $id );
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
