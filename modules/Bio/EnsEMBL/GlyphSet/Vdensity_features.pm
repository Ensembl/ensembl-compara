package Bio::EnsEMBL::GlyphSet::Vdensity_features;
use strict;
use warnings;
no warnings 'uninitialized';
use base qw(Bio::EnsEMBL::GlyphSet::V_density);

sub _init {
  my ($self) = @_;
  my $image_config  = $self->{'config'};
  my $chr           = $self->{'extras'}->{'chr'} || $self->{'container'}->{'chr'};

  my $slice_adapt   = $self->{'container'}->{'sa'};
  my $density_adapt = $self->{'container'}->{'da'};

  my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);

  my @objs = map { { 'key' => $_,'scale'=>1,'max_value'=>0} }
             @{ $self->my_config('keys')||[] };

  my $features = 0;
  my $max_value = 0;

## Pass one - get all the densities from the database...
  my $bins = 150;
  $image_config->set_parameter( 'bins', $bins );
  foreach(@objs) {
    $_->{'density'}   = $_->{'key'} ? $density_adapt->fetch_Featureset_by_Slice( $chr_slice, $_->{'key'}, $bins, 1 ) : undef;
    next unless $_->{'density'};
    $_->{'max_value'} = $_->{'density'}->max_value;
    $max_value = $_->{'max_value'} if $_->{'max_value'} > $max_value;
    $features += $_->{'density'}->size;
  }
  return unless $max_value;

  ## Get the maximum value from all defined tracks if we want to scale across multiple tracks
  if ($self->my_config('scale_all')) {
    foreach my $sv (@{ $image_config->get_parameter('scale_values') })  {
      my $density = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $sv, 150, 1);
      my $this_max_value = $density->max_value;
      $max_value = $this_max_value if $this_max_value > $max_value;
    }
  }
  $image_config->set_parameter('max_value', $max_value);

## Pass two - if they are all on the same scale - set scale factor to ratio with highest value..

  if( $self->my_config('same_scale') || $self->my_config('scale_all') ) {
    foreach (@objs) {
      $_->{'scale'} = $_->{'max_value'}/$max_value;
    }
  }

## Pass three - now rescale all values to fit track width and sort out styling

  my ($data, $key);
  my $i = 0;
 
  foreach(@objs) {
    next unless $_->{'density'};
    $key = $_->{'key'};

    ## Scale values
    $_->{'density'}->scale_to_fit( ($self->my_config( 'width' )||80) * $_->{'scale'} );
    $_->{'density'}->stretch(0);
    my $scores = [];
    my $features = $_->{'density'}->get_all_binvalues || [];
    next unless scalar(@$features);

    ## Convert to a simple array of scores (since that's all we need for the display)
    foreach (@$features) {
      push @$scores, $_->scaledvalue;
    }
    $data->{$key} = {
      'scores' => $scores,
      'colour' => $self->my_colour($_->{'key'}),
      'sort'   => $i,
    };

    ## Deal with styling differences between preconfigured tracks and new options
    my $style = $self->my_colour($_->{'key'},'style');
    if ($self->{'display'} eq 'density_graph' || $self->{'display'} eq 'density_line') {
      $style = 'line';
    }
    elsif ($self->{'display'} eq 'density_bar') {
      $style = 'fill';
    }
    elsif ($self->{'display'} eq 'density_outline' && scalar(@objs) < 2) {
      $style = 'box';
    }
    if( $style eq 'fill' || $style eq 'box' ) {
      $data->{$key}{'display'} = '_histogram';
      $data->{$key}{'histogram'} = $style;
      ## Always draw filled boxes first
      if ( $style eq 'fill') {
        $data->{$key}{'sort'} =  0;
      }
    }
    elsif ($style eq 'narrow') {
      $data->{$key}{'display'} = '_histogram';
      $data->{$key}{'histogram'} = 'narrow';
    }
    else {
      $data->{$key}{'display'} = '_line';
    }
    $i++;
  }

## Render the features
  $self->build_tracks($data);

}

1;
