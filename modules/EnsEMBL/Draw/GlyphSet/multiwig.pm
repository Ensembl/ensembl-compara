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

package EnsEMBL::Draw::GlyphSet::multiwig;

### Module for drawing multiple bigWig files in a single track 
### (used by some trackhubs via the 'container = multiWig' directive)

use strict;

use EnsEMBL::Draw::Utils::ColourMap;
use EnsEMBL::Draw::Style::Extra::Header;

use parent qw(EnsEMBL::Draw::GlyphSet::bigwig);

sub can_json { return 1; }

sub init {
  my $self = shift;
  $self->{'my_config'}->set('scaleable', 1);
  my $data = [];
  foreach my $track (@{$self->my_config('subtracks')||{}}) {
    my $aref = $self->get_data(undef, $track->{'source_url'});
    ## Override default colour with value from parsed trackhub
    $aref->[0]{'metadata'}{'colour'} = $track->{'colour'};
    $aref->[0]{'metadata'}{'label'} = $track->{'source_name'};
    push @$data, $aref->[0];
  }
  $self->{'data'} = $data;
}

sub render_signal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->{'my_config'}->set('on_error',555);
  $self->_render_aggregate;
}

sub draw_aggregate {
  my ($self, $data) = @_;
  $data ||= $self->{'data'};
  return unless $data && ref $data eq 'ARRAY';
  my $feature_count = 0;
  my $colour_legend = {};

  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('multi', 1);
  $self->{'my_config'}->set('hide_subtitle',1);

  my $colourmap = new EnsEMBL::Draw::Utils::ColourMap($self->{'config'}{'hub'}->species_defs);

  foreach (@$data) {
    next unless $_->{'features'} && ref $_->{'features'} eq 'ARRAY';
    $feature_count += scalar(@{$_->{'features'}||[]});
    $_->{'metadata'}{'subtitle'} ||= $self->{'my_config'}->get('longLabel')
                                      || $self->{'my_config'}->get('caption');
    my $colour = $_->{'metadata'}{'colour'};
    if ($colour =~ /,/) {
      my @split = split(',', $colour);
      $colour = $colourmap->hex_by_rgb(\@split);
    }
    $colour_legend->{$_->{'metadata'}{'label'}} = $colour;
  }

  if ($feature_count < 1) {
    return $self->no_features;
  }

  my %config = %{$self->track_style_config};
  $config{'bg_href'} = $self->bg_href;
  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Graph'];

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    if ($self->dynamic_use($style_class)) {
      my $style = $style_class->new(\%config, $data);
      $self->push($style->create_glyphs);
    }
  }

  ## Prepare to draw any headers/labels in lefthand column
  my $header = EnsEMBL::Draw::Style::Extra::Header->new(\%config);
  my $params = {
                label           => 'Legend',
                title           => $self->{'my_config'}->get('name') || 'Individual tracks',
                colour_legend   => $colour_legend,
                y_offset        => 20,
               };
  $header->draw_sublegend($params);
  $self->push(@{$header->glyphs||[]});

  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  return 0;
}

sub _colour_legend {

}


1;
