package Bio::EnsEMBL::GlyphSet::nod_bacs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Nod BACs"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MiscFeatures('nod_bacs');
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
    my ($self, $f ) = @_;
    return ("@{[$f->get_attribute('name')]}",'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_attribute('name')]}";
}

## Create the zmenu...
## Include each accession id separately

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption' => "Clone: @{[$f->get_attribute('name')]}",
        "01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}" => '',
        '02:length: @{[$f->length]} bps' => '',
        '03:Centre on clone:' => $self->href($f),
    };
    return $zmenu;
}

1;
