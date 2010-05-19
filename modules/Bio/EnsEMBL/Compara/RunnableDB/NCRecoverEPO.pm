#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NCRecoverEPO

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $nc_recover_epo = Bio::EnsEMBL::Compara::RunnableDB::NCRecoverEPO->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$nc_recover_epo->fetch_input(); #reads from DB
$nc_recover_epo->run();
$nc_recover_epo->output();
$nc_recover_epo->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::NCRecoverEPO;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  # Get the needed adaptors here
  $self->{memberDBA} = $self->{comparaDBA}->get_MemberAdaptor;
  $self->{treeDBA}   = $self->{'comparaDBA'}->get_NCTreeAdaptor;
  $self->{mlssDBA}   = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  $self->{ssDBA}   = $self->{'comparaDBA'}->get_SpeciesSetAdaptor;

  my @nc_trees_mlsses = @{$self->{mlssDBA}->fetch_all_by_method_link_type('NC_TREES')};
  $self->{mlssID} = $nc_trees_mlsses[0]->dbID || 0;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->{'comparaDBA_epo'} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{epo_db}, 'compara');
  $self->{gabDBA_epo} = $self->{'comparaDBA_epo'}->get_GenomicAlignBlockAdaptor;
  $self->{mlssDBA_epo} = $self->{'comparaDBA_epo'}->get_MethodLinkSpeciesSetAdaptor;

  my $low_cov_ss = $self->{ssDBA}->fetch_by_tag_value('name','low-coverage-assembly');

  $low_cov_ss = $self->{ssDBA}->fetch_by_tag_value('name','low-coverage') if (!defined($low_cov_ss) || $low_cov_ss eq '');
  foreach my $gdb (@{$low_cov_ss->genome_dbs}) {
    $self->{low_cov_gdbs}{$gdb->dbID} = 1;
  }

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[epo_db analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} = 
         $self->{'comparaDBA'}->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
    printf("  nc_tree_id : %d\n", $self->{'nc_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
    printf("  clusterset_id : %d\n", $self->{'clusterset_id'});
  }

  if(defined($params->{epo_gdb})) {
    foreach my $epo_gdb (@{$params->{epo_gdb}}) {
      $self->{epo_gdb}{$epo_gdb} = 1;
    }
  }
  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_ncrecoverepo;
  $self->run_low_coverage_best_in_alignment;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  $self->remove_low_cov_predictions;
  $self->add_matching_predictions;
}


##########################################
#
# internal methods
#
##########################################

sub run_ncrecoverepo {
  my $self = shift;

  my $root_id = $self->{nc_tree}->node_id;
  # Find absent gdbs
  foreach my $leaf (@{$self->{nc_tree}->get_all_leaves}) {
    $self->{present_gdbs}{$leaf->genome_db_id}++;
  }
  foreach my $present_gdb (keys %{$self->{present_gdbs}}) {
    if (defined($self->{epo_gdb}{$present_gdb})) {
      $self->{present_epo_gdb}{$present_gdb} = 1;
    }
  }
  foreach my $epo_gdb (keys %{$self->{epo_gdb}}) {
    if (!defined($self->{present_gdbs}{$epo_gdb})) {
      $self->{absent_gdbs}{$epo_gdb} = 1;
    }
  }

  my $leaves = $self->{nc_tree}->get_all_leaves;
  foreach my $leaf (@$leaves) {
    my $description = $leaf->description; $description =~ /Gene\:(\S+)/; my $gene_id = $1;
    $self->{nc_tree_gene_ids}{$gene_id} = 1;
    $self->{seq_length} += length($leaf->sequence);
  }
  $self->{avg_seq_length} = $self->{seq_length}/(scalar @$leaves);

  if (defined($self->{absent_gdbs})) {
    my $pecan_mlss = @{$self->{mlssDBA_epo}->fetch_all_by_method_link_type('PECAN')}->[0];

    foreach my $leaf (@{$self->{nc_tree}->get_all_leaves}) {
      my $gdb_name = $leaf->genome_db->name;
      print STDERR "# PECAN $gdb_name\n" if ($self->debug);
      next unless(defined($self->{present_epo_gdb}{$leaf->genome_db_id})); # Only for the ones in genomic alignments
      my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
      next unless (defined($slice));
      my $genomic_align_blocks = $self->{gabDBA_epo}->fetch_all_by_MethodLinkSpeciesSet_Slice($pecan_mlss,$slice);
      next unless(0 < scalar(@$genomic_align_blocks));
      foreach my $genomic_align_block (@$genomic_align_blocks) {
        my $pecan_restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start,$slice->end);
        next unless (defined($pecan_restricted_gab));
        my $gab_start = $pecan_restricted_gab->{restricted_aln_start};
        my $gab_end   = $genomic_align_block->length - $pecan_restricted_gab->{restricted_aln_end};
        my $boundary = 10;
        if (defined($self->{pecan_restricted_gab}{$genomic_align_block->dbID})) {
          if (
              abs($self->{pecan_restricted_gab}{$genomic_align_block->dbID}{start} - $gab_start) < $boundary &&
              abs($self->{pecan_restricted_gab}{$genomic_align_block->dbID}{end}   - $gab_end) < $boundary &&
              abs($self->{pecan_restricted_gab}{$genomic_align_block->dbID}{slice_length} - $slice->length) < $boundary
             ) {
            # same genomic alignment region, dont need to go through it again
            print STDERR "#   same genomic alignment region, dont need to go through it again\n" if ($self->debug);
            next;
          }
        }
        $self->{pecan_restricted_gab}{$genomic_align_block->dbID}{start}          = $gab_start;
        $self->{pecan_restricted_gab}{$genomic_align_block->dbID}{end}            = $gab_end;
        $self->{pecan_restricted_gab}{$genomic_align_block->dbID}{slice_length}   = $slice->length;
        foreach my $genomic_align (@{$pecan_restricted_gab->get_all_GenomicAligns}) {
          my $ga_gdb = $genomic_align->genome_db;
          next if ($ga_gdb->dbID == $leaf->genome_db_id);
          my $core_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($ga_gdb->name, "core");
          throw("Cannot access core db") unless(defined($core_adaptor));
          $core_adaptor->dbc->disconnect_when_inactive(0);
          $genomic_align->dnafrag->genome_db->db_adaptor($core_adaptor);
          my $other_slice = $genomic_align->get_Slice;
          my $other_genome_db_id = $genomic_align->genome_db->dbID;
          next unless (defined ($other_slice));
          my $genes = $other_slice->get_all_Genes;
          my $found_prediction; my $validated_prediction = 0;
          print STDERR "#   Other genome: ", $genomic_align->genome_db->name, "\n" if ($self->debug);
          foreach my $gene (@$genes) {
            my $gene_stable_id = $gene->stable_id;
            if (defined($self->{nc_tree_gene_ids}{$gene_stable_id})) {
              $self->{validated_nc_tree_gene_ids}{$gene_stable_id} = 1;
              $found_prediction->{$gene_stable_id} = 1;
              $validated_prediction = 1;
            } elsif ($gene->biotype !~ /coding/) {
              $found_prediction->{$gene_stable_id} = 1;
              print STDERR "#     $gene_stable_id, biotype:", $gene->biotype, "\n" if ($self->debug);
            }
          }
          if (defined($found_prediction) && 0 == $validated_prediction) {
            foreach my $found_gene_stable_id (keys %$found_prediction) {
              # Store it in the table
              my $sth = $self->{'comparaDBA'}->dbc->prepare
                ("INSERT IGNORE INTO recovered_member 
                           (node_id,
                            stable_id,
                            genome_db_id) VALUES (?,?,?)");
              $sth->execute($root_id,
                            $found_gene_stable_id,
                            $other_genome_db_id);
              $sth->finish;
              # See if we can match the RFAM name or RFAM id
              my $gene_member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$found_gene_stable_id);
              next unless (defined($gene_member));
              my $other_tree = $self->{treeDBA}->fetch_by_Member_root_id($gene_member);
              if (defined($other_tree)) {
                my $other_tree_id = $other_tree->node_id;
                print STDERR  "#     found_description and gene_member, but already in tree $other_tree_id [$root_id]\n" if ($self->debug);
                next;
              }
              my $description = $gene_member->description;
              $description =~ /Acc:(\w+)/;
              my $acc_description = $1 if (defined($1));
              my $clustering_id = $self->{nc_tree}->get_tagvalue('clustering_id');
              my $model_id = $self->{nc_tree}->get_tagvalue('model_id');
              if ($acc_description eq $clustering_id || $acc_description eq $model_id) {
                $self->{predictions_to_add}->{$found_gene_stable_id} = 1;
              } else {
                print STDERR "#     found_prediction but Acc not mapped: $acc_description [$clustering_id - $model_id]\n" if ($self->debug);
              }
            }
          }
          # We don't have a gene prediction here, so we try to predict one
          if (!defined($found_prediction)) {
            my $start   = $other_slice->start;
            my $end     = $other_slice->end;
            my $seqname = $other_slice->seq_region_name;
            my $sequence = $other_slice->seq; $sequence =~ s/N//g;
            my $length = length($sequence);
            next if (0 == $length);
            next if (($self->{avg_seq_length}/$length) > 1.2 ||
                     ($self->{avg_seq_length}/$length) < 0.8);
            my $found_gene_stable_id = "$seqname:$start-$end";
            my $sth = $self->{'comparaDBA'}->dbc->prepare
              ("INSERT IGNORE INTO recovered_member 
                           (node_id,
                            stable_id,
                            genome_db_id) VALUES (?,?,?)");
            $sth->execute($root_id,
                          $found_gene_stable_id,
                          $other_genome_db_id);
            $sth->finish;
            print STDERR "#     no_prediction\n" if ($self->debug);
            # Use the RFAM model to see if the sequence is good
          }
        }
      }
    }
  }

  return 1;
}

sub run_low_coverage_best_in_alignment {
  my $self = shift;

  my $epo_low_mlss = @{$self->{mlssDBA_epo}->fetch_all_by_method_link_type('EPO_LOW_COVERAGE')}->[0];
  foreach my $genome_db (@{$epo_low_mlss->species_set}) {
    $self->{epo_low_cov_gdbs}{$genome_db->dbID}++;
  }

  # First round to get the candidate GenomicAlignTrees
  foreach my $leaf (@{$self->{nc_tree}->get_all_leaves}) {
    my $gdb_name = $leaf->genome_db->name;
    if (defined($self->{low_cov_gdbs}{$leaf->genome_db_id})) {
      $self->{low_cov_leaves_pmember_id}{$leaf->member_id} = 1;
      $self->{low_cov_leaves_stable_id}{$leaf->stable_id} = 1;
      next;
    }
    next unless (defined($self->{epo_low_cov_gdbs}{$leaf->genome_db_id}));
    my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    next unless (defined($slice));
    my $genomic_align_blocks = $self->{gabDBA_epo}->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss,$slice);
    next unless(0 < scalar(@$genomic_align_blocks));
    print STDERR "# CANDIDATE EPO_LOW_COVERAGE $gdb_name\n" if ($self->debug);
    foreach my $genomic_align_block (@$genomic_align_blocks) {
      if (!defined($genomic_align_block->dbID)) {
        # It's considered 2x in the epo_low_cov, so add to the list and skip
        $self->{epo_low_cov_gdbs}{$leaf->genome_db_id}++;
        next;
      }
      my $epo_low_restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start,$slice->end);
      next unless (defined($epo_low_restricted_gab));
      my $gab_start = $epo_low_restricted_gab->{restricted_aln_start};
      my $gab_end   = $genomic_align_block->length - $epo_low_restricted_gab->{restricted_aln_end};
      my $boundary = 10;
      $self->{epo_low_restricted_gab}{$leaf->genome_db_id}{gabID}          = $genomic_align_block->dbID;
      $self->{epo_low_restricted_gab}{$leaf->genome_db_id}{start}          = $gab_start;
      $self->{epo_low_restricted_gab}{$leaf->genome_db_id}{end}            = $gab_end;
      $self->{epo_low_restricted_gab}{$leaf->genome_db_id}{slice_length}   = $slice->length;
      $self->{epo_low_restricted_gab}{$leaf->genome_db_id}{gdb_name}       = $gdb_name;
      $self->{epo_low_restricted_gabIDs}{$genomic_align_block->dbID}++;
    }
  }
  my $epo_low_gabIDS = scalar keys %{$self->{epo_low_restricted_gabIDs}};
  my $max = 0; my $max_gabID;
  foreach my $gabID (keys %{$self->{epo_low_restricted_gabIDs}}) {
    my $count = $self->{epo_low_restricted_gabIDs}{$gabID};
    if ($count > $max) {$max = $count; $max_gabID = $gabID};
  }

  # Second round to get the low-covs on the max_gabID
  foreach my $leaf (@{$self->{nc_tree}->get_all_leaves}) {
    my $gdb_name = $leaf->genome_db->name;
    next unless (defined($self->{low_cov_gdbs}{$leaf->genome_db_id}));
    next unless (defined($self->{epo_low_cov_gdbs}{$leaf->genome_db_id}));
    my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    throw("Unable to fetch slice for this genome_db leaf: $gdb_name") unless (defined($slice));
    $self->{low_cov_slice_seqs}{$leaf->genome_db_id}{$leaf->member_id} = $slice;
    my $low_cov_genomic_align_blocks = $self->{gabDBA_epo}->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss,$slice);
    unless (0 < scalar(@$low_cov_genomic_align_blocks)) {
      # $DB::single=1;1;
      $self->{low_cov_leaves_to_delete_pmember_id}{$leaf->member_id} = $leaf->gene_member->stable_id;
      next;
    }
    print STDERR "# EPO_LOW_COVERAGE $gdb_name\n" if ($self->debug);
    foreach my $low_cov_genomic_align_block (@$low_cov_genomic_align_blocks) {
      unless ($low_cov_genomic_align_block->{original_dbID} == $max_gabID) {
        # We delete this leaf because it's a low_cov slice that is not in the epo_low_cov, so it's the best in alignment
        # $DB::single=1;1;
        $self->{low_cov_leaves_to_delete_pmember_id}{$leaf->member_id} = $leaf->gene_member->stable_id;
      } else {
        $self->{low_cov_leaves_pmember_id_slice_to_check_coord_system}{$leaf->member_id} = $leaf->gene_member->stable_id;
      }
    }
  }

  foreach my $genome_db_id (keys %{$self->{low_cov_slice_seqs}}) {
    my @member_ids = keys %{$self->{low_cov_slice_seqs}{$genome_db_id}};
    next if (2 > scalar @member_ids);
    while (my $member_id1 = shift (@member_ids)) {
      foreach my $member_id2 (@member_ids) {
        my $slice1 = $self->{low_cov_slice_seqs}{$genome_db_id}{$member_id1};
        my $coord_level1 = $slice1->coord_system->is_top_level;
        my $slice2 = $self->{low_cov_slice_seqs}{$genome_db_id}{$member_id2};
        my $coord_level2 = $slice2->coord_system->is_top_level;
        if (0 < abs($coord_level1-$coord_level2)) {
          if ($coord_level2 < $coord_level1) {
            my $temp_slice = $slice1; $slice1 = $slice2; $slice2 = $temp_slice;
            my $temp_member_id = $member_id1; $member_id1 = $member_id2; $member_id2 = $temp_member_id;
          }
        }
        my $mapped_slice2 = @{$slice2->project($slice1->coord_system->name)}->[0];
        next unless(defined($mapped_slice2)); # no projection, so pair of slices are different
        my $proj_slice2 = $mapped_slice2->to_Slice;
        if ($slice1->seq_region_name eq $proj_slice2->seq_region_name &&
            $slice1->start           eq $proj_slice2->start           &&
            $slice1->end             eq $proj_slice2->end) {
          $self->{low_cov_same_slice}{$member_id1} = $member_id2;
        }
      }
    }
  }

  foreach my $member_id1 (keys %{$self->{low_cov_same_slice}}) {
    my $member_id2 = $self->{low_cov_same_slice}{$member_id1};
    if (defined ($self->{low_cov_leaves_pmember_id_slice_to_check_coord_system}{$member_id2})) {
      # We found this slice in the genomic alignment, but it's same
      # slice as another higher rank slice, so goes to the delete list
      my $stable_id2 = $self->{low_cov_leaves_pmember_id_slice_to_check_coord_system}{$member_id2};
      # $DB::single=1;1;
      $self->{low_cov_leaves_to_delete_pmember_id}{$member_id2} = $stable_id2;
    }
  }
}

sub remove_low_cov_predictions {
  my $self = shift;
  my $root_id = $self->{nc_tree}->node_id;

  # Remove low cov members that are not best in alignment
  foreach my $leaf (@{$self->{nc_tree}->get_all_leaves}) {
    if (defined($self->{low_cov_leaves_to_delete_pmember_id}{$leaf->member_id})) {
      my $removed_stable_id = $self->{low_cov_leaves_to_delete_pmember_id}{$leaf->member_id};
      print STDERR "removing low_cov prediction $removed_stable_id\n" if($self->debug);
      my $removed_genome_db_id = $leaf->genome_db_id;
      $leaf->disavow_parent;
      $self->{treeDBA}->delete_flattened_leaf($leaf);
      my $sth = $self->{'comparaDBA'}->dbc->prepare
        ("INSERT IGNORE INTO removed_member 
                           (node_id,
                            stable_id,
                            genome_db_id) VALUES (?,?,?)");
      $sth->execute($root_id,
                    $removed_stable_id,
                    $removed_genome_db_id);
      $sth->finish;
    }
  }
  #calc residue count total
  my $leafcount = scalar(@{$self->{nc_tree}->get_all_leaves});
  $self->{nc_tree}->store_tag('gene_count', $leafcount);

  return 1;
}

sub add_matching_predictions {
  my $self = shift;

  # Insert the members that are found new and have matching Acc
  foreach my $gene_stable_id_to_add (keys %{$self->{predictions_to_add}}) {
    my $gene_member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$gene_stable_id_to_add);
    # Incorporate this member into the cluster
    my $node = new Bio::EnsEMBL::Compara::NestedSet;
    $node->node_id($gene_member->get_canonical_peptide_Member->member_id);
    $self->{nc_tree}->add_child($node);
    $self->{nc_tree}->clusterset_id($self->{'clusterset_id'});
    #leaves are NestedSet objects, bless to make into AlignedMember objects
    bless $node, "Bio::EnsEMBL::Compara::AlignedMember";

    #the building method uses member_id's to reference unique nodes
    #which are stored in the node_id value, copy to member_id
    $node->member_id($node->node_id);
    $node->method_link_species_set_id($self->{mlssID});
    # We won't do the store until the end, otherwise it will affect the main loop
    print STDERR "adding matching prediction $gene_stable_id_to_add\n" if($self->debug);
  }
  my $clusterset = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});
  $self->{treeDBA}->store($self->{nc_tree});

  #calc residue count total
  my $leafcount = scalar(@{$self->{nc_tree}->get_all_leaves});
  $self->{nc_tree}->store_tag('gene_count', $leafcount);

  return 1;
}


1;
