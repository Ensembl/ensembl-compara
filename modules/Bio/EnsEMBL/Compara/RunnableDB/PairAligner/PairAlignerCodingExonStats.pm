=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module populuates the temporary table 'statistics' with coding exon statistics (matches, mis-matches, insertions and uncovered)

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my ($self) = @_;

  #These lines are only necessary when running as not part of the PairAligner pipeline
  if ($self->param('registry_dbs')) {
      my $reg = "Bio::EnsEMBL::Registry";
      my $registry_dbs =$self->param('registry_dbs');
      
      for(my $r_ind=0; $r_ind<scalar(@$registry_dbs); $r_ind++) {
          $reg->load_registry_from_db( %{ $registry_dbs->[$r_ind] } );
      }
  }

  return 1;
}

=head2 run

=cut

sub run {
  my $self = shift;

  my $compara_dba;
  if ($self->param('db_conn')) {
      #These lines are only necessary when running as not part of the PairAligner pipeline
      my $compara_url = $self->param('db_conn');
      $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
  } else {
      $compara_dba = $self->compara_dba;
  }

  my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
  my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;
  my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

  my $mlss_id = $self->param('mlss_id');
  my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

  my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($self->param_required('dnafrag_id'));
  $self->param('genome_db', $dnafrag->genome_db);

  my $coding_exons = [];
  $dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {

  my $slice_adaptor = $dnafrag->genome_db->db_adaptor->get_SliceAdaptor();

  #Necessary to get unique bits of Y
  my $slices = $slice_adaptor->fetch_by_region_unique('toplevel', $dnafrag->name);
  die "No slices for dnafrag ".$dnafrag->name unless @$slices;

  foreach my $slice (@$slices) {
      get_coding_exon_regions($slice, $coding_exons);
  }

  });

  print "coding_exons " . @$coding_exons . "\n" if($self->debug);
  
  my $totals;
  my $uncovered = 0;
  foreach my $coding_exon (@$coding_exons) {
      my ($start, $end) = @$coding_exon;

      my $coding_exon_length = ($end - $start + 1);
      print "start=$start end=$end length=$coding_exon_length\n" if($self->debug);

      #Store the total coding_exon_length
      $totals->{'coding_exon_length'} += $coding_exon_length;

      #restricted genomic_align_blocks (use dnafrag so I can send over start and end instead of creating a new slice)
      my $gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $dnafrag, $start, $end, undef, undef, 1);

      if (@$gabs > 1) {
          $gabs = $self->restrict_overlapping_genomic_align_blocks($gabs);
      }

      print "num gabs " . @$gabs . "\n" if($self->debug);

      #Keep track of how much of a coding exon is covered by the reference genomic_align 
      #(in the case where multiple gabs cover a single coding exon with gaps between the blocks)
      my $ref_ga_covering_coding_exon = 0;

      foreach my $gab (@$gabs) {

          #values for this gab
          my $num_matches = 0;
          my $num_mis_matches = 0;
          my $ref_insertions = 0;
          my $non_ref_insertions = 0;
        
          #Total length of this restricted alignment block (include insertions)
          my $align_length = $gab->length;
          print "  align_length=$align_length coding_exon_length=$coding_exon_length\n" if($self->debug);
        
          #reference and non-reference genomic_align
          my $ref_ga = $gab->reference_genomic_align;
          my $non_ref_ga = $gab->get_all_non_reference_genomic_aligns->[0];
          
          #Length of reference genomic_align (in slice coords ie no insertions)
          my $ref_ga_length = ($ref_ga->dnafrag_end - $ref_ga->dnafrag_start + 1);
        
          #Perform xor which will result in matches having a value of zero and mis-matches being non-zero
          my $mask = $ref_ga->aligned_sequence ^ $non_ref_ga->aligned_sequence;
        
          #Count the number of matches ie zero (\x0) values there are
          $num_matches = $mask =~ tr/\x0/\x0/;
        
          #Find number of insertions (ie gaps in the other species)
          $non_ref_insertions = $ref_ga->aligned_sequence =~ tr/-//;
          $ref_insertions = $non_ref_ga->aligned_sequence =~ tr/-//;
        
          #Mismatches must be what is left. Assume we can't have a gap aligning to a gap
          $num_mis_matches = $ref_ga_length - $num_matches - $ref_insertions;

          #check (not necessary?)
          if ($num_mis_matches != ($align_length - $num_matches - $ref_insertions - $non_ref_insertions)) {
              $self->warning("  PROBLEM $num_mis_matches " . ($align_length - $num_matches - $ref_insertions - $non_ref_insertions) . "\n");
          }

          #Remember this is the reference genomic_align has already been restricted to the coding_exon. If the
          #coding exon spans more than one genomic_align, we need to keep track for each genomic_align
          $ref_ga_covering_coding_exon += ($ref_ga->dnafrag_end - $ref_ga->dnafrag_start + 1);
        
          #Store total values
          $totals->{'matches'} += $num_matches;
          $totals->{'mis_matches'} += $num_mis_matches;
          $totals->{'ref_insertions'} += $ref_insertions;
          $totals->{'non_ref_insertions'} += $non_ref_insertions;
          
          #Print values for this coding_exon/genomic_align
          print "  " . $ref_ga->aligned_sequence . "\n" if($self->debug);
          print "  " . $non_ref_ga->aligned_sequence . "\n" if($self->debug);
          
          print "  match=$num_matches mis_match=$num_mis_matches ref_ins=$ref_insertions non_ref_ins=$non_ref_insertions ga_length=$ref_ga_length " if($self->debug);
      }
      
      #The uncovered portion of the coding_exon must be the total length of the coding_exon (in slice coords) minus the portion covered by the restricted reference genomic_aligns (there may be more than one)
      print "uncovered " . ($coding_exon_length-$ref_ga_covering_coding_exon) . "\n\n" if($self->debug);
      $totals->{'uncovered'} += ($coding_exon_length-$ref_ga_covering_coding_exon);
  }

  #Store in param to pass to write_output
  $self->param('totals', $totals);

  return 1;
}

sub write_output {
  my $self = shift;

  print "TOTAL\n" if($self->debug);
  my $totals = $self->param('totals');
  my $mlss_id = $self->param('mlss_id');

  foreach my $key (keys %$totals) {
      print "$key " . $totals->{$key} . "\n" if($self->debug);
  }

  my $sql = "REPLACE INTO statistics (method_link_species_set_id, genome_db_id, dnafrag_id, matches, mis_matches, ref_insertions, non_ref_insertions, uncovered, coding_exon_length) VALUES (?,?,?,?,?,?,?,?,?)";
  my $sth = $self->dbc->prepare($sql);
  $sth->execute($mlss_id, $self->param('genome_db')->dbID, $self->param('dnafrag_id'), $totals->{'matches'},  $totals->{'mis_matches'}, $totals->{'ref_insertions'}, $totals->{'non_ref_insertions'},$totals->{'uncovered'}, $totals->{'coding_exon_length'});
  $sth->finish;

  return 1;

}

sub get_coding_exon_regions {
  my ($this_slice, $regions) = @_;

  return undef if (!$this_slice);

  my $all_coding_exons = [];
  my $all_genes = $this_slice->get_all_Genes_by_type("protein_coding");
  foreach my $this_gene (@$all_genes) {
    my $all_transcripts = $this_gene->get_all_Transcripts();
    foreach my $this_transcript (@$all_transcripts) {
      push(@$all_coding_exons, @{$this_transcript->get_all_translateable_Exons()});
    }
  }
  my $last_start = 0;
  my $last_end = -1;
  foreach my $this_exon (sort {$a->seq_region_start <=> $b->seq_region_start} @$all_coding_exons) {
      #print "exon start " . $this_exon->seq_region_start . " end " . $this_exon->seq_region_end . " last_start $last_start last_end $last_end\n";

    if ($last_end < $this_exon->seq_region_start) {
      if ($last_end > 0) {
        push(@$regions, [$last_start, $last_end]);
      }
      $last_end = $this_exon->seq_region_end;
      $last_start = $this_exon->seq_region_start;
    } elsif ($this_exon->seq_region_end > $last_end) {
      $last_end = $this_exon->seq_region_end;
    }
  }

  #Add final region
  push (@$regions, [$last_start, $last_end]);
}


#
#Need to deal with overlapping blocks:
#Sort gabs by dnafrag_start of the reference 
#Compare current gab ($gab) with previous gab (last_gab)
#If the there is no overlap, add last_gab to array to be returned (restricted_gabs)
#If the end of the current ref_ga is less than the end of previous ref_ga (last_end), current gab must be within prev gab so skip
#If the end of the current ref_ga is greater than the end of previous ref_ga (last_end) and the start is not the same, then restrict
#block 1 from last_start to current ref_ga start. If the start positions are the same, use the longer block 2.
#
sub restrict_overlapping_genomic_align_blocks {
    my ($self, $gabs) = @_;

    my $restricted_gabs;
    my $last_start = 0;
    my $last_end = -1;
    my $last_gab;

    #Sort on ref_ga->dnafrag_start
    foreach my $gab (sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @$gabs) {
        my $ref_ga = $gab->reference_genomic_align;
        my $non_ref_ga = $gab->get_all_non_reference_genomic_aligns->[0];

        print "  ga_start " . $gab->reference_genomic_align->dnafrag_start . " ga_end " . $gab->reference_genomic_align->dnafrag_end . "\n" if ($self->debug);
        #print "  start " . $non_ref_ga->dnafrag_start . " end " . $non_ref_ga->dnafrag_end . " " . $non_ref_ga->dnafrag->name . "\n";

        #my $species1 = $ref_ga->dnafrag->genome_db->_get_unique_name;
        #my $species2 = $non_ref_ga->dnafrag->genome_db->_get_unique_name;
        #print "  " . $species1 . "\t" . $ref_ga->aligned_sequence . "\n";
        #print "  " . $species2 . "\t" . $non_ref_ga->aligned_sequence . "\n";

        if ($last_end < 0) {
            #first time through
            $last_end = $ref_ga->dnafrag_end;
            $last_start = $ref_ga->dnafrag_start;
            $last_gab = $gab;

         #causes problems with chimp chr 6 29997216-29997216 1bp exon
#        } elsif ($ref_ga->dnafrag_start >= $last_end) {
        } elsif ($ref_ga->dnafrag_start > $last_end) {
            #no overlap, no restriction necessary
            print "  OVER No overlap\n" if($self->debug);

            #Store the last_gab
            push @$restricted_gabs, $last_gab;

            #Set 'last' to new gab
            $last_end = $ref_ga->dnafrag_end;
            $last_start = $ref_ga->dnafrag_start;
            $last_gab = $gab;
        } elsif ($ref_ga->dnafrag_end <= $last_end) {
            #block 1 covers block 2, no restriction necessary
            print "  OVER block 2 covered by block 1\n" if($self->debug);

            #Don't set 'last'
        } elsif ($ref_ga->dnafrag_end > $last_end) {
            #block 2 extends beyond block 1
            if ($ref_ga->dnafrag_start > $last_start) {
                #need to restrict end of block 1
                print "  OVER restrict block1 $last_start " . $ref_ga->dnafrag_start . "\n" if($self->debug);
                #$last_end = $ref_ga->dnafrag_start-1;
                #$last_gab = $last_gab->restrict_between_reference_positions($last_start, $last_end);

                my $rest_gab = $last_gab->restrict_between_reference_positions($last_start, $ref_ga->dnafrag_start-1);
                push @$restricted_gabs,$rest_gab;
                #Set 'last' to new gab
                $last_end = $ref_ga->dnafrag_end;
                $last_start = $ref_ga->dnafrag_start;
                $last_gab = $gab;

            } else {
                #block2 start is the same as block 1 start so use block 2
                #Set 'last' to new gab
                print "  OVER block2 is larger than block1 $last_end " . $ref_ga->dnafrag_end . "\n" if($self->debug);
                $last_end = $ref_ga->dnafrag_end;
                $last_start = $ref_ga->dnafrag_start;
                $last_gab = $gab;
            }
        }
    }

    #Need to deal with last gab
    push @$restricted_gabs, $last_gab;

    return $restricted_gabs;
}

1;
