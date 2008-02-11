#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterStack

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::FilterStack->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This is designed to run after Chaining and Netting has been done on a PairWise analysis. It will perform a sort of pseudo softmasking on regions of large numbers of overlapping genomic_aligns on the non-reference species. It marks regions where there are more than "threshold" genomic_aligns and will remove all genomic_aligns and genomic_align_blocks that are entirely within this region. It takes as input (on the input_id string).

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterStack;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

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
  $self->{'threshold'}                  = undef;
  $self->{'method_link_species_set_id'} = undef;
  $self->{'options'} = undef;

  #default height. Only prune stacks that are above this height initially
  $self->{'height'} = 40; 

  $self->debug(0);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->print_params;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  # get DnaCollection
  throw("must specify 'collection_name' to identify DnaCollection") 
    unless(defined($self->{'collection_name'}));
  $self->{'collection'} = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->fetch_by_set_description($self->{'collection_name'});
  throw("unable to find DnaCollection with name : ". $self->{'collection_name'})
    unless(defined($self->{'collection'}));

  return 1;
}


sub run
{
  my $self = shift;
  $self->filter_stack;
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
  # from analysis parameters
  $self->{'method_link'} = $params->{'method_link'} 
    if(defined($params->{'method_link'}));

  $self->{'query_genome_db_id'} = $params->{'query_genome_db_id'} 
    if(defined($params->{'query_genome_db_id'}));

  $self->{'target_genome_db_id'} = $params->{'target_genome_db_id'} 
    if(defined($params->{'target_genome_db_id'}));
  
  $self->{'height'} = $params->{'height'}
    if(defined($params->{'height'}));
  
  # from job input_id
  $self->{'collection_name'} = $params->{'collection_name'} 
    if(defined($params->{'collection_name'}));

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   method_link : ", $self->{'method_link'},"\n");
  print("   query_genome_db_id : ", $self->{'query_genome_db_id'},"\n");
  print("   target_genome_db_id : ", $self->{'target_genome_db_id'},"\n");
  print("   height : ", $self->{'height'},"\n");
  print("   collection_name : ", $self->{'collection_name'},"\n");

}


sub filter_stack {
    my $self = shift;
    
    my $height = $self->{'height'};
    my $dna_collection  = $self->{'collection'};
    
    $self->{'delete_group'} = {}; #all the genomic_align_blocks that need to be deleted
    my $mlss = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db_id'}, $self->{'target_genome_db_id'}]);
    
    
    my $GAB_DBA = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
    # create a list of dnafrag here in case we want to make this runnable working with an input_id 
    # containing a list of dnafrag_ids

    #my $dnafrag_list = [$self->{'comparaDBA'}->get_DnaFragAdaptor->fetch_by_dbID($self->{'dnafrag_id'})];
    
    #my $dnafrag_id_list = $dna_collection->get_all_dnafrag_ids;
    my $dna_list = $dna_collection->get_all_dna_objects;

    foreach my $dna_object (@{$dna_list}) {
	my $dnafrag_chunk_array;
	
	if ($dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
	    $dnafrag_chunk_array = $dna_object->get_all_DnaFragChunks;
	} else {
	    $dnafrag_chunk_array = [$dna_object];
	}
	foreach my $new_dna_object (@$dnafrag_chunk_array) {
	    my $delete_group = {};
	    my $dnafrag = $new_dna_object->dnafrag;
	    
	    my $genomic_align_block_list = $GAB_DBA->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $dnafrag);
	    
	    #printf("dnafrag %s %s has %d GABs\n", $dnafrag->coord_system_name, $dnafrag->name, scalar(@$genomic_align_block_list));
	    
	    #print $dnafrag->name, ": ", scalar(@$genomic_align_block_list), "\n";
	    
	    if ($self->debug) {
		foreach my $gab (@{$genomic_align_block_list}) {
		    $self->assign_jobID_to_genomic_align_block($gab);
		}
	    }
	    
	    @$genomic_align_block_list = sort {
		$a->reference_genomic_align->dnafrag_start <=>
		  $b->reference_genomic_align->dnafrag_start} @$genomic_align_block_list;
	    my $max_end = 0;
	    my $blocks = [];
	    foreach my $this_genomic_align_block (@$genomic_align_block_list) {
	      #found all overlapping blocks
		if ($this_genomic_align_block->reference_genomic_align->dnafrag_start > $max_end) {
		    if (@$blocks > 0) {
			$delete_group = $self->find_stack_coverage($blocks, $height, $delete_group);
		    }
		    $blocks = [];
		}
		push(@$blocks, $this_genomic_align_block);
		if ($this_genomic_align_block->reference_genomic_align->dnafrag_end > $max_end) {
		    $max_end = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
		}
	    }
	    if (@$blocks > 0) {
		$delete_group = $self->find_stack_coverage($blocks, $height, $delete_group);
	    }
	    $self->delete_alignments($GAB_DBA, $mlss, $delete_group);
	}
    }
}

sub assign_jobID_to_genomic_align_block {
  my $self = shift;
  my $gab = shift;

  my $sql = "SELECT analysis_job_id FROM genomic_align_block_job_track ".
                  "WHERE genomic_align_block_id=?";
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute($gab->dbID);
  my ($job_id) = $sth->fetchrow_array();
  $sth->finish;
  $gab->{'analysis_job_id'} = $job_id;
}

sub find_stack_coverage {
    my ($self, $blocks, $height, $delete_group) = @_;

    #find coverage ie min start and max end of overlapping blocks
    my ($min_start, $max_end);
    foreach my $this_block (@$blocks) {
	if (!$min_start or $min_start > $this_block->reference_genomic_align->dnafrag_start) {
	    $min_start = $this_block->reference_genomic_align->dnafrag_start;
	}
	if (!$max_end or $max_end < $this_block->reference_genomic_align->dnafrag_end) {
	    $max_end = $this_block->reference_genomic_align->dnafrag_end;
	}
    }
    
    #print "update_coverage min_start $min_start max_end $max_end\n";
    
    #find number of overlapping blocks for each position in coverage
    my @coverage_by_pos;
    foreach my $this_block (@$blocks) {
	my $start = $this_block->reference_genomic_align->dnafrag_start;
	my $end = $this_block->reference_genomic_align->dnafrag_end;
	for (my $a = $start; $a <= $end; $a++) {
	    $coverage_by_pos[$a-$min_start]++;
	}
    }
    
    my $threshold_limits;
    my $threshold_limit;

    #loop through each position in coverage
    for (my $a = 0; $a < @coverage_by_pos; $a++) {
	$coverage_by_pos[$a] ||= 0;
	
	#if number of gabs at this position is above threshold
	if ($coverage_by_pos[$a] > $height) {
	    #find start of threshold coverage
	    if (!defined $threshold_limit->{min}) {
		$threshold_limit->{min} = $a+$min_start;
	    }
	} else {
	    #coverage has fallen below threshold so store max as previous value if
	    #min has already been stored.
	    if (defined($threshold_limit->{min})) {
		$threshold_limit->{max} = $a+$min_start-1;
		push @$threshold_limits, $threshold_limit;
		#unset threshold_limit 
		undef($threshold_limit);
	    }
	}
    }
    
    #if the last item of coverage_by_pos is above the threshold, I won't have found it before in previous loop
    if (defined($threshold_limit->{min}) && !defined($threshold_limit->{max} && $coverage_by_pos[-1] > $height)) {
	$threshold_limit->{max} = @coverage_by_pos+$min_start-1;
	push @$threshold_limits, $threshold_limit;
	undef($threshold_limit);
    }

    #remove all blocks that are entirely covered by the threshold limits.
    foreach my $limit (@$threshold_limits) {
	foreach my $this_block (@$blocks) {
	    my $start = $this_block->reference_genomic_align->dnafrag_start;
	    my $end = $this_block->reference_genomic_align->dnafrag_end;
	    if ($start >= $limit->{min} && $end <= $limit->{max}) {
		#print "delete gab $start $end " . $this_block->dbID . "\n";
		push @{$delete_group->{$this_block->group_id}}, $this_block;
	    }
	}
    }
    return $delete_group;
}


sub delete_alignments {
    my ($self, $GAB_DBA, $mlss, $delete_group) = @_;
    my @del_list;
    
    foreach my $group_id (keys %{$delete_group}) {
	my $group_gabs = $GAB_DBA->fetch_all_by_MethodLinkSpeciesSet_GroupID($mlss, $group_id);
		
	#Only delete a gab if all the gabs of a group are in $delete_group
	if (@$group_gabs == @{$delete_group->{$group_id}}) {
	    #check the gab->dbIDs match
	    my $error = 0;
	    @$group_gabs = sort {$a->dbID<=>$b->dbID} @$group_gabs;
	    @{$delete_group->{$group_id}} = sort {$a->dbID<=>$b->dbID} @{$delete_group->{$group_id}};
	    for (my $i = 0; $i < @$group_gabs; $i++) {
		#Hopefully this should never happen
		if ($group_gabs->[$i]->dbID != $delete_group->{$group_id}->[$i]->dbID) {
		    warn "Inconsistent genomic_align_blocks in group $group_id \n";
		    $error = 1;
		}
	    }
	    if (!$error) {
		push @del_list, @$group_gabs;
	    }
	}
    }

    #assume not many of these
    if (@del_list > 0) {
	my @gab_ids = map {$_->dbID} @del_list;    
	my $sql_genomic_align = "DELETE FROM genomic_align WHERE genomic_align_block_id IN (" . join(",", @gab_ids) . ");";
	my $sql_genomic_align_block = "DELETE FROM genomic_align_block WHERE genomic_align_block_id in (" . join(",", @gab_ids) . ");";
	
	#foreach my $gab (@del_list) {
	#   print("DELETE "); 
	#   print_gab($gab);
	#}
	my $sth_genomic_align = $self->{'comparaDBA'}->prepare($sql_genomic_align);
	$sth_genomic_align->execute;
	$sth_genomic_align->finish;
	my $sth_genomic_align_block = $self->{'comparaDBA'}->prepare($sql_genomic_align_block);
	$sth_genomic_align_block->execute;
	$sth_genomic_align->execute;
    }
    printf("%d gabs to delete\n", scalar(@del_list));
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


1;
