package Bio::EnsEMBL::GlyphSet::pdb;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'pdb',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $protein    = $self->{'container'};
    my $Config     = $self->{'config'};
    my $y          = 0;
    my $h          = 4;
    my $highlights = $self->highlights();
    my $length     = $protein->length();
    my $xp         = 0;
    my $wp         = $length;

    my $colour = $Config->get('pdb', 'col');

    my $rect = new Bio::EnsEMBL::Glyph::Rect({
        'x'        => $xp,
        'y'        => $y,
        'width'    => $wp,
        'height'   => $h,
        'id'       => $protein->id(),
        'colour'   => $colour,
        'zmenu' => {
            'caption' => $protein->id(),
        },
    });
    
    $self->push($rect);
}
1;




















