package Bio::EnsEMBL::GlyphSet::hum;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "SpTrHuman"; }

sub features {
    my ($self) = @_;

    
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("hum",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology    
    my $biodb = 'hum'; #specify db name here - corresponds to bioperl_db, biodatabases table 
    return {
        'caption' => "$id",
            "Protein homology" => "/$ENV{ENSEMBL_SPECIES}/bioperldbview?id=$id&biodb=$biodb&format=swiss",
    };
}
;
