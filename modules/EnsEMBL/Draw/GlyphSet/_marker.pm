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

package EnsEMBL::Draw::GlyphSet::_marker;

### Draws marker track

##################
# DEPRECATED!
##################

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub feature_label { return $_[1]->{'drawing_id'}; }
sub colour_key    { return lc $_[1]->marker->type; }

sub _init {
  my $self = shift;
  warn "############# DEPRECATED MODULE - USE GlyphSet::marker instead";
  warn "This module will be removed in release 82";
  
  return unless $self->strand == -1;
  return $self->render_text if $self->{'text_export'};
  
  $self->_init_bump;
  
  my $slice  = $self->{'container'};
  my $length = $slice->length;
  
  if ($length > 5e7) {
    $self->errorTrack('Markers only displayed for less than 50Mb.');
    return;
  }
  
  my $pix_per_bp     = $self->scalex;
  my %font_params    = $self->get_font_details('outertext', 1);
  my $text_height    = [$self->get_text_width(0, 'X', '', %font_params)]->[3];
  my $labels         = $self->my_config('labels') ne 'off' && $length < 1e7;
  my $row_height     = 8;
  my $previous_start = $length + 1e10;
  my $previous_end   = -1e10;
  my $previous_id    = '';
  my @logic_names    = @{$self->my_config('logic_names') || []};
  my $logic_name     = $logic_names[0];
  ## Fetch all markers if this isn't a subset, e.g. SATMap
  $logic_name        = undef if $logic_name eq 'marker';
  my $features       = $self->features($logic_name);
  
  foreach my $f (@$features) {
    my $id = $f->{'drawing_id'};

    ## Remove duplicates
    next if $id == $previous_id && $f->start == $previous_start && $f->end == $previous_end;

    my $feature_colour = $self->my_colour($self->colour_key($f));
    my $start          = $f->start - 1;
    my $end            = $f->end;
    
    next if $start > $length || $end < 0;
    
    $start = 0       if $start < 0;
    $end   = $length if $end > $length;

    # Draw feature
    unless ($slice->strand < 0 ? $previous_start - $start < 0.5 / $pix_per_bp : $end - $previous_end < 0.5 / $pix_per_bp) {
      $self->push($self->Rect({
        x         => $start,
        y         => 0,
        height    => $row_height, 
        width     => $end - $start,
        colour    => $feature_colour, 
        absolutey => 1,
        href      => $self->href($f)
      }));
      
      $previous_end   = $end;
      $previous_start = $end;
    }
    
    $previous_id = $id;
    
    next unless $labels;
    
    my $text_width = [$self->get_text_width(0, $id, '', %font_params)]->[2];
    
    my $glyph = $self->Text({
      x         => $start,
      y         => $row_height,
      height    => $text_height,
      width     => $text_width / $pix_per_bp,
      halign    => 'left',
      colour    => $feature_colour,
      absolutey => 1,
      text      => $id,
      href      => $self->href($f),
      %font_params
    });

    my $bump_start = int($glyph->x * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end   = $bump_start + $text_width;
    my $row        = $self->bump_row($bump_start, $bump_end, 1);
    
    next if $row < 0; # don't display if falls off RHS
    
    $glyph->y($glyph->y + (1.2 * $row * $text_height));
    $self->push($glyph);
  }
  
  ## No features show "empty track line" if option set
  $self->errorTrack('No markers in this region') if !scalar @$features && $self->{'config'}->get_option('opt_empty_tracks') == 1;
}

sub render_text {
  my $self = shift;
  return join '', map $self->_render_text($_, 'Marker', { headers => [ 'id' ], values => [ $_->{'drawing_id'} ] }), @{$self->features};
}

sub features {
  my ($self, $logic_name) = @_;
  my $slice = $self->{'container'};
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
  
  foreach my $f (@features) {
    my $ms  = $f->marker->display_MarkerSynonym;
    my $id  = $ms ? $ms->name : '';
      ($id) = grep $_ ne '-', map $_->name, @{$f->marker->get_all_MarkerSynonyms || []} if $id eq '-' || $id eq '';
    
    $f->{'drawing_id'} = $id;
  }
  
  return [ sort { $a->seq_region_start <=> $b->seq_region_start } @features ];
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
