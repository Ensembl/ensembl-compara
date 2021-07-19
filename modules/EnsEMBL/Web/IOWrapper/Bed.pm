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

package EnsEMBL::Web::IOWrapper::Bed;

### Wrapper for Bio::EnsEMBL::IO::Parser::Bed, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(first);

use parent qw(EnsEMBL::Web::IOWrapper);

sub validate {
  ### Wrapper around the parser's validation method
  ### We have to do extra for BED because it has alternative columns
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $format  = $self->hub->param('format');
  my $errors  = $self->parser->validate($format);

  if (keys %$errors) {
    my $message = 'File did not validate as format '.$self->format;
    $message .= '<ul>';
    foreach (sort keys %$errors) {
      $message .= sprintf('<li>%s: %s</li>', $_, $errors->{$_});
    }
    $message .= '</ul>';
    return $message;
  }
  else {
    my $format_name = $self->parser->format->name;
    $format = $format_name if $format_name;
    $self->{'format'}       = $format;
    $self->{'column_count'} = $self->parser->get_column_count;
    ## Update session record accordingly
    my $record = $session->get_record_data({'type' => 'upload', 'code' => $self->file->code});
    if (keys %$record) {
      $record->{'format'}       = $self->{'format'};
      $record->{'column_count'} = $self->{'column_count'};
      $session->set_record_data($record);
    }
    return undef;
  }

}


sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;
  my $slice_start = $slice->start;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;

  ## Allow for seq region synonyms
  my $seq_region_names = [$slice->seq_region_name];
  if ($metadata->{'use_synonyms'}) {
    push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
  }

  return unless first {$seqname eq $_} @$seq_region_names;

  my $start_coord = $self->parser->get_start;
  my $end_coord   = $self->parser->get_end;
  my $drawn_start = $start_coord - $slice_start + 1;
  my $drawn_end   = $end_coord - $slice_start + 1;

  return if $drawn_end < 0 || $drawn_start > $slice->length;


  $metadata         ||= {};
  my $strand          = $self->parser->get_strand || 0;
  my $score           = $self->parser->get_score;
  if ($score =~ /inf/i) {
    $score = uc($score);
  }
  my $colour_params   = {
    'metadata'  => $metadata, 
    'strand'    => $strand, 
    'score'     => $score,
    'itemRgb'   => $self->parser->get_itemRgb,
  };
  my $colour = $self->set_colour($colour_params);

  my $label = $self->parser->can('get_name') ? $self->parser->get_name : '';
  my $id    = $self->parser->get_id || $label;

  my $drawn_strand = $metadata->{'drawn_strand'} || $strand;
  ## Constrain click coords by viewport, so we don't fetch unnecessary data in zmenu
  my $click_start = $start_coord < $slice_start ? $slice_start : $start_coord;
  my $click_end   = $end_coord > $slice->end ? $slice->end : $end_coord;
  my $href;
  unless ($metadata->{'omit_feature_links'}) {
    my $custom_fields = {};
    if ($metadata->{'custom_fields'}) {
      foreach (@{$metadata->{'custom_fields'}}) {
        my $method  = 'get_'.$_;
        my $value   = $self->parser->$method;
        $custom_fields->{$_} = $value if defined($value);
      }
    }
    $href = $self->href({
                          'action'        => $metadata->{'action'},
                          'id'            => $id,
                          'url'           => $metadata->{'url'},
                          'seq_region'    => $seqname,
                          'start'         => $click_start,
                          'end'           => $click_end,
                          'strand'        => $drawn_strand,
                          'zmenu_extras'  => $metadata->{'zmenu_extras'},
                          'custom_fields' => $custom_fields,
                          });
  }

  ## Don't set start and end yet, as drawing code and zmenu want
  ## different values
  my $feature = {
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $label,
    'colour'        => $colour,
    'href'          => $href,
  };

  ## We may need to deal with BigBed or bigGenePred AutoSQL fields
  my $column_map = $self->parser->{'column_map'} || {};

  if ($metadata->{'display'} eq 'text') {
    ## Want the real coordinates, not relative to the slice
    $feature->{'start'} = $start_coord;
    $feature->{'end'}   = $end_coord;
    ## This needs to deal with BigBed AutoSQL fields, so it's a bit complex
    if (keys %$column_map) {
      $feature->{'extra'} = [];
      ## Synonyms for standard columns used in zmenus
      my %skipped = (
        'chrom'       => 1,
        'chromStart'  => 1,
        'chromEnd'    => 1,
        'score'       => 1,
      );
      my %lookup = reverse %$column_map;
      for (sort {$a <=> $b} keys %lookup) {
        my $field   = $lookup{$_};
        next if ($feature->{$field} || $skipped{$field});
        my $method  = "get_$field";
        my $value   = $self->parser->$method;
        ## Prettify common array values
        if ($method eq 'get_blockSizes' || $method eq 'get_blockStarts' || $method eq 'chromStarts') {
          $value = join(', ', @$value);
        }
        ## N.B. don't try to parse camelcase names - it's just a minefield!
        push @{$feature->{'extra'}}, {
          'name'  => ucfirst($field),
          'value' => $value, 
        };
      }

    }
    elsif ($self->parser->get_blockCount) {
      $feature->{'extra'} = [
        {'name' => 'Block count', 'value' => $self->parser->get_blockCount},
        {'name' => 'Block sizes', 'value' => join(', ', @{$self->parser->get_blockSizes||[]})},
        {'name' => 'Block starts', 'value' => join(', ', @{$self->parser->get_blockStarts||[]})},
        {'name' => 'Thick start', 'value' => $self->parser->get_thickStart},
        {'name' => 'Thick end', 'value' => $self->parser->get_thickEnd},
      ];
    }
    ## TODO Put RNAcentral link here
  }
  else {
    $feature->{'start'}         = $drawn_start;
    $feature->{'end'}           = $drawn_end;
    $feature->{'structure'}     = $self->create_structure($feature, $start_coord, $end_coord, $slice_start);
    $feature->{'join_colour'}   = $metadata->{'join_colour'} || $colour;
    $feature->{'label_colour'}  = $metadata->{'label_colour'} || $colour;
    if ($column_map->{'name2'}) {
      $feature->{'gene'}          = $self->parser->get_name2;
    }
  }
  return $feature;
}

sub create_structure {
  my ($self, $feature, $start_coord, $end_coord, $slice_start) = @_;

  my $thick_start   = $self->parser->get_thickStart;
  my $thick_end     = $self->parser->get_thickEnd;
  my $block_count   = $self->parser->get_blockCount;

  return unless ($block_count || ($thick_start && $thick_end));

  my $structure = [];
  my ($has_utr5, $has_utr3);

  ## First, create the blocks
  if ($self->parser->get_blockCount) {
    my @block_starts  = @{$self->parser->get_blockStarts};
    my @block_lengths = @{$self->parser->get_blockSizes};
    my $offset        = $start_coord - $slice_start + 1;

    foreach(0..($self->parser->get_blockCount - 1)) {
      my $start   = shift @block_starts; 
      ## Adjust to be relative to slice
      $start      = $start + $offset;
      my $length  = shift @block_lengths;
      ## Adjust coordinates here to accommodate drawing code without 
      ## altering zmenu content
      my $end     = $start + $length - 1;

      push @$structure, {'start' => $start, 'end' => $end};
    }
  }
  else {
    ## Single-block feature
    $structure = [{'start' => $feature->{'start'}, 'end' => $feature->{'end'}}];
  }

  ## Fix for non-intuitive configuration of non-coding transcripts
  if ($thick_start == $thick_end) {
    $thick_start  = 0;
    $thick_end    = 0;
  }
  else {
    ## Do we have any UTR?
    $has_utr5 = 1 if ($thick_start && $thick_start > $start_coord);
    $has_utr3 = 1 if ($thick_end && $thick_end < $end_coord);
    ## Adjust to make relative to slice 
    $thick_start -= ($slice_start - 1);
    $thick_end   -= ($slice_start - 1);
  }

  ## Does this feature have any coding sequence?
  my $has_coding = $thick_start || $thick_end ? 1 : 0;

  foreach my $block (@$structure) {
    my $start = $block->{'start'};
    my $end   = $block->{'end'};

    if (!$has_coding) {
      $block->{'non_coding'} = 1; 
    }
    else {
      if ($thick_start && $thick_start > $start) {## 5' UTR
        if ($thick_start > $end) {
          $block->{'non_coding'} = 1; 
        }
        elsif ($has_utr5) {
          $block->{'utr_5'} = $thick_start;
        }
      }
      if ($thick_end && $thick_end < $end) { ## 3' UTR
        if ($thick_end < $start) {
          $block->{'non_coding'} = 1; 
        }
        elsif ($has_utr3) {
          $block->{'utr_3'} = $thick_end; 
        }
      }
    }
  }

  return $structure;
}

1;
