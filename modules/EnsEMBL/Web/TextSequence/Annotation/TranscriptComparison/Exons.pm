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

package EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Exons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Exons);

sub annotate {
  my ($self, $config, $slice_data, $markup, $seq, $ph,$real_sequence) = @_;

  my $sequence = $real_sequence->legacy;
  # XXX should have per-rope switchable Annotation
  if($slice_data->{'type'} && $slice_data->{'type'} eq 'gene') {
    # gene rope
    $markup->{'exons'}{$_}{'type'} = ['gene'] for 0..$#$sequence;
    return;
  }
  # transcript rope
  my $slice = $slice_data->{'slice'};
  my $subslice_start = $config->{'sub_slice_start'};
  my $subslice_end   = $config->{'sub_slice_end'};
  $_-- for grep $_, $subslice_start, $subslice_end;  

  my $start = $slice->start;
  my $length = $slice->length;
  my $strand = $slice->strand;
  my $transcript = $slice_data->{'transcript'};
  my $utr_type = defined $transcript->coding_region_start ? 'eu' : 'exon0'; # if coding_region_start returns unded, exons are marked non-coding
  my $type   = 'exon1';
  my ($crs, $cre, $transcript_start) = map $_ - $start, $transcript->coding_region_start, $transcript->coding_region_end, $transcript->start;
  if ($strand == -1) {
    $_ = $length - $_ - 1, for $crs, $cre;
    ($crs, $cre) = ($cre, $crs);
  }   
      
  $crs--;

  my @exons = @{$transcript->get_all_Exons};
  my ($first_exon, $last_exon) = map $exons[$_]->stable_id, 0, -1;
  for my $exon (@exons) {
    my $exon_id = $exon->stable_id;
    my ($s, $e) = map $_ - $start, $exon->start, $exon->end;

    if ($strand == -1) {
      $_ = $length - $_ - 1, for $s, $e; 
      ($s, $e) = ($e, $s);
    }   
      
    if ($subslice_start || $subslice_end) {    
      if ($e < 0 || $s > $subslice_end) {
        if (!$config->{'exons_only'} && (($exon_id eq $first_exon && $s > $subslice_end) || ($exon_id eq $last_exon && $e < 0))) {
          $sequence->[$_]{'letter'} = '-' for 0..$#$sequence;
        }   
        next;
      }   
      
      $s = 0           if $s < 0;
      $e = $length - 1 if $e >= $length;
    }   
      
    if (!$config->{'exons_only'}) {
      if ($exon_id eq $first_exon && $s) {
        $sequence->[$_]{'letter'} = '-' for 0..$s-1;
      } elsif ($exon_id eq $last_exon) {
        $sequence->[$_]{'letter'} = '-' for $e+1..$#$sequence;
      }   
    }   

    if ($exon->phase == -1) {
      # if the exon phase is -1, it means it starts with a non-coding or
      # utr markup
      $type = $utr_type;

    } elsif ($exon->end_phase == -1) {
      # if end phase is -1, that means it started with a coding region but
      # then somewhere in the middle it became non-coding, so we start with
      # $type = exon1. That location where it became non-coding is coding
      # end region of the transcript however, if we are in a subslice and
      # the coding end region is negative wrt. the subslice coords, the
      # start of this subslice is already non-coding then so in that case
      # we start with utr or non-coding markup
      $type = $cre < 0 ? $utr_type : 'exon1';
    }     
          
    # after having decided the starting markup type - exon1 or utr, we move
    # along the sequence from start to end and add the decided markup type
    # to each base pair but while progressing, when the current coord
    # becomes same as coding exon start or coding exon end, we switch the
    # markup since that point is a transition between coding and noncoding
    for ($s..$e) {
      push @{$markup->{'exons'}{$_}{'type'}}, $type;
      $type = $type eq 'exon1' ? $utr_type : 'exon1' if $_ == $crs || $_ == $cre; # transition point between coding and non-coding

      $markup->{'exons'}{$_}{'id'} .= ($markup->{'exons'}{$_}{'id'} ? "\n" : '') . $exon_id unless $exon_id and $markup->{'exons'}{$_}{'id'} and $markup->{'exons'}{$_}{'id'} =~ /$exon_id/;
    }
  }
  if ($config->{'exons_only'}) {
    $sequence->[$_]{'letter'} = '-' for grep !$markup->{'exons'}{$_}, 0..$#$sequence;
  }

  # finally mark anything left as introns
  for (0..$#$sequence) {
    $markup->{'exons'}{$_}{'type'} ||= ['intron'];
  }
}

1;
