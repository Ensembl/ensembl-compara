package Bio::EnsEMBL::GlyphSet::sptr;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "SpTrEMBL"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures_by_strand("sptr",80,$self->glob_bp,$self->strand());
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return {
        'caption' => "$id",
	    "Protein homology" =>
            (
                $id=~/^NP/ ?
                    "http://www.sanger.ac.uk/srs6bin/cgi-bin/wgetz?-e+[REFSEQPROTEIN-ID:$id]" :
                    "http://www.ebi.ac.uk/cgi-bin/swissfetch?$id"
            )
    };
}
1;
