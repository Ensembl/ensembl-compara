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

package EnsEMBL::Draw::GlyphSet::repeat;

### Draws repeat feature tracks as simple (grey) blocks

use strict;

use EnsEMBL::Draw::Style::Feature;

use base qw(EnsEMBL::Draw::GlyphSet::Simple);

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('depth', 20);
  return $self->_render;
}

sub render_compact {
  my $self = shift;
  return $self->_render;
}

sub _render {
  my $self = shift;
  $self->{'my_config'}->set('striped', 1);

  my $data = $self->get_data;
  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Feature->new($config, $data);
  $self->push($style->create_glyphs);
}

sub get_data {
  my $self = shift;

  my $repeats = $self->features || [];
  if (!scalar @$repeats) {
    $self->no_features;
    return [];
  }

  my $colours   = [$self->my_colour('repeat'), $self->my_colour('repeat', 'alt')];
  my $features  = [];
  my $i;

  foreach (@$repeats) {
    my $colour = ($i % 2 == 0) ? $colours->[0] : $colours->[1];
    push @$features, {
                      'start'   => $_->start,
                      'end'     => $_->end,
                      'colour'  => $colour,
                      'title'   => $self->title($_),
                      };
    $i++;
  }

  return [{'features' => $features}];
}

sub features {
  ## Get raw API objects - needed by zmenu
  my $self        = shift;
  my $types       = $self->my_config('types');
  my $logic_names = $self->my_config('logic_names');

  my @repeats = map { my $t = $_; map @{$self->{'container'}->get_all_RepeatFeatures($t, $_)}, @$types } @$logic_names;
  return \@repeats;
}

sub title      { return sprintf '%s; bp: %s-%s; length: %s', $_[1]->repeat_consensus->name, $_[1]->seq_region_start, $_[1]->seq_region_end, $_[1]->length; }

sub href {
  my ($self, $f)  = @_;
  
  return $self->_url({
    species => $self->species,
    type    => 'Repeat',
    id      => $f->dbID
  });
}

sub export_feature {
  my ($self, $feature) = @_;
  my $id = "repeat:$feature->{'dbID'}";
  
  return if $self->{'export_cache'}{$id};
  
  $self->{'export_cache'}{$id} = 1;
  
  return $self->_render_text($feature, 'Repeat', undef, { source => $feature->display_id });
}

1;
