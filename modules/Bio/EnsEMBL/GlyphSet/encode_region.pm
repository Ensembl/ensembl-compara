package Bio::EnsEMBL::GlyphSet::encode_region;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "ENCODE"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MiscFeatures('encode_regions');
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
    my ($self, $f ) = @_;
    return ("@{[$f->get_scalar_attribute('name')]}",'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $region, $start, $end ) = @_;
    my $spp=$self->{container}{_config_file_name_};
    return "/$spp/$ENV{'ENSEMBL_SCRIPT'}?l=$region:$start-$end";
}

## Create the zmenu...

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $start = $f->seq_region_start;
    my $end = $f->seq_region_end;
    my $region =  $f->seq_region_name;
    my $type = $f->get_scalar_attribute('type');
    my $name = $f->get_scalar_attribute('name');
    my $zmenu = { 
        'caption' => "BAC: $name",
        "01:bp: $start - $end" => '',
        "02:Type $type" => '',
        '03:Centre on region' => $self->href($region, $start, $end),
    };
    return $zmenu;
}

1;
