package Bio::EnsEMBL::GlyphSet::non_hum;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "SpTrOthers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("non_hum",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology
    my $biodb = 'non_hum'; #specify db name here - corresponds to bioperl_db, biodatabases table
    return {
        'caption' => "$id",
            "Protein homology" => "/perl/bioperldbview?id=$id&biodb=$biodb&format=swiss",

    };
}
;
