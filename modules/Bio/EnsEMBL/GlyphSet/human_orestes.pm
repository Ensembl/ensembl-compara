package Bio::EnsEMBL::GlyphSet::human_orestes;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Human ORESTES"; }

sub features {

    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("HUMAN_ORESTES",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology
    my $biodb = 'HUMAN_ORESTES';#specify db name here - corresponds to bioperl_db, biodatabases table
    return {
        'caption' => "$id",
         "$id"     => "/perl/bioperldbview?id=$id&biodb=$biodb&format=GenBank"};

}
;
