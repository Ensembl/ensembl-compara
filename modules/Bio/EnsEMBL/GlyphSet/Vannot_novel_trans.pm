package Bio::EnsEMBL::GlyphSet::Vannot_novel_trans;
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
        'text' => 'Novel',
        'colour' => 'Novel_Transcript',
        'type' => 'novel_trans',
    };
    push @label, {
        'text' => 'trans.',
        'colour' => 'Novel_Transcript',
        'type' => 'novel_trans',
    };
    return @label;
}

sub logic_name {
    my $self = shift;
    my @logic_name;
    # key descriptions see above
    push @logic_name, {
        'text' => 'Novel',
        'colour' => 'Novel_Transcript',
        'type' => 'novel_trans',
    };
    return @logic_name;
}

1;
