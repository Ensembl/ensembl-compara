package Bio::EnsEMBL::GlyphSet::Vannot_pseudo_and_poly;
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
        'text' => 'Pseudo',
        'colour' => 'Pseudogene',
        'type' => 'pseudo',
    };
    push @label, {
        'text' => 'Polymorph.',
        'colour' => 'Polymorphic',
        'type' => 'polymorphic',
    };
    return @label;
}

sub logic_name {
    my $self = shift;
    return $self->my_label();
}

1;

