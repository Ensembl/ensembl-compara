#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::FilterDuplicates->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This analysis/RunnableDB is designed to run after all GenomicAlignBlock entries for a 
specific MethodLinkSpeciesSet has been completed and filters out all duplicate entries
which can result from jobs being rerun or from regions of overlapping chunks generating
the same HSP hits.  It takes as input (on the input_id string) 

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;
our @ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'max_set_bps'}              = 10000000; #10Mbase
  $self->{'genome_db_id'}             = 0;  # 'gdb'
  $self->{'chunkset_id'}              = 0;
  $self->{'store_seq'}                = 0;
  $self->{'overlap'}                  = 1000;
  $self->{'chunk_size'}               = 1000000;
  $self->{'region'}                   = undef;
  $self->{'analysis_job'}             = undef;
  $self->debug(1);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("No genome_db specified") unless defined($self->{'genome_db_id'});
  $self->print_params;
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
    
  return 1;
}


sub run
{
  my $self = shift;
  $self->filter_duplicates;
  return 1;
}


sub write_output 
{  
  my $self = shift;

  my $output_id = $self->input_id;

  print("output_id = $output_id\n");
  $self->input_id($output_id);                    
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  $self->{'method_link_species_set_id'} = $params->{'method_link_species_set_id'} 
    if(defined($params->{'method_link_species_set_id'}));

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   method_link_species_set_id : ", $self->{'method_link_species_set_id'},"\n");
}


sub filter_duplicates {
  my $self = shift;

  my $segment_length = 1000000;
  $self->{'overlap_count'}   = 0;
  $self->{'identical_count'} = 0;
  $self->{'gab_count'} = 0;
  $self->{'truncate_count'} = 0;
  $self->{'not_truncate_count'} = 0;

  $self->{'dups_hash'} = {};
  $self->{'overlap_hash'} = {};
    
  my $mlss = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->{'method_link_species_set_id'});
  my ($gdb1, $gdb2) = @{$mlss->species_set};
  if($gdb1->dbID > $gdb2->dbID) {
    my $tmp = $gdb1; $gdb1=$gdb2; $gdb2=$tmp;
  }
  
  my $GAB_DBA = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  my $dnafrag_list = $self->{'comparaDBA'}->get_DnaFragAdaptor->fetch_all_by_GenomeDB_region($gdb2);
  foreach my $dnafrag (@$dnafrag_list) {
    my $region_start = 0;
    printf("dnafrag (%d)%s:%s len=%d\n", $dnafrag->dbID, $dnafrag->coord_system_name, $dnafrag->name, $dnafrag->length);
    while($region_start <= $dnafrag->length) {
      my $region_end = $region_start + 100000;
      #my $region_end = $region_start + $segment_length;
      my $genomic_align_block_list = $GAB_DBA->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                           $mlss, $dnafrag, $region_start, $region_end);

      printf("dnafrag %s %s %d:%d has %d GABs\n", $dnafrag->coord_system_name, $dnafrag->name, 
             $region_start, $region_end, scalar(@$genomic_align_block_list));
             
      $self->process_genomic_align_block_list($genomic_align_block_list, $region_start, $region_end);          

      $region_start += 1000000;
      #$region_start += $segment_length;
    }
  }
  
  printf("found %d equal GAB pairs\n", scalar(keys(%{$self->{'dups_hash'}})));
  printf("found %d overlapping GAB pairs\n", scalar(keys(%{$self->{'overlap_hash'}})));
  printf("found %d overlapping GABs\n", $self->{'overlap_count'});
  printf("%d GABs loadled\n", $self->{'gab_count'});
  printf("%d TRUNCATE gabs\n", $self->{'truncate_count'});
  printf("%d not TRUNCATE gabs\n", $self->{'not_truncate_count'});
}


sub sort_alignments{
  my $a_ref = $a->reference_genomic_align;
  my ($a_other) = @{$a->get_all_non_reference_genomic_aligns};
  my $b_ref = $b->reference_genomic_align;
  my ($b_other) = @{$b->get_all_non_reference_genomic_aligns};

  return 
    ($a_other->dnafrag_id <=> $b_other->dnafrag_id) ||
    ($a_ref->dnafrag_strand <=> $b_ref->dnafrag_strand) ||
    ($a_other->dnafrag_strand <=> $b_other->dnafrag_strand) ||
    ($a_ref->dnafrag_start <=> $b_ref->dnafrag_start) ||
    ($a_ref->dnafrag_end <=> $b_ref->dnafrag_end) ||
    ($a_other->dnafrag_start <=> $b_other->dnafrag_start) ||
    ($a_other->dnafrag_end <=> $b_other->dnafrag_end) ||
    ($a->score <=> $b->score);
}


sub process_genomic_align_block_list {
  my $self = shift;
  my $genomic_align_block_list = shift;
  my $region_start = shift;
  my $region_end = shift;
  
  return unless(scalar(@$genomic_align_block_list));
  
  my @sorted_GABs = sort sort_alignments @$genomic_align_block_list;
  #print(scalar(@sorted_GABs), " sorted GABs\n");
  $self->{'gab_count'} += scalar(@sorted_GABs);

  while(scalar(@sorted_GABs)) {
    my $gab = shift @sorted_GABs;
    #if($self->debug) { print("ref: "); print_gab($gab);}
    foreach my $next_gab (@sorted_GABs) {
      last if($next_gab->reference_genomic_align->dnafrag_start > 
              $gab->reference_genomic_align->dnafrag_end);

      #if($self->debug) { print("next: "); print_gab($next_gab); }
    
      if(genomic_align_blocks_identical($gab, $next_gab)) {
        #printf("identical GABs %d %d\n", $next_gab->dbID, $gab->dbID);# if($self->debug);
        if($gab->dbID < $next_gab->dbID) {
           my $key = $gab->dbID . $next_gab->dbID;
           $self->{'dups_hash'}->{$key} = $key;
        } else {
           my $key = $next_gab->dbID. $gab->dbID;
           $self->{'dups_hash'}->{$key} = $key;
        }
        $self->{'identical_count'}++;
      }
      elsif(genomic_align_blocks_overlap($gab, $next_gab)) {
        $self->process_overlap_for_chunk_edge_truncation($gab, $next_gab, $region_start, $region_end);

        $self->{'overlap_count'}++;
        if($gab->dbID < $next_gab->dbID) {
           my $key = $gab->dbID . $next_gab->dbID;
           $self->{'overlap_hash'}->{$key} = $key;
        } else {
           my $key = $next_gab->dbID. $gab->dbID;
           $self->{'overlap_hash'}->{$key} = $key;
        }
      } 
    }
  }
  #printf("found %d identical, %d overlapping GABs\n", $self->{'identical_count'}, $self->{'overlap_count'});
  #printf("found %d identical, %d overlapping GABs\n",
  #         scalar(keys(%{$self->{'dups_hash'}})), scalar(keys(%{$self->{'overlap_hash'}})));
  
}


sub print_gab {
  my $gab = shift;
  
  my ($gab_1, $gab_2) = @{$gab->genomic_align_array};
  printf(" id(%d)  %s:(%d)%d-%d    %s:(%d)%d-%d  score=%d\n", 
         $gab->dbID,
         $gab_1->dnafrag->name, $gab_1->dnafrag_strand, $gab_1->dnafrag_start, $gab_1->dnafrag_end,
         $gab_2->dnafrag->name, $gab_2->dnafrag_strand, $gab_2->dnafrag_start, $gab_2->dnafrag_end,
         $gab->score);
}


sub genomic_align_blocks_identical {
  my ($gab1, $gab2) = @_;
  
  my ($gab1_1, $gab1_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab1->genomic_align_array};
  my ($gab2_1, $gab2_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab2->genomic_align_array};
  
  return 0 if(($gab1_1->dnafrag_id != $gab2_1->dnafrag_id) or ($gab1_2->dnafrag_id != $gab2_2->dnafrag_id));
  return 0 if(($gab1_1->dnafrag_strand != $gab2_1->dnafrag_strand) or ($gab1_2->dnafrag_strand != $gab2_2->dnafrag_strand));

  return 0 if(($gab1_1->dnafrag_start != $gab2_1->dnafrag_start) or ($gab1_1->dnafrag_end != $gab2_1->dnafrag_end));  
  return 0 if(($gab1_2->dnafrag_start != $gab2_2->dnafrag_start) or ($gab1_2->dnafrag_end != $gab2_2->dnafrag_end));  

  return 0 if($gab1->score != $gab2->score);

  return 0 if($gab1_1->cigar_line ne $gab2_1->cigar_line);  
  return 0 if($gab1_2->cigar_line ne $gab2_2->cigar_line);
  
  return 1;
}


sub genomic_align_blocks_overlap {
  my ($gab1, $gab2) = @_;
  
  my ($gab1_1, $gab1_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab1->genomic_align_array};
  my ($gab2_1, $gab2_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab2->genomic_align_array};
  
  return 0 if(($gab1_1->dnafrag_id != $gab2_1->dnafrag_id) or ($gab1_2->dnafrag_id != $gab2_2->dnafrag_id));
  return 0 if(($gab1_1->dnafrag_strand != $gab2_1->dnafrag_strand) or ($gab1_2->dnafrag_strand != $gab2_2->dnafrag_strand));

  return 0 if(($gab1_1->dnafrag_end < $gab2_1->dnafrag_start) or ($gab1_1->dnafrag_start > $gab2_1->dnafrag_end));  
  return 0 if(($gab1_2->dnafrag_end < $gab2_2->dnafrag_start) or ($gab1_2->dnafrag_start > $gab2_2->dnafrag_end));  
  
  return 1;
}


sub process_overlap_for_chunk_edge_truncation {
  my ($self, $gab1, $gab2, $region_start, $region_end) = @_;
 
  my $keeper = undef;
  
  my $aligns_1_1 = $gab1->reference_genomic_align;
  my $aligns_1_2 = $gab1->get_all_non_reference_genomic_aligns->[0];
  my $aligns_2_1 = $gab2->reference_genomic_align;
  my $aligns_2_2 = $gab2->get_all_non_reference_genomic_aligns->[0];
    
  #first test if this overlapping pair is such that one of them crosses
  #one of the region boundaries and the other one does not
  #Processings is done such that we walk through the overlap regions of 
  #one genome, which in the GAB is the 'reference' so only need to test the
  #reference for region_edge artifacts.
  #IF both genomes are chunked and overlapped, then this needs to be run twice
  #1) with genome1 on the genome1 chunking regions
  #2) with genome2 on the genome2 chunking regions
  return undef 
    unless((($aligns_1_1->dnafrag_start < $region_start) and
            ($aligns_2_1->dnafrag_start >= $region_start))
           or
           (($aligns_1_1->dnafrag_start >= $region_start) and
            ($aligns_2_1->dnafrag_start < $region_start))
           or
           (($aligns_1_1->dnafrag_end > $region_end) and
            ($aligns_2_1->dnafrag_end <= $region_end))
           or
           (($aligns_1_1->dnafrag_end <= $region_end) and
            ($aligns_2_1->dnafrag_end > $region_end)));
            

  if(
      (($aligns_1_1->dnafrag_strand == $aligns_1_2->dnafrag_strand)
        and(
          (($aligns_1_1->dnafrag_start == $aligns_2_1->dnafrag_start) and 
           ($aligns_1_2->dnafrag_start == $aligns_2_2->dnafrag_start)) 
          or
          (($aligns_1_1->dnafrag_end   == $aligns_2_1->dnafrag_end) and 
           ($aligns_1_2->dnafrag_end   == $aligns_2_2->dnafrag_end))
        )
      ) 
      or
      (($aligns_1_1->dnafrag_strand != $aligns_1_2->dnafrag_strand)
        and(
          (($aligns_1_1->dnafrag_start == $aligns_2_1->dnafrag_start) and 
           ($aligns_1_2->dnafrag_end   == $aligns_2_2->dnafrag_end)) 
          or
          (($aligns_1_1->dnafrag_end   == $aligns_2_1->dnafrag_end) and 
           ($aligns_1_2->dnafrag_start == $aligns_2_2->dnafrag_start))
        )
      ) 
    )   
  {
    printf("TRUNCATE GABs %d %d\n", $gab2->dbID, $gab1->dbID);
    if($gab1->score > $gab2->score) {
      $keeper = $gab1;
      print("      "); print_gab($gab1);
      print("  DEL "); print_gab($gab2);
    } else {
      $keeper = $gab2;
      print("  DEL "); print_gab($gab1);
      print("      "); print_gab($gab2);
    }
    
    $self->{'truncate_count'}++;  
  }
  else {
    printf("overlaping GABs %d %d - not truncate\n", $gab2->dbID, $gab1->dbID);
    print("      "); print_gab($gab1);
    print("      "); print_gab($gab2);
    $self->{'not_truncate_count'}++;
  }
  
}





1;
