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

package EnsEMBL::Draw::GlyphSet::marker;

### Draws marker track

use strict;

use EnsEMBL::Draw::Style::Blocks;

use base qw(EnsEMBL::Draw::GlyphSet);

sub colour_key    { return lc $_[1]->marker->type; }

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
  my $features       = $self->features($logic_name);

  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Blocks->new($config, $features);
  $self->push($style->create_glyphs);

}

sub render_text {
  my $self = shift;
  return join '', map $self->_render_text($_, 'Marker', { headers => [ 'id' ], values => [ $_->{'drawing_id'} ] }), @{$self->features};
}

sub features {
  my ($self, $logic_name) = @_;
  my $slice   = $self->{'container'};
  my $length  = $slice->length;
  my $data    = [];
  my @features;
  
  if ($self->{'text_export'}) {
    @features = @{$slice->get_all_MarkerFeatures};
  } else {
    my $priority   = $self->my_config('priority');
    my $marker_id  = $self->my_config('marker_id');
    my $map_weight = 2;
    @features   = (@{$slice->get_all_MarkerFeatures($logic_name, $priority, $map_weight)});
    push @features, @{$slice->get_MarkerFeatures_by_Name($marker_id)} if ($marker_id and !grep {$_->display_id eq $marker_id} @features); ## Force drawing of specific marker regardless of weight (but only if not already being drawn!)
  }
  
  my ($previous_id, $previous_start, $previous_end);
  foreach my $f (@features) {
    my $ms  = $f->marker->display_MarkerSynonym;
    my $id  = $ms ? $ms->name : '';
      ($id) = grep $_ ne '-', map $_->name, @{$f->marker->get_all_MarkerSynonyms || []} if $id eq '-' || $id eq '';
    
    $f->{'drawing_id'} = $id;
  }
  
  foreach my $f (sort { $a->seq_region_start <=> $b->seq_region_start } @features) {
    my $id = $f->{'drawing_id'};

    ## Remove duplicates
    next if $id == $previous_id && $f->start == $previous_start && $f->end == $previous_end;

    my $feature_colour = $self->my_colour($self->colour_key($f)) || 'magenta';

    my $start          = $f->start - 1;
    my $end            = $f->end;
    next if $start > $length || $end < 0;
    $start = 0       if $start < 0;
    $end   = $length if $end > $length;

    push @$data, {
                  'start'         => $start,
                  'end'           => $end,
                  'colour'        => $feature_colour,
                  'label'         => $id,
                  'label_colour'  => $feature_colour, 
                  'href'          => $self->href($f),
                  };
    $previous_id    = $id;
    $previous_start = $start;
    $previous_end   = $end;
  }

  return $data;
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    species => $self->species,
    type    => 'Marker',
    m       => $f->{'drawing_id'},
  });
}

1;
