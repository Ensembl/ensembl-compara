package Bio::EnsEMBL::VRenderer;
use strict;
use Exporter;
use vars qw(@ISA);

@ISA = qw(Exporter);

sub new {
    my ($class, $config, $container, $glyphsets_ref) = @_;

    my $self = {
        'glyphsets' => $glyphsets_ref,
        'canvas'    => undef,
        'colourmap' => $config->colourmap(),
        'config'    => $config,
        'container' => $container
    };
    bless($self, $class);
    $self->render();
    return $self;
}

sub render {
    my ($self) = @_;

    my $config = $self->{'config'};

    my $im_width  = $config->{'_max_width'};
    my $im_height = $config->{'_max_height'};

    ########## create a fresh canvas
    if($self->can('init_canvas')) {
        $self->init_canvas($config, $im_width, $im_height);
    }

    for my $glyphset (@{$self->{'glyphsets'}}) {
        ########## loop through everything and draw it
        for my $glyph ($glyphset->glyphs()) {
            my $method = $self->method($glyph);
            if($self->can($method)) {
                $self->$method($glyph);
            } else {
                print STDERR qq(Bio::EnsEMBL::Renderer::render: Do not know how to $method\n);
            }
        }

    }
        
    ########## the last thing we do in the render process is add a frame
    ########## so that it appears on the top of everything else...
    $self->add_canvas_frame($config, $im_width, $im_height);
}

sub canvas {
    my ($self, $canvas) = @_;
    $self->{'canvas'} = $canvas if(defined $canvas);
    return $self->{'canvas'};
}

sub method {
    my ($self, $glyph) = @_;

    my ($suffix) = ref($glyph) =~ /.*::(.*)/;
    return qq(render_$suffix);
}

sub render_Composite {
    my ($self, $glyph) = @_;

    for my $subglyph (@{$glyph->{'composite'}}) {
        my $method = $self->method($subglyph);

        if($self->can($method)) {
            $self->$method($subglyph);
        } else {
            print STDERR qq(Bio::EnsEMBL::VRenderer::render_Composite: Do not know how to $method\n);
        }
    }
}

########## empty stub for Blank spacer objects with no rendering at all
sub render_Blank { }

1;
