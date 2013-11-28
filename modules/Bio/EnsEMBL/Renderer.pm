=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Renderer;
use strict;

sub new {
  my ($class, $config, $container, $glyphsets_ref) = @_;

  my $self = {
    'glyphsets' => $glyphsets_ref,
    'canvas'    => undef,
    'colourmap' => $config->colourmap(),
    'config'    => $config,
    'container' => $container,
    'spacing'   => 5,
  };

  bless($self, $class);

  $self->render();

  return $self;
}

sub render {
  my ($self) = @_;

  my $config = $self->{'config'};

  #########
  # now set all our labels up with scaled negative coords
  # and while we're looping, tot up the image height
  #
  my $spacing   = $self->{'spacing'};
  my $im_height = $spacing * 1.5;

  for my $glyphset (@{$self->{'glyphsets'}}) {
    next if (scalar @{$glyphset->{'glyphs'}} == 0);
    my $fntheight = (defined $glyphset->label())?$config->texthelper->height($glyphset->label->font()):0;
    my $gstheight = $glyphset->height();

    $im_height += $spacing + ( $gstheight > $fntheight ? $gstheight : $fntheight );
  }

  $config->image_height($im_height);
  my $im_width = $config->image_width();

  #########
  # create a fresh canvas
  #
  if($self->can('init_canvas')) {
    $self->init_canvas($config, $im_width, $im_height);
  }

  for my $glyphset (@{$self->{'glyphsets'}}) {
    next if(scalar @{$glyphset->{'glyphs'}} == 0);

    #########
    # loop through everything and draw it
    #
    for my $glyph ($glyphset->glyphs()) {
      my $method = $self->method($glyph);
      if($self->can($method)) {
        $self->$method($glyph);
      } else {
        warn qq(Bio::EnsEMBL::Renderer::render: Do not know how to $method\n);
      }
    }

  }
    

  #########
  # the last thing we do in the render process is add a frame
  # so that it appears on the top of everything else...
    
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
      warn qq(Bio::EnsEMBL::Renderer::render_Composite: Do not know how to $method\n);
    }
  }
}

#########
# empty stub for Blank spacer objects with no rendering at all
#
sub render_Space {
}

1;
