package Bio::EnsEMBL::GlyphSet::riken;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "RIKEN"; }

sub features {
    my ($self) = @_;
    print STDERR "RIKEN PROT CALLED\n\n";
    my @res = $self->{'container'}->get_all_ExternalFeatures($self->glob_bp);
    print STDERR "RES: ",scalar(@res),"\n";
    my @res = grep { $_->source_tag() eq 'riken' }
        $self->{'container'}->get_all_ExternalFeatures($self->glob_bp);
    print STDERR "RES: ",scalar(@res),"\n";
    return @res;
}

sub href {
    my ($self, $id ) = @_;
    return $self->ID_URL( 'RIKEN', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "RIKEN $id", "$id" => $self->href( $id ) };
}
1;
