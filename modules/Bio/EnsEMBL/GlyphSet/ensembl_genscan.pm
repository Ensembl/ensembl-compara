package Bio::EnsEMBL::GlyphSet::ensembl_genscan;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Ensembl Genscan"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("ensembl_genscan",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    #$id =~ s/(.*)\.\d+/$1/o; #jerm - removed this string substitution (why was it there in the first place?)

    #marie - uses local bioperl db to serve up protein homology
    my $biodb = 'ensembl_genscan'; #specify db name here - corresponds to bioperl_db, biodatabases table
    return {
        'caption' => "$id",
            "Protein homology" => "/perl/bioperldbview?id=$id&biodb=$biodb&format=fasta",

    };
}
;
