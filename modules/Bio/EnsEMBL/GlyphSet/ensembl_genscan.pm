package Bio::EnsEMBL::GlyphSet::ensembl_genscan;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Ens. Genscan pep."; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_ProteinAlignFeatures("BLASTX_HUM_GENSCAN",1);
}

sub href {
    my ($self, $id ) = @_;
    if($id =~ /(.*)+\.\d+\.(\d+)\.(\d+)$/) {   
       return $self->{'config'}->{'ext_url'}->get_url( 'ENS_GENSCAN', { 'CONTIG' => $1 , 'START' => $2, 'END' => $3 } );
    } else {
       return undef;
    } 
}
sub zmenu {
    my ($self, $id ) = @_;
    #marie - uses local bioperl db to serve up protein homology
    my $URL = $self->href($id);
    return $URL ? {
        'caption' => "$id",
            "Jump to location in Homo sapiens" =>  $URL

    } : {
        'caption' => "$id"
    };
}
1;

