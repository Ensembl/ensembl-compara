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

package EnsEMBL::Web::TextSequence::Annotation::Codons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self,$config,$slice_data,$markup) = @_;

  my $slice       = $slice_data->{'slice'};
  my @transcripts = map @{$_->get_all_Transcripts}, @{$slice->get_all_Genes};
  my ($slice_start, $slice_length) = map $slice->$_, qw(start length);
  
  if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    foreach my $t (grep { ($_->coding_region_start||0) < ($slice_length||0) && ($_->coding_region_end||0) > 0 } @transcripts) {
      next unless defined $t->translation;
          
      my @codons;
          
      # FIXME: all_end_codon_mappings sometimes returns $_ as undefined for small subslices. This eval stops the error, but the codon will still be missing.
      # Awaiting a fix from the compara team.
      eval {
        push @codons, map {{ start => $_->start, end => $_->end, label => 'START' }} @{$t->translation->all_start_codon_mappings || []}; # START codons
        push @codons, map {{ start => $_->start, end => $_->end, label => 'STOP'  }} @{$t->translation->all_end_codon_mappings   || []}; # STOP codons
      };    
      
      my $id = $t->stable_id;
    
      foreach my $c (@codons) {
        my ($start, $end) = ($c->{'start'}, $c->{'end'});
          
        # FIXME: Temporary hack until compara team can sort this out
        $start = $start - 2 * ($slice_start - 1);
        $end   = $end   - 2 * ($slice_start - 1);
            
        next if $end < 1 || $start > $slice_length;
        
        $start = 1 unless $start > 0;
        $end   = $slice_length unless $end < $slice_length;
            
        $markup->{'codons'}{$_}{'label'} .= ($markup->{'codons'}{$_}{'label'} ? "\n" : '') . "$c->{'label'}($id)" for $start-1..$end-1;
      }     
    } 
  } else { # Normal Slice
    foreach my $t (grep { $_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
      my ($start, $stop, $id, $strand) = ($t->coding_region_start, $t->coding_region_end, $t->stable_id, $t->strand);
          
      # START codons
      if ($start >= 1) {
        my $label = ($strand == 1 ? 'START' : 'STOP') . "($id)";
        $markup->{'codons'}{$_}{'label'} .= ($markup->{'codons'}{$_}{'label'} ? "\n" : '') . $label for $start-1..$start+1;
      }     
      
      # STOP codons
      if ($stop <= $slice_length) {
        my $label = ($strand == 1 ? 'STOP' : 'START') . "($id)";
        $markup->{'codons'}{$_}{'label'} .= ($markup->{'codons'}{$_}{'label'} ? "\n" : '') . $label for $stop-3..$stop-1;
      }
    }
  }
}

1;
