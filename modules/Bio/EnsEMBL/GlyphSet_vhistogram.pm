package Bio::EnsEMBL::GlyphSet_vhistogram;
use strict;
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr = $self->{'container'}->{'chr'};
    # get label definition from subclass
    my @label_def = $self->my_label();
    my @labels;
    my $i;
    foreach my $label_def (@label_def) {
        my $density = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr, $label_def->{'type'});
        # draw label only if there is genes of this type
        if ($density->{'_biggest_value'}) {
            my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => $label_def->{'text'},
		'font'      => 'Small',
		'colour'    => $Config->get('_colours', $label_def->{'colour'}),
		'absolutey' => 1,
            });
            my $func = 'label' . $i;
            $self->$func($label);
            $i += 2;
        }
    }
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $feature_name = $self->check();
    my $chr = $self->{'container'}->{'chr'};
    # get track definitions from subclass
    my @track_def = $self->logic_name();

    # get density from adaptor
    my $density1 = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr, $track_def[0]->{'type'});
    my ($density2, $has_density2);
    if ($track_def[1]) {
        # we have two tracks to display
        $density2 = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr, $track_def[1]->{'type'});
        $has_density2 = $density2->size();
    }
    # get max density for scaling
    my $ignore_types = ['gc', 'gene', 'kngene', 'repeat'];
    my $max_density = $self->{'container'}->{'da'}->get_max_density_per_chromosome($chr, $ignore_types);
    # return if there is no data to display
    return unless ($density1->size() || $has_density2);
    my $density1_max = $density1->{'_biggest_value'};
    my $density2_max = $density2->{'_biggest_value'};
    return unless (($density1_max > 0) || ($has_density2 && ($density2_max > 0)));

    # scale the tracks and add glyphs
    my $Hscale_factor1 = 1;
    my $Hscale_factor2 = 1;
    if ($max_density > 0) {
        $Hscale_factor1 = ($density1_max / $max_density);
        $Hscale_factor2 = ($density2_max / $max_density);
    } 
    $density1->scale_to_fit($Config->get($feature_name, 'width') * $Hscale_factor1);
    $density1->stretch(0);
    my @density1 = $density1->get_binvalues();
    my $g_x;
    if ($track_def[1]) {
        $density2->scale_to_fit($Config->get($feature_name, 'width') * $Hscale_factor2);
        $density2->stretch(0);
        my @density2 = $density2->get_binvalues();
        # draw track 2 only if available
        foreach (@density2) {
            $g_x = new Sanger::Graphics::Glyph::Rect({
                'x'      => $_->{'chromosomestart'},
                'y'      => 0,
                'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
                'height' => $_->{'scaledvalue'},
		'colour' => $Config->get('_colours', $track_def[1]->{'colour'}),
                'absolutey' => 1,
            });
            $self->push($g_x);
        }
    }
    foreach (@density1) {
        $g_x = new Sanger::Graphics::Glyph::Rect({
            'x'      => $_->{'chromosomestart'},
            'y'      => 0,
            'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
            'height' => $_->{'scaledvalue'},
	    'bordercolour' => $Config->get('_colours', $track_def[0]->{'colour'}),
            'absolutey' => 1,
            'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
            });
        $self->push($g_x);
    }
}

1;
