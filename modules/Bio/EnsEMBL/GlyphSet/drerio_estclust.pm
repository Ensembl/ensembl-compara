package Bio::EnsEMBL::GlyphSet::drerio_estclust;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "EST cluster"; }

sub features {
    my ($self) = @_;
    return (
      $self->{'container'}->get_all_SimilarityFeatures( "EST_cluster_WashU", 80, $self->glob_bp),
      $self->{'container'}->get_all_SimilarityFeatures( "EST_cluster_IMCB", 80, $self->glob_bp)
    );
}

sub href {
    my ( $self, $id ) = @_;
    if($id =~ /^WZ/) {
	$id =~ s/^WZ//i;
        return $self->ID_URL('WZ',$id);
    } else {
        return $self->ID_URL('IMCB_HOME',$id);
    }
}

sub zmenu {
    my ($self, $id ) = @_;
    if($id =~ /^WZ/) {
        return { 'caption' => "WZ cluster: $id", "$id details" => $self->href( $id ) };
    } else {
        return { 'caption' => "IMCB cluster: $id", "IMCB Home" => $self->href( $id ) };
    }
}
1;
