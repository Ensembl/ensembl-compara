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

package EnsEMBL::Draw::GlyphSet::navigation;

### Navigation "sprites" for Region Comparison image
### See EnsEMBL::Web::ImageConfig::MultiBottom

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub render {
  my $self = shift;
  
  return $self->render_highlighting if $self->strand > 0 || $self->get_parameter('export');

  my $href = $self->get_parameter('base_url') . ';action=%s;id=' . --[split '|', $self->get_parameter('slice_number')]->[0];
  
  my $sprite_size = 18;
  my $sprite_pad = 3;
  my $sprite_step = $sprite_size + $sprite_pad;
  my $compara = $self->get_parameter('compara');

  my $sprites = {
    nav   => [ 
      -60 - $sprite_size, 
      -$sprite_step,
      [ 'zoom_out', 'out'     ],
      [ 'nudge_left', 'left'  ],
      [ 'left',       'left2' ],
    ],
    left  => [ 
      -60, 
      $sprite_step,
    ],
    right => [ 
      $sprite_pad * 2, 
      -$sprite_step,
      [ 'right',       'right2'  ],
      [ 'nudge_right', 'right'   ],
      [ 'zoom_in',     'in'      ],
      [ 'realign',     'realign' ],
    ]
  };
  
  if ($compara ne 'primary') {
    push @{$sprites->{'right'}}, [ 'flip_strand', 'flip' ];
    $sprites->{'right'}[0] += $sprite_step;
  }
  if ($compara eq 'secondary') { 
    # Not available for paralogues
    $sprites->{'right'}[0] += $sprite_step;
    push @{$sprites->{'right'}}, [ 'set_as_primary', 'primary' ];
  }

  foreach my $key (keys %$sprites) {
    my ($pos, $step,  @sprite_array) = @{$sprites->{$key}};
    
    foreach my $sprite (@sprite_array) {
      (my $alt = $sprite->[0]) =~ s/_/ /g;
      
      $self->push($self->Sprite({
        z             => 1000,
        x             => $pos,
        y             => $sprite_size,,
        sprite        => $sprite->[0],
        width         => $sprite_size,
        height        => $sprite_size,
        absolutex     => 1,
        absolutewidth => 1,
        absolutey     => 1,
        href          => sprintf($href, $sprite->[1]),
        class         => 'nav',
        alt           => ucfirst($alt)
      }));
      
      $pos += $step;
    }
  }
  
  $self->render_highlighting;
}

sub render_highlighting {
  my $self = shift;
  
  my $label_width = $self->{'config'}->get_parameter('label_width');
  my $compara = $self->get_parameter('compara'); 
  my ($y, $tag1, $tag2) = $self->strand > 0 ? (0, 0, 0.9) : (12, 0.9, 0);
  
  my $line = $self->Line({
    x             => -($label_width) - 11,
    y             => $y,
    width         => $label_width + 20,
    height        => 0,
    absolutex     => 1,
    absolutewidth => 1,
    absolutey     => 1
  });
  
  $self->join_tag($line, 'bracket', 0, 0, 'black');

  if ($compara eq 'primary') {
    $self->join_tag($line, 'bracket2', $tag1, 0, 'rosybrown1', 'fill', -40);
    $self->join_tag($line, 'bracket2', $tag2, 0, 'rosybrown1', 'fill', -40);
  }
  
  $self->push($line);
  
  $self->push($self->Line({
    x             => 0,
    y             => $y,
    colour        => 'black',
    width         => 20000,
    height        => 0,
    absolutex     => 1,
    absolutewidth => 1,
    absolutey     => 1
  }));
}

1;
