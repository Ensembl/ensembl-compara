package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_landmark_MarkerFeatures();
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 
        'caption' => $id,
	    'Marker info' => "/$ENV{'ENSEMBL_SPECIES'}/markerview?marker=$id",
    };
}
1;
