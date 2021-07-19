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

package EnsEMBL::Draw::GlyphSet::marker;

### Draws marker track

use strict;

use EnsEMBL::Draw::Style::Feature;

use base qw(EnsEMBL::Draw::GlyphSet);

sub render_normal {
  my $self = shift;

  return unless $self->strand == -1;

  my $slice  = $self->{'container'};
  my $length = $slice->length;
  if ($length > 5e7) {
    $self->errorTrack('Markers only displayed for less than 50Mb.');
    return;
  }

  $self->{'my_config'}->set('show_labels', 1);
  $self->{'my_config'}->set('bumped', 'labels_only');

  my @logic_names    = @{$self->my_config('logic_names') || []};
  my $logic_name     = $logic_names[0];
  ## Fetch all markers if this isn't a subset, e.g. SATMap
  $logic_name        = undef if $logic_name eq 'marker';
  my $data           = $self->get_data($logic_name);

  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Feature->new($config, $data);
  $self->push($style->create_glyphs);
}

sub render_text {
  my $self = shift;
  #return join '', map $self->_render_text($_, 'Marker', { headers => [ 'id' ], values => [ $_->{'drawing_id'} ] }), @{$self->features};
}

sub get_data {
  my ($self, $logic_name) = @_;

  my $hub = $self->{'config'}{'hub'}; 
  my $features = $hub->get_query('GlyphSet::Marker')->go($self,{
                                slice => $self->{'container'},
                                species => $self->{'config'}{'species'},
                                logic_name => $logic_name,
                                priority => $self->my_config('priority'),
                                marker_id => $self->my_config('marker_id')
                  });
  return [{'features' => $features}];
}

1;
