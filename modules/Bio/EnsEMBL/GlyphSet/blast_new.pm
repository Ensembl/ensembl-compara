package Bio::EnsEMBL::GlyphSet::blast_new;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Blast hits"; }

sub features {
    my ($self) = @_;
    return map {
       /BLAST_NEW:(.*)/? $self->{'container'}->get_all_SearchFeatures($1):()
    } $self->highlights;
}

sub href {
    my ( $self, $id ) = @_;
    return undef;
 #   return $self->ID_URL( 'SRS_PROTEIN', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    # $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id" }; #, "Protein homology" => $self->href( $id ) };
}
1;
