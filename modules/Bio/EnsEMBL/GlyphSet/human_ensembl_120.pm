package Bio::EnsEMBL::GlyphSet::human_ensembl_120;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "TBlastx Human"; }

sub features {
    my ($self) = @_;
    return
$self->{'container'}->get_all_SimilarityFeatures_by_strand("human_ensembl_120",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    #$id =~ s/(.*)\.\d+/$1/o;
    #marie - uses local bioperl db to serve up protein homology
    my $biodb = 'ensembl_nov_pep'; #specify db name here - corresponds to bioperl_db, biodatabases table
    
    my $contig_id = $id;
    $id =~ s/(\w+)\.\S+/$1/g;
    
    return {
        'caption' => "$contig_id",
            "Human homologous sequence" =>"http://www.ensembl.org/Homo_sapiens/seqentryview?seqentry=$id&contigid=$contig_id",

    };
}
;
