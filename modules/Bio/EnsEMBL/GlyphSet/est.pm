package Bio::EnsEMBL::GlyphSet::est;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "ESTs"; }

sub features {
    my ($self) = @_;
    return grep { $_->source_tag() eq 'est' }
        $self->{'container'}->get_all_ExternalFeatures($self->glob_bp);
}

sub href {
    my ($self, $id ) = @_;
    my $estid = $id;
    $estid =~s/(.*?)\.\d+/$1/;
    return $self->{'config'}->{'ext_url'}->get_url( 'EST', $estid );
}

sub zmenu {
    my ($self, $id ) = @_;
    return { 'caption' => "EST $id", "$id" => $self->href( $id ) };
}
1;
