package Bio::EnsEMBL::GlyphSet::misc_bacends;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "BACends"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MiscFeatures('bacends');
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
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_scalar_attribute('name')]}";
}

## Create the zmenu...

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $bacends = join(",", @{$f->get_all_attribute_values('bacend')});
    my $zmenu = { 
        'caption' => "BAC: @{[$f->get_scalar_attribute('name')]}",
        "01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}" => '',
        "02:Ends: $bacends" => '',
        '03:Centre on clone:' => $self->href($f),
    };
    return $zmenu;
}

1;
