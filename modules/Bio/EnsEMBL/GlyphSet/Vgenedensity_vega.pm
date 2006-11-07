package Bio::EnsEMBL::GlyphSet::Vgenedensity_vega;
use strict;
use Bio::EnsEMBL::GlyphSet;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my $self = shift;
    my $Config = $self->{'config'};
    my $track = $self->check;
    my @logic_names =  $Config->get($track, 'logicname');
    my @labels = @{$Config->get($track, 'label')};
    my @colours = split ' ',@{$Config->get($track, 'colour')}[0];
    my $chr = $self->{'container'}->{'chr'};
    my $slice_adapt   = $self->{'container'}->{'sa'};
    my $density_adapt = $self->{'container'}->{'da'};
    my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);
    my ($i, $last_max);	
    foreach my $label (@labels) {
        my $logic_name = shift @logic_names;
        my $colour = shift @colours;
		my $density;
		foreach my $ln (split ' ', $logic_name) {
            $density = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $ln, 150, 1);
            $last_max = $density->max_value;
        }
	
	## draw label only if there is genes of this type or if we have
    ## a two-line label
	if ($last_max) { 
            my $text = new Sanger::Graphics::Glyph::Text({
                'text'      => $label,
                'font'      => 'Small',
                'colour'    => $Config->get('_colours', $colour)->[0],
                'absolutey' => 1,
                });
            my $func = 'label' . $i;
            $self->$func($text);
            $i += 2;
        }
    }
}

sub _init {
    my $self = shift;
    my $Config = $self->{'config'};
    my $track = $self->check;
    my @logic_names =  split ' ',$Config->get($track, 'logicname');
    my @colours = split ' ',@{ $Config->get($track, 'colour') }[0];
    my $chr = $self->{'container'}->{'chr'};
    my $slice_adapt   = $self->{'container'}->{'sa'};  
    my $density_adapt = $self->{'container'}->{'da'};
    my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);

    ## get max density for scaling
    foreach (@{ $Config->get('_settings', 'scale_values') }) {
        my $max = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $_, 150, 1)->max_value;
        $self->{'_max'} = $max if ($max > $self->{'_max'}); 
    }

    ## get density from adaptor
    my $density1 = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $logic_names[0], 150, 1);
    my $density1_max = $density1->max_value;

    my ($density2, $density2_max);
    if ($logic_names[1]) {
        ## we have two tracks to display
        $density2 = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $logic_names[1], 150, 1);
        $density2_max = $density2->max_value;
    }

    ## return if there is no data to display
    return unless (($density1_max > 0) || ($density2_max > 0));

    ## scale the tracks and add glyphs
    my $Hscale_factor1 = 1;
    my $Hscale_factor2 = 1;
    if ($self->{'_max'} > 0) {
        $Hscale_factor1 = ($density1_max / $self->{'_max'});
        $Hscale_factor2 = ($density2_max / $self->{'_max'});
    } 
    ## draw track 2 only if available
    if ($density2_max) {
        $density2->scale_to_fit($Config->get($track, 'width') * $Hscale_factor2);
        $density2->stretch(0);
        foreach (@{ $density2->get_all_binvalues }) {
            $self->push( new Sanger::Graphics::Glyph::Rect({
                'x'      => $_->start,
                'y'      => 0,
                'width'  => $_->end-$_->start,
                'height' => $_->scaledvalue,
	        	'colour' => $Config->get('_colours', $colours[1])->[0],
                'absolutey' => 1,
            }));
        }
    }
    $density1->scale_to_fit($Config->get($track, 'width') * $Hscale_factor1);
    $density1->stretch(0);
    foreach (@{ $density1->get_all_binvalues }) {
        $self->push( new Sanger::Graphics::Glyph::Rect({
            'x'      => $_->start,
            'y'      => 0,
            'width'  => $_->end-$_->start,
            'height' => $_->scaledvalue,
    	    'bordercolour' => $Config->get('_colours', $colours[0])->[0],
            'absolutey' => 1,
            'href'   => "/@{[$self->{container}{_config_file_name_}]}/contigview?chr=$chr;vc_start=$_->{'chromosomestart'};vc_end=$_->{'chromosomeend'}"
            }));
    }
}

1;
