=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $self = shift;
  my ($valid, $format, $col_count) = $self->parser->validate($self->hub->param('format'));

  if ($valid) {
    $self->{'format'}       = $format;
    $self->{'column_count'} = $col_count;
    ## Update session record accordingly
    my $record = $self->hub->session->get_data('type' => 'upload', 'code' => $self->file->code);
    if ($record) {
      $record->{'format'}       = $format;
      $record->{'column_count'} = $col_count;
      $self->hub->session->set_data(%$record);
    }
  }

  return $valid ? undef : 'File did not validate as format '.$format;
}


sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;

  ## Allow for seq region synonyms
  my $seq_region_names = [$slice->seq_region_name];
  if ($metadata->{'use_synonyms'}) {
    push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
  }

  return unless first {$seqname eq $_} @$seq_region_names;

  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start;
  my $end           = $feature_end - $slice->start;
  return if $end < 0 || $start > $slice->length;


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

  my $id = $self->parser->can('get_id') ? $self->parser->get_id
            : $self->parser->can('get_name') ? $self->parser->get_name : undef;

  my $href = $self->href({
                        'id'          => $id,
                        'url'         => $metadata->{'url'},
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        'strand'      => $strand,
                        }) unless $metadata->{'omit_feature_links'};

  ## Don't set start and end yet, as drawing code and zmenu want
  ## different values
  my $feature = {
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $self->parser->get_name,
    'colour'        => $colour,
    'href'          => $href,
  };

  if ($metadata->{'display'} eq 'text') {
    ## Want the real coordinates, not relative to the slice
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
    ## This needs to deal with BigBed AutoSQL fields, so it's a bit complex
    my $column_map      = $self->parser->{'column_map'};
    if ($column_map) {
      $feature->{'extra'} = [];
      ## Skip standard columns used in zmenus
      my %skipped = (
                    'chrom'       => 1,
                    'chromStart'  => 1,
                    'chromEnd'    => 1,
                    'score'       => 1,
                    );
      my %lookup = reverse %$column_map;
      for (sort {$a <=> $b} keys %lookup) {
        my $field   = $lookup{$_};
        next if $skipped{$field};
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
    $feature->{'start'}         = $start;
    $feature->{'end'}           = $end;
    $feature->{'structure'}     = $self->create_structure($feature_start, $slice->start);
    $feature->{'join_colour'}   = $metadata->{'join_colour'} || $colour;
    $feature->{'label_colour'}  = $metadata->{'label_colour'} || $colour;
  }
  return $feature;
}

sub create_structure {
  my ($self, $feature_start, $slice_start) = @_;

  if (!$self->parser->get_blockCount || !$self->parser->get_blockSizes 
          || !$self->parser->get_blockStarts) {
    return undef; 
  } 

  my $structure = [];

  my @block_starts  = @{$self->parser->get_blockStarts};
  my @block_lengths = @{$self->parser->get_blockSizes};
  my $thick_start   = $self->parser->get_thickStart;
  my $thick_end     = $self->parser->get_thickEnd;

  ## Fix for non-intuitive configuration of non-coding transcripts
  if ($thick_start == $thick_end) {
    $thick_start  = 0;
    $thick_end    = 0;
  }
  else {
    ## Adjust to make relative to slice (and compensate for BED coords)
    $thick_start -= ($slice_start - 1);
    $thick_end   -= $slice_start;
  }

  ## Does this feature have _any_ coding sequence?
  my $has_coding = $thick_start || $thick_end ? 1 : 0;

  foreach(0..($self->parser->get_blockCount - 1)) {
    my $start   = shift @block_starts;
    ## Adjust to be relative to slice and compensate for BED format
    my $offset  = $feature_start - $slice_start;
    $start      = $start + $offset + 1;
    my $length  = shift @block_lengths;
    my $end     = $start + $length - 1;

    my $block = {'start' => $start, 'end' => $end};
    
    if (!$has_coding) {
      $block->{'non_coding'} = 1; 
    }
    else {
      if ($thick_start && $thick_start > $start) {## 5' UTR
        if ($thick_start > $end) {
          $block->{'non_coding'} = 1; 
        }
        else {
          $block->{'utr_5'} = $thick_start - $start;
        }
      }
      elsif ($thick_end && $thick_end < $end) { ## 3' UTR
        if ($thick_end < $start) {
          $block->{'non_coding'} = 1; 
        }
        else {
          $block->{'utr_3'} = $thick_end - $start;
        }
      }
    }
    push @$structure, $block;
  }

  return $structure;
}

1;
