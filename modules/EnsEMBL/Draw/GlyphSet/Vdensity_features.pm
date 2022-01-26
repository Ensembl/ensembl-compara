=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::Vdensity_features;

### Module used by feature density tracks on Location/Chromosome
### See EnsEMBL::Web::Component::Location::ChromosomeImage

use strict;
use warnings;
no warnings 'uninitialized';

use POSIX qw(ceil);

use base qw(EnsEMBL::Draw::GlyphSet::V_density);

sub _init {
  my ($self) = @_;
  my $image_config  = $self->{'config'};
  my $chr           = $self->{'extras'}->{'chr'} || $self->{'container'}->{'chr'};

  my $slice_adapt   = $self->{'container'}->{'sa'};
  my $density_adapt = $self->{'container'}->{'da'};

  my $chr_slice = $slice_adapt->fetch_by_region(undef, $chr);

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
    my $track_width = $self->my_config('width') || 80;
    $_->{'density'}->scale_to_fit($track_width * $_->{'scale'});
    $_->{'density'}->stretch(0);
    my $scores = [];
    my $features = $_->{'density'}->get_all_binvalues || [];
    next unless scalar(@$features);

    ## Convert to a simple array of scores (since that's all we need for the display)
    foreach (@$features) {
      my $value = $_->scaledvalue;
      if ($key eq 'snpdensity') {
        $value = log(ceil($value)) if $value;
      }
      push @$scores, $value;
    }
    $data->{$key} = {
      'scores' => $scores,
      'colour' => $self->my_colour($_->{'key'}),
      'sort'   => $i,
    };

    if ($key eq 'snpdensity') {
      $data->{$key}{'max_value'} = log($max_value); 
    }

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
