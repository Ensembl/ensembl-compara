package Bio::EnsEMBL::GlyphSet::est2genome;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "ESTs"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_DnaAlignFeatures( "est2genome", 80);
}

sub href {
    my ( $self, $id ) = @_;
    return $self->{'config'}->{'exturl'}->get_url( 'EMBL', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    (my $stripped_id = $id) =~ s/(^[^\.]+)\..*/$1/;
    my $zmenu = { 'caption' => "EST $stripped_id", "$stripped_id" => $self->href( $stripped_id ) };

    my $extra_URL  = "/@{[$self->{container}{_config_file_name_}]}/featureview?type=DnaAlignFeature&id=$id";
    #$extra_URL .= "&db=".$self->my_config('DATABASE') if $self->my_config('DATABASE');
    $zmenu->{ 'View all hits' } = $extra_URL;
    return $zmenu;
}

1;

