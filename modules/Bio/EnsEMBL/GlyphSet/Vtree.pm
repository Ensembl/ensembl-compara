package Bio::EnsEMBL::GlyphSet::Vtree;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;

use SiteDefs;

sub init_label {
    my ($self) = @_;
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => "Tree diagram",
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $Config = $self->{'config'};
    
    return unless ($self->strand() == 1);
## FIRSTLY LETS SORT OUT THE COLOURS!!
    my $cmap   = $Config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');

## LETS GRAB THE DATA FROM THE CONTAINER
    my @nodes       = $self->{'container'}->nodes;
    print STDERR "HERE -- ",$self->{'container'},"\n";

    my $x_max = 0;
    foreach my $node (@nodes) {
        $x_max = $node->{'x'} if $node->{'x'}>$x_max;
    }
    my $horizontal_scale = $Config->get('_settings','width')/1.5/$x_max;
    foreach my $node (@nodes) {
        if($node->{'id'} eq '*') { # branch...
            $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'          => $node->{'x'} * $horizontal_scale - 1,
                'y'          => $node->{'y'} * 10 - 1, 
                'width'      => 2,
                'height'     => 2,
                'bordercolour'  => $black,
                'absolutey'  => 1,
                'absolutex'  => 1
            }));
        } else {
            $self->push(new Sanger::Graphics::Glyph::Text({
                'x'          => $node->{'x'} * $horizontal_scale + 5,
                'y'          => $node->{'y'} * 10 - 4,
                'font'       => 'Tiny',
                'colour'     => $black,
                'text'       => $node->{'id'},
                'absolutey'  => 1,
                'absolutex' => 1
            }));
        }
        $self->push(new Sanger::Graphics::Glyph::Line({
            'x'       => $node->{'xp'} * $horizontal_scale,
            'y'       => $node->{'yp'} * 10,
            'width'   => 0,
            'height'  => ($node->{'y'}-$node->{'yp'}) * 10,
            'colour'  =>  $black,
            'absolutey'        => 1, 'absolutex'        => 1
        }));
        $self->push(new Sanger::Graphics::Glyph::Line({
            'x'       => $node->{'xp'} * $horizontal_scale,
            'y'       => $node->{'y'} * 10,
            'width'   => ($node->{'x'}-$node->{'xp'}) * $horizontal_scale,
            'height'  => 0,
            'colour'  =>  $black,
            'absolutey'        => 1, 'absolutex'        => 1
        }));
    }
}
1;
