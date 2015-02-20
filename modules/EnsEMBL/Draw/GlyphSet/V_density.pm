=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### Parent module for vertical density tracks - does some generic data munging
### and draws the histogram/graph components

### Accepts a data hash in the format:
### $data = {
###     'scores'    => [],
###     'display    => '_method',   # optional
###     'histogram' => 'bar_style', # optional
###     'colour'    => '',
###     'sort'      => 0,
### };

sub build_tracks {
  ## Does data munging common to vertical density tracks
  ## and draws optional max/min lines, as they are needed only once per glyphset
  my ($self, $data) = @_;
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
  my $max_data      = $image_config->get_parameter( 'max_value' ) || 1;
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
    $T->{'max_data'}  = $max_data;
    $T->{'max_len'}   = $max_len;
    $T->{'bin_size'}  = $bin_size;
    $T->{'v_offset'}  = $v_offset;

    my $scaled_scores = [];
    foreach(@$scores) { 
      ## Use real values for max/min labels
		  $chr_min_data = $_ if ($_ < $chr_min_data || $chr_min_data eq undef); 
		  $chr_max_data = $_ if $_ > $chr_max_data;
      ## Scale data for actual display
      my $max = $chr_max_data || 1; 
      push @$scaled_scores, $_/$max * $width;
	  }
    $T->{'scores'} = $scaled_scores;
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
      'y'      => $chr_max_data,
     'width'  => $max_len - $v_offset ,
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

sub _line {
  my ($self, $T) = @_;
  my @data =  @{$T->{'scores'}};

  my $old_y = undef;
  for(my $x = $T->{'v_offset'} - $T->{'bin_size'}; $x < $T->{'max_len'}; $x += $T->{'bin_size'}) {
    my $datum = shift @data;
    my $new_y = $datum; # / $T->{'max_data'} * $T->{'width'} ;
   
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
    my $new_y = $datum / $T->{'max_data'} * $T->{'width'};

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

1;
