package Bio::EnsEMBL::GlyphSet::Vannot_ig_and_ig_pseudo;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_vhistogram;
@ISA = qw(Bio::EnsEMBL::GlyphSet_vhistogram);

sub my_label {
    my $self = shift;
    my @label;
    # text: label
    # colour: name of colour in colourmap
    # type: type in lite.map_density.type
    push @label, {
        'text' => 'Ig Segment',
        'colour' => 'Ig_Segment',
        'type' => 'Ig_Segment',
    };
    push @label, {
        'text' => 'Ig Pseudo Seg.',
        'colour' => 'Ig_Pseudogene_Segment',
        'type' => 'ig_pseudogene',
    };
    return @label;
}

sub logic_name {
    my $self = shift;
    return $self->my_label();
}

1;

