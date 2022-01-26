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

package EnsEMBL::Draw::VRenderer::imagemap;

### Renders vertical ideograms as an imagemap
### Modeled on EnsEMBL::Draw::Renderer::imagemap

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Draw::VRenderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
  shift->canvas([]);
}

sub render_Circle  {}
sub render_Line    {}
sub render_Ellipse {}
sub render_Intron  {}

sub render_Composite { shift->render_Rect(@_); }
sub render_Space     { shift->render_Rect(@_); }
sub render_Text      { shift->render_Rect(@_); }

sub render_Rect {
  my ($self, $glyph) = @_;

  my $attrs = $self->get_attributes($glyph);  
    
  return unless $attrs;
  
  my $x1 = $glyph->{'pixelx'};
  my $x2 = $x1 + $glyph->{'pixelwidth'};
  my $y1 = $glyph->{'pixely'};
  my $y2 = $y1 + $glyph->{'pixelheight'};

  $x1 = 0 if $x1 < 0;
  $x2 = 0 if $x2 < 0;
  $y1 = 0 if $y1 < 0;
  $y2 = 0 if $y2 < 0;
  
  $y2++;
  $x2++;

  $self->render_area('rect', [ $y1, $x1, $y2, $x2 ], $attrs) if($self->{'config'}->species_defs->ENSEMBL_SITETYPE ne 'Ensembl mobile');  
}

sub render_Poly {
  my ($self, $glyph) = @_;
  my $attrs = $self->get_attributes($glyph);
  
  return unless $attrs;

  $self->render_area('poly', [ reverse @{$glyph->pixelpoints} ], $attrs) if($self->{'config'}->species_defs->ENSEMBL_SITETYPE ne 'Ensembl mobile');
}

sub render_area {
  my ($self, $shape, $points, $attrs) = @_;
 
  my $coords = join ',', map int, @$points;

  push @{$self->canvas},[$shape,[map int, @$points],$attrs];
}

sub get_attributes {
  my ($self, $glyph) = @_;

  my %actions = ();  
  foreach (qw(title alt href target class id)) {
    my $attr = $glyph->$_;
 
    if (defined $attr) {
      if ($_ eq 'alt' || $_ eq 'title') {
        $actions{'title'} = $actions{'alt'} = encode_entities($attr);
      } elsif ($_ eq 'class') {
        $actions{'klass'} = [ split(/ /,$attr) ];
      } elsif ($_ eq 'id') {
        $actions{$_} = $attr if($attr);
      } else {
        $actions{$_} = $attr;
      }
    }
  }

  return unless $actions{'title'} || $actions{'href'};
  
  $actions{'alt'} ||= '';

  return \%actions;
}

1;
