package Bio::EnsEMBL::GlyphSet::epd;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EPD"; }

sub features {

    my ($self) = @_;
    return
$self->{'container'}->get_all_SimilarityFeatures_by_strand("epd",1,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    #$id =~ s/(.*)\.\d+/$1/o;
    my $biodb = 'epd'; #specify db name here - corresponds to bioperl_db, biodatabases table

    my $contig_id = $id;
    $id =~ s/(\w+)\.\S+/$1/g;

    return {
        'caption' => "$contig_id",
            "Promoter Sequence" =>"/perl/bioperldbview?id=$id&biodb=$biodb&format=fasta",

    };
}
;

