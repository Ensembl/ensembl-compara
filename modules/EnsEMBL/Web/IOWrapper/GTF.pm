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

package EnsEMBL::Web::IOWrapper::GTF;

### Wrapper for Bio::EnsEMBL::IO::Parser::GTF, which builds
### simple hash features from a GFF2 or GFF file, suitable 
### for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::IOWrapper::GXF);


sub build_feature {
### Parse exons separately from other features
  my ($self, $data, $track_key, $slice) = @_;

  my $attribs       = $self->parser->get_attributes;
  my $transcript_id = $attribs->{'transcript_id'};
  my $type          = $self->parser->get_type;
  my $strand        = $self->parser->get_strand || 0;

  if ($transcript_id && $type ne 'transcript') { ## Feature is part of a transcript!
    if ($data->{$track_key}{'transcript_parts'}{$transcript_id}) {
      push @{$data->{$track_key}{'transcript_parts'}{$transcript_id}}, $self->create_hash($slice, $data->{$track_key}{'metadata'});
    }
    else {
      $data->{$track_key}{'transcript_parts'}{$transcript_id} = [$self->create_hash($slice, $data->{$track_key}{'metadata'})];
    }
  }
  else { ## Single feature - add to track as normal
    if ($type eq 'transcript' && $transcript_id) {
      $data->{$track_key}{'transcripts'}{$transcript_id} = $self->create_hash($slice, $data->{$track_key}{'metadata'});
    }
    else {
      if ($data->{$track_key}{'features'}) {
        push @{$data->{$track_key}{'features'}}, $self->create_hash($slice, $data->{$track_key}{'metadata'});
      }
      else {
        $data->{$track_key}{'features'} = [$self->create_hash($slice, $data->{$track_key}{'metadata'})];
      }
    }
  }
}

sub post_process {
### Reassemble sub-features back into features
  my ($self, $data) = @_;
  
  while (my ($track_key, $content) = each (%$data)) {
    while (my ($transcript_id, $segments) = each (%{$content->{'transcript_parts'}})) {

      my $no_of_segments = scalar(@{$segments||[]});
      next unless $no_of_segments;

      my %transcript = %{$data->{$track_key}{'transcripts'}{$transcript_id} || $segments->[0]};
      $transcript{'label'}    ||= $transcript{'transcript_name'} || $transcript{'transcript_id'};
      $transcript{'structure'}  = [];

      ## Sort elements: by start then by reverse name, 
      ## so we get UTRs before their corresponding exons/CDS
      my @ordered_segments = sort {
                                    $a->{'start'} <=> $b->{'start'}
                                    || lc($b->{'type'}) cmp lc($a->{'type'})
                                  } @$segments;
      my $args = {'seen' => {}, 'no_separate_transcript' => 1};   
      
      ## Now turn exons into internal structure
      foreach (@ordered_segments) {
        ($args, %transcript) = $self->add_to_transcript($_, $args, %transcript);
      }

      if ($data->{$track_key}{'features'}) {
        push @{$data->{$track_key}{'features'}}, \%transcript; 
      }
      else {
        $data->{$track_key}{'features'} = [\%transcript]; 
      }

      delete $data->{$track_key}{'transcripts'}{$transcript_id};
    }

    ## Now add any lone transcripts (with no exons) to the feature array
    $data->{$track_key}{'features'} ||= [];
    push @{$data->{$track_key}{'features'}}, values %{$data->{$track_key}{'transcripts'}||{}};

    ## Transcripts will be out of order, owing to being stored in hash
    ## Sort by start coordinate, then reverse length (i.e. longest first)
    my @sorted_features = sort {
                                  $a->{'seq_region'} cmp $b->{'seq_region'}
                                  || $a->{'start'} <=> $b->{'start'}
                                  || $b->{'end'} <=> $a->{'end'}
                                  } @{$data->{$track_key}{'features'}||[]};
    $data->{$track_key}{'features'} = \@sorted_features;
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

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;
  return if $seqname ne $slice->seq_region_name;
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start + 1;
  my $end           = $feature_end - $slice->start + 1;
  return if $end < 0 || $start > $slice->length;

  ## Only set colour if we have something in metadata, otherwise
  ## we will override the default colour in the drawing code
  my $strand  = $self->parser->get_strand || 0;
  my $score   = $self->parser->get_score;

  $metadata ||= {};

  my $colour_params  = {
                        'metadata'  => $metadata,
                        'strand'    => $strand,
                        'score'     => $score,
                        };
  my $colour = $self->set_colour($colour_params);

  ## Try to find an ID for this feature
  my $attributes = $self->parser->get_attributes;

  my $id = $attributes->{'transcript_name'} || $attributes->{'transcript_id'} 
            || $attributes->{'gene_name'} || $attributes->{'gene_id'};

  ## Not a transcript, so just grab a likely attribute
  if (!$id) {
    while (my ($k, $v) = each (%$attributes)) {
      if ($k =~ /id$/i) {
        $id = $v;
        last;
      }
    }
  }
  my $name = $attributes->{'extname'} || $id;

  my $feature = {
                  'seq_region'    => $seqname,
                  'strand'        => $strand,
                  'score'         => $score,
                  'colour'        => $colour, 
                  'join_colour'   => $metadata->{'join_colour'} || $colour,
                  'label_colour'  => $metadata->{'label_colour'} || $colour,
                  'label'         => $name,
                };


  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;

    ## For zmenus, build array of extra attributes
    $feature->{'extra'} = $self->_build_extras($attributes);
  }
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
    my $click_params = {
                        'id'          => $id,
                        'url'         => $metadata->{'url'},
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        'strand'      => $strand,
                        };
    if ($attributes->{'exon_number'}) {
      $click_params->{'exon'} = $attributes->{'exon_number'};
    }
    $feature->{'href'} = $self->href($click_params);

    ## Needed by Location/Genome, for image+table from one parser pass
    if ($metadata->{'include_attribs'}) {
      $feature->{'extra'} = $self->_build_extras($attributes);
    }
  }

  return $feature;
}

sub _build_extras {
  my ($self, $attributes, $as_hash) = @_;

  my $extra = [];
  push @$extra, {'name' => 'Source',        'value' => $self->parser->get_source};
  push @$extra, {'name' => 'Feature type',  'value' => $self->parser->get_type};
  if ($attributes->{'gene_id'}) {
    push @$extra, {'name' => 'Gene ID', 'value' => $attributes->{'gene_id'}};
    delete $attributes->{'gene_id'};
    if ($attributes->{'gene_name'}) {
      push @$extra, {'name' => 'Gene name', 'value' => $attributes->{'gene_name'}};
      delete $attributes->{'gene_name'};
    }
    if ($attributes->{'gene_biotype'}) {
      push @$extra, {'name' => 'Gene biotype', 'value' => $attributes->{'gene_biotype'}};
      delete $attributes->{'gene_biotype'};
    }
  }
  if ($attributes->{'transcript_id'}) {
    push @$extra, {'name' => 'Transcript ID', 'value' => $attributes->{'transcript_id'}};
    delete $attributes->{'transcript_id'};
    if ($attributes->{'transcript_name'}) {
      push @$extra, {'name' => 'Transcript name', 'value' => $attributes->{'transcript_name'}};
      delete $attributes->{'transcript_name'};
    }
  }
  foreach (sort keys %$attributes) {
    (my $name = $_) =~ s/_/ /g;
    push @$extra, {'name' => ucfirst($name), 'value' => $attributes->{$_}};
  }

  return $extra;
}

1;
