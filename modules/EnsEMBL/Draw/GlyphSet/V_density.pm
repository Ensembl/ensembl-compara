=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::V_density;
use strict;
use base qw(EnsEMBL::Draw::GlyphSet);
use Data::Dumper;
use List::Util qw( max );

### Parent module for vertical density tracks - does some generic data munging
### and draws the histogram/graph components

### Accepts a data hash in the format:
### $data = {
###     'scores'    => [],
###     'mins'      => [], #optional
###     'maxs'      => [], #optional
###     'display    => '_method',   # optional
###     'histogram' => 'bar_style', # optional
###     'colour'    => '',
###     'sort'      => 0,
### };

sub build_tracks {
  ## Does data munging common to vertical density tracks
  ## and draws optional max/min lines, as they are needed only once per glyphset
  my ($self, $data) = @_;
  ## Skip unless we are drawing density data
  return unless $data || ($self->{'data'} && ref($self->{'data'}) eq 'HASH');

  my $chr = $self->{'chr'} || $self->{'container'}->{'chr'};
  my $image_config  = $self->{'config'};
  my $track_config  = $self->{'my_config'};
  
  $data ||= $self->{'data'}{$chr};
  
  ## Translate legacy styles into internal ones
  my $display       = $self->{'display'};
  if ($display) {
    $display =~ s/^density//;
  }
  my $histogram;
  if ($display eq '_bar') {
    $display = '_histogram';
    $histogram = 'fill';
  }
  elsif ($display eq '_outline' || $display eq 'histogram') {
    $display = '_histogram';
  }

  ## Build array of track settings
  my @settings;
	my $chr_min_data ;
  my $chr_max_data  = 0;
	my $slice			    = $self->{'container'}->{'sa'}->fetch_by_region(undef, $chr);
  my $width         = $image_config->get_parameter( 'width') || 80;
  my $max_value     = $image_config->get_parameter( 'max_value' ) || 1;
  my $max_mean      = $image_config->get_parameter( 'max_mean' ) || 1;
  my $bins          = $image_config->get_parameter('bins') || 150;
  my $max_len       = $image_config->container_width();
  my $bin_size      = int($max_len/$bins);
  my $v_offset      = $max_len - ($slice->length() || 1);

  my @sorted = sort {$a->{'sort'} <=> $b->{'sort'}} values %$data;

  foreach my $info (@sorted) {
    my $T = {};
    my $scores = $info->{'scores'};
    next unless $scores && ref($scores) eq 'ARRAY' && scalar(@$scores);
    
    $T->{'style'}     = $info->{'display'} || $display;
    $T->{'histogram'} = $info->{'histogram'} || $histogram;
    $T->{'width'}     = $width;
    $T->{'colour'}    = $info->{'colour'};
    $T->{'max_mean'}  = $max_mean;
    $T->{'max_len'}   = $max_len;
    $T->{'bin_size'}  = $bin_size;
    $T->{'v_offset'}  = $v_offset;

    my $current_max = ref($scores->[0]) eq 'HASH' ? 0 : max @$scores;
    if (uc($chr) eq 'MT') {
      $T->{'max_value'} = undef;
    }
    else {
      $T->{'max_value'} = $info->{'max_value'} || $max_value;
    }

    my $scaled_scores = [];
    my $mins          = [];
    my $maxs          = [];
    my $local_max     = 1;
    foreach(@$scores) { 
      my $mean = $_;
      if (ref($_) eq 'HASH') {
        $mean = $_->{'mean'};
        push @$mins, $_->{'min'};
        push @$maxs, $_->{'max'};
      } 
      ## Use real values for max/min labels
		  $chr_min_data = $mean if ($mean < $chr_min_data || $chr_min_data eq undef); 
		  $chr_max_data = $mean if $mean > $chr_max_data;
      ## Scale data for actual display
      my $max;

      if ($T->{'max_value'}) {
        $max = $T->{'max_value'};  
        $max = $current_max if ($current_max > $max);
      } else {
        $max = ($current_max > $chr_max_data) ? $current_max : $chr_max_data;
      }
      $local_max = $max;

      push @$scaled_scores, $mean/$max * $width;
	  }
    $T->{'scores'} = $scaled_scores;
    $T->{'mins'}   = $mins;
    $T->{'maxs'}   = $maxs;
    $T->{'max_value'} ||= $local_max;
    push @settings, $T;
  }
  
  ## Add max/min lines if required
  if ($display eq '_line' && $track_config->get('maxmin') && scalar @settings) {
    $self->label2('Min:'.$chr_min_data.' Max:'.$chr_max_data); 
    $self->push( $self->Space( {
      'x' => 1, 'width' => 3, 'height' => $width, 'y' => 0, 'absolutey'=>1 
    } ));
    # max line (max)
    $self->push( $self->Line({
      'x'      => $v_offset ,
      'y'      => $width,
     'width'  => $max_len - $v_offset,
     'height' => 0,
     'colour' => 'lavender',
     'absolutey' => 1,
    }) );
    # base line (0)
    $self->push( $self->Line({
      'x'      => $v_offset ,
      'y'      => 0 ,
      'width'  => $max_len - $v_offset,
      'height' => 0,
      'colour' => 'lavender',
      'absolutey' => 1,
    }) );
    if ($image_config->get_parameter('all_chromosomes') eq 'yes') {
      # global max line (global max)
      $self->push( $self->Line({
        'x'      => $v_offset,
        'y'      => $width,
        'width'  => $max_len - $v_offset,
        'height' => 0,
        'colour' => 'lightblue',
        'absolutey' => 1,
      }) );
    }
	}

  ## Now add the data tracks
  foreach (@settings) {
    my $style = $_->{'style'};
    $self->$style($_);
  } 
}

sub _whiskers {
  my ($self, $T) = @_;
  $self->_line($T, {'whiskers' => 1});
}

sub _raw {
  my ($self, $T) = @_;
  $self->_line($T, {'scale_to_mean' => 1});
}

sub _line {
  my ($self, $T, $options) = @_;
  my @scores  =  @{$T->{'scores'}};
  my @mins    =  @{$T->{'mins'}};
  my @maxs    =  @{$T->{'maxs'}};
  ## These two options are mutually exclusive
  my $draw_whiskers = $options->{'whiskers'};
  my $scale_to_mean  = $draw_whiskers ? 0 : $options->{'scale_to_mean'};

  my $old_y = undef;
  for(my $x = $T->{'v_offset'} - $T->{'bin_size'}; $x < $T->{'max_len'}; $x += $T->{'bin_size'}) {
    my $datum       = shift @scores;
    last if not defined $datum;
    my $max_mean    = $T->{'max_mean'} || 1;
    my $scale       = $scale_to_mean ? $T->{'width'} / $max_mean : 1;
    my $new_y       = $datum * $scale;
    my $min_whisker = (shift @mins) * $scale;
    my $max_whisker = (shift @maxs) * $scale;
    if(defined $old_y) {
      
      $self->push( $self->Line({
        'x'      => $x ,
        'y'      => $old_y,
	      'width'  => $T->{'bin_size'},
 	      'height' => $new_y-$old_y,
 	      'colour' => $T->{'colour'},
 	      'absolutey' => 1,
      }) );			
    }
    if ($draw_whiskers && $min_whisker && $max_whisker) {
      my $whisker_len = $T->{'bin_size'};
      ## NOTE These x coordinates are based more on trial-and-error
      ## than on maths - I'm not sure how correct they are! 
      ## Main whisker line (min to max)
      $self->push( $self->Line({
        'x'      => $x + ($whisker_len * 2), 
        'y'      => $min_whisker,
        'width'  => 0,
 	      'height' => $max_whisker,
 	      'colour' => 'black',
 	      'absolutey' => 1,
      }) );
      ## Min whisker end
      $self->push( $self->Line({
        'x'      => $x + ($whisker_len * 1.5), 
        'y'      => $min_whisker,
	      'width'  => $whisker_len,
 	      'height' => 0, 
 	      'colour' => 'black',
 	      'absolutey' => 1,
      }) );
      ## Max whisker end
      $self->push( $self->Line({
        'x'      => $x + ($whisker_len * 1.5), 
        'y'      => $max_whisker,
	      'width'  => $whisker_len,
 	      'height' => 0, 
 	      'colour' => 'black',
 	      'absolutey' => 1,
      }) );
    }
    $old_y = $new_y;
  }
} 

sub _histogram {
  my ($self, $T)    = @_;
  my @data =  @{$T->{'scores'}};

  my $style = $T->{'histogram'} eq 'fill' ? 'colour' : 'bordercolour';
  my $bar_width = $T->{'histogram'} eq 'narrow' ? 0 : $T->{'bin_size'}; # * 2;

  my $old_y;
  for(my $x = $T->{'v_offset'}; $x < $T->{'max_len'}; $x += $T->{'bin_size'}) {
    my $datum = shift @data;
    last if not defined $datum;
    my $new_y = $datum / $T->{'max_value'} * $T->{'width'};

    if(defined $old_y) {
      $self->push( $self->Rect({
        'x'         => $x ,
        'y'         => 0, ## $old_y
        'width'     => $bar_width,
        'height'    => $datum, #$new_y-$old_y,
         $style     => $T->{'colour'},
        'absolutey' => 1,
      }) );
    }
    $old_y = $new_y;
  }
}

sub _set_scale {
  my ($self, $T) = @_;
  return $T->{'max_data'} ? $T->{'width'} / $T->{'max_data'} : $T->{'width'};
}

1;
