package Bio::EnsEMBL::GlyphSet::ensembl_mouse_pep;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Ensembl Mouse"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("ensembl_mouse_pep",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology
    my $biodb = 'ensembl_mouse_pep'; #specify db name here - corresponds to bioperl_db, biodatabases table
    return {
        'caption' => "$id",
            "Protein homology" => "/perl/bioperldbview?id=$id&biodb=$biodb&format=fasta",

    };
}
;
