#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $nc_recover_epo = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$nc_recover_epo->fetch_input(); #reads from DB
$nc_recover_epo->run();
$nc_recover_epo->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO;

use strict;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my $self = shift @_;

  return if ($self->param('skip'));

  $self->input_job->transient_error(0);
  my $mlss_id    = $self->param('mlss_id')      || die "'mlss_id' is an obligatory numeric parameter\n";
  my $epo_db     = $self->param('epo_db')       || die "'epo_db' is an obligatory hash parameter\n";
  my $nc_tree_id = $self->param('gene_tree_id') || die "'gene_tree_id' is an obligatory numeric parameter\n";
  $self->input_job->transient_error(1);


  print "$nc_tree_id\n";
  $self->param('nc_tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id));

  $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
  $self->param('treenode_adaptor', $self->compara_dba->get_GeneTreeNodeAdaptor);

  my $epo_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($epo_db);
  $self->param('epo_gab_adaptor', $epo_dba->get_GenomicAlignBlockAdaptor);
  $self->param('epo_mlss_adaptor', $epo_dba->get_MethodLinkSpeciesSetAdaptor);

  my $species_set_adaptor = $self->compara_dba->get_SpeciesSetAdaptor;

# Do we need two pass in and support two identical sets (epo_gdb and low_cov_gdbs)?
# Aren't they supposed to be different?

  my ($epo_ss) = @{ $species_set_adaptor->fetch_all_by_tag_value('name', 'low-coverage-assembly') };
  unless($epo_ss) {
    die "Could not fetch a SpeciesSet named 'low-coverage-assembly' from the database\n";
  }
  $self->param('epo_gdb', {});
  foreach my $epo_gdb (@{$epo_ss->genome_dbs}) {
      $self->param('epo_gdb')->{$epo_gdb} = 1;
  }

  my ($low_cov_ss) = @{ $species_set_adaptor->fetch_all_by_tag_value('name', 'low-coverage-assembly') };
  unless($low_cov_ss) {
    ($low_cov_ss) = @{ $species_set_adaptor->fetch_all_by_tag_value('name', 'low-coverage') };
  }
  unless($low_cov_ss) {
    die "A SpeciesSet named either 'low-coverage-assembly' or 'low-coverage' must be present in the database to run this analysis\n";
  }
  $self->param('low_cov_gdbs', {});
  foreach my $gdb (@{$low_cov_ss->genome_dbs}) {
    $self->param('low_cov_gdbs')->{$gdb->dbID} = 1;
  }

}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift @_;

  return if ($self->param('skip'));

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
  my $self = shift @_;

  return if ($self->param('skip'));

  $self->param('predictions_to_add', {});
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

  my $root_id = $self->param('nc_tree')->root_id;

  my %present_gdbs     = ();
  my %absent_gdbs      = ();
  my %present_epo_gdbs = ();
  
  # Find absent gdbs
  foreach my $leaf (@{$self->param('nc_tree')->get_all_leaves}) {
      $present_gdbs{$leaf->genome_db_id}++;
  }
  foreach my $present_gdb (keys %present_gdbs) {
    if (defined($self->param('epo_gdb')->{$present_gdb})) {
      $present_epo_gdbs{$present_gdb} = 1;
    }
  }
  foreach my $epo_gdb (keys %{$self->param('epo_gdb')}) {
    if (!defined($present_gdbs{$epo_gdb})) {
      $absent_gdbs{$epo_gdb} = 1;
    }
  }

  my %nc_tree_gene_ids = ();
  my $seq_length = 0;

  my $leaves = $self->param('nc_tree')->get_all_leaves;
  foreach my $leaf (@$leaves) {
    my $description = $leaf->description; $description =~ /Gene\:(\S+)/; my $gene_id = $1;
    $nc_tree_gene_ids{$gene_id} = 1;
    $seq_length += length($leaf->sequence);
  }
  
  my $avg_seq_length = $seq_length/(scalar @$leaves);

  my %pecan_restricted_gab_hash = ();

  if (keys %absent_gdbs) {
    my $pecan_mlss = $self->param('epo_mlss_adaptor')->fetch_all_by_method_link_type('PECAN')->[0];

    foreach my $leaf (@{$self->param('nc_tree')->get_all_leaves}) {
      my $gdb_name = $leaf->genome_db->name;
      print STDERR "# PECAN $gdb_name\n" if ($self->debug);
      next unless(defined($present_epo_gdbs{$leaf->genome_db_id})); # Only for the ones in genomic alignments
      my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
      next unless (defined($slice));
      my $genomic_align_blocks = $self->param('epo_gab_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($pecan_mlss,$slice);
      next unless(0 < scalar(@$genomic_align_blocks));
      foreach my $genomic_align_block (@$genomic_align_blocks) {
        my $pecan_restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start,$slice->end);
        next unless (defined($pecan_restricted_gab));
        my $gab_start = $pecan_restricted_gab->{restricted_aln_start};
        my $gab_end   = $genomic_align_block->length - $pecan_restricted_gab->{restricted_aln_end};
        my $boundary = 10;
        if (defined($pecan_restricted_gab_hash{$genomic_align_block->dbID})) {
          if (
              abs($pecan_restricted_gab_hash{$genomic_align_block->dbID}{start} - $gab_start) < $boundary &&
              abs($pecan_restricted_gab_hash{$genomic_align_block->dbID}{end}   - $gab_end) < $boundary &&
              abs($pecan_restricted_gab_hash{$genomic_align_block->dbID}{slice_length} - $slice->length) < $boundary
             ) {
            # same genomic alignment region, dont need to go through it again
            print STDERR "#   same genomic alignment region, dont need to go through it again\n" if ($self->debug);
            next;
          }
        }
        $pecan_restricted_gab_hash{$genomic_align_block->dbID}{start}          = $gab_start;
        $pecan_restricted_gab_hash{$genomic_align_block->dbID}{end}            = $gab_end;
        $pecan_restricted_gab_hash{$genomic_align_block->dbID}{slice_length}   = $slice->length;
        foreach my $genomic_align (@{$pecan_restricted_gab->get_all_GenomicAligns}) {
          my $ga_gdb = $genomic_align->genome_db;
          next if ($ga_gdb->dbID == $leaf->genome_db_id);
          my $core_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($ga_gdb->name, "core");
          $self->throw("Cannot access core db") unless(defined($core_adaptor));
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
            if (defined($nc_tree_gene_ids{$gene_stable_id})) {
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
              my $sth = $self->compara_dba->dbc->prepare
                ("INSERT IGNORE INTO recovered_member 
                           (node_id,
                            stable_id,
                            genome_db_id) VALUES (?,?,?)");
              $sth->execute($root_id,
                            $found_gene_stable_id,
                            $other_genome_db_id);
              $sth->finish;
              # See if we can match the RFAM name or RFAM id
              my $gene_member = $self->param('gene_member_adaptor')->fetch_by_source_stable_id('ENSEMBLGENE',$found_gene_stable_id);
              next unless (defined($gene_member));
              # FIXME: this code cannot work because nctree_adaptor is not defined !
              my $other_tree = $self->param('nctree_adaptor')->fetch_by_Member_root_id($gene_member);
              if (defined($other_tree)) {
                my $other_tree_id = $other_tree->node_id;
                print STDERR  "#     found_description and gene_member, but already in tree $other_tree_id [$root_id]\n" if ($self->debug);
                next;
              }
              my $description = $gene_member->description;
              $description =~ /Acc:(\w+)/;
              my $acc_description = $1 if (defined($1));
              my $clustering_id = $self->param('nc_tree')->get_tagvalue('clustering_id');
              my $model_id = $self->param('nc_tree')->get_tagvalue('model_id');
              if ($acc_description eq $clustering_id || $acc_description eq $model_id) {
                $self->param('predictions_to_add')->{$found_gene_stable_id} = 1;
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
            next if (($avg_seq_length/$length) > 1.2 ||
                     ($avg_seq_length/$length) < 0.8);
            my $found_gene_stable_id = "$seqname:$start-$end";
            my $sth = $self->compara_dba->dbc->prepare
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

  $self->param('epo_low_cov_gdbs', {});

  my $epo_low_mlss = $self->param('epo_mlss_adaptor')->fetch_all_by_method_link_type('EPO_LOW_COVERAGE')->[0];
  foreach my $genome_db (@{$epo_low_mlss->species_set_obj->genome_dbs()}) {
    $self->param('epo_low_cov_gdbs')->{$genome_db->dbID}++;
  }

  my %epo_low_restricted_gab_hash = ();
  my %epo_low_restricted_gabIDs = ();

  # First round to get the candidate GenomicAlignTrees
  foreach my $leaf (@{$self->param('nc_tree')->get_all_leaves}) {
    my $gdb_name = $leaf->genome_db->name;
    next if (defined($self->param('low_cov_gdbs')->{$leaf->genome_db_id}));

    next unless (defined($self->param('epo_low_cov_gdbs')->{$leaf->genome_db_id}));
    my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    next unless (defined($slice));
    my $genomic_align_blocks = $self->param('epo_gab_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss,$slice);
    next unless(0 < scalar(@$genomic_align_blocks));
    print STDERR "# CANDIDATE EPO_LOW_COVERAGE $gdb_name\n" if ($self->debug);
    foreach my $genomic_align_block (@$genomic_align_blocks) {
      if (!defined($genomic_align_block->dbID)) {
        # It's considered 2x in the epo_low_cov, so add to the list and skip
        $self->param('epo_low_cov_gdbs')->{$leaf->genome_db_id}++;
        next;
      }
      my $epo_low_restricted_gab = $genomic_align_block->restrict_between_reference_positions($slice->start,$slice->end);
      next unless (defined($epo_low_restricted_gab));
      my $gab_start = $epo_low_restricted_gab->{restricted_aln_start};
      my $gab_end   = $genomic_align_block->length - $epo_low_restricted_gab->{restricted_aln_end};
      my $boundary = 10;
      $epo_low_restricted_gab_hash{$leaf->genome_db_id}{gabID}          = $genomic_align_block->dbID;
      $epo_low_restricted_gab_hash{$leaf->genome_db_id}{start}          = $gab_start;
      $epo_low_restricted_gab_hash{$leaf->genome_db_id}{end}            = $gab_end;
      $epo_low_restricted_gab_hash{$leaf->genome_db_id}{slice_length}   = $slice->length;
      $epo_low_restricted_gab_hash{$leaf->genome_db_id}{gdb_name}       = $gdb_name;
      $epo_low_restricted_gabIDs{$genomic_align_block->dbID}++;
    }
  }
  my $max = 0; my $max_gabID;
  foreach my $gabID (keys %epo_low_restricted_gabIDs) {
    my $count = $epo_low_restricted_gabIDs{$gabID};
    if ($count > $max) {$max = $count; $max_gabID = $gabID};
  }

  my %low_cov_leaves_pmember_id_slice_to_check_coord_system = ();
  my %low_cov_slice_seqs = ();
  $self->param('low_cov_leaves_to_delete_pmember_id', {});

  # Second round to get the low-covs on the max_gabID
  foreach my $leaf (@{$self->param('nc_tree')->get_all_leaves}) {
    my $gdb_name = $leaf->genome_db->name;
    next unless (defined($self->param('low_cov_gdbs')->{$leaf->genome_db_id}));
    next unless (defined($self->param('epo_low_cov_gdbs')->{$leaf->genome_db_id}));
    my $slice = $leaf->genome_db->db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    $self->throw("Unable to fetch slice for this genome_db leaf: $gdb_name") unless (defined($slice));
    $low_cov_slice_seqs{$leaf->genome_db_id}{$leaf->member_id} = $slice;
    my $low_cov_genomic_align_blocks = $self->param('epo_gab_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss,$slice);
    unless (0 < scalar(@$low_cov_genomic_align_blocks)) {
      # $DB::single=1;1;
      $self->param('low_cov_leaves_to_delete_pmember_id')->{$leaf->member_id} = $leaf->gene_member->stable_id;
      next;
    }
    print STDERR "# EPO_LOW_COVERAGE $gdb_name\n" if ($self->debug);
    foreach my $low_cov_genomic_align_block (@$low_cov_genomic_align_blocks) {
      unless ($low_cov_genomic_align_block->{original_dbID} == $max_gabID) {
        # We delete this leaf because it's a low_cov slice that is not in the epo_low_cov, so it's the best in alignment
        # $DB::single=1;1;
        $self->param('low_cov_leaves_to_delete_pmember_id')->{$leaf->member_id} = $leaf->gene_member->stable_id;
      } else {
        $low_cov_leaves_pmember_id_slice_to_check_coord_system{$leaf->member_id} = $leaf->gene_member->stable_id;
      }
    }
  }

  my %low_cov_same_slice = ();

  foreach my $genome_db_id (keys %low_cov_slice_seqs) {
    my @member_ids = keys %{$low_cov_slice_seqs{$genome_db_id}};
    next if (2 > scalar @member_ids);
    while (my $member_id1 = shift (@member_ids)) {
      foreach my $member_id2 (@member_ids) {
        my $slice1 = $low_cov_slice_seqs{$genome_db_id}{$member_id1};
        my $coord_level1 = $slice1->coord_system->is_top_level;
        my $slice2 = $low_cov_slice_seqs{$genome_db_id}{$member_id2};
        my $coord_level2 = $slice2->coord_system->is_top_level;
        if (0 < abs($coord_level1-$coord_level2)) {
          if ($coord_level2 < $coord_level1) {
            my $temp_slice = $slice1; $slice1 = $slice2; $slice2 = $temp_slice;
            my $temp_member_id = $member_id1; $member_id1 = $member_id2; $member_id2 = $temp_member_id;
          }
        }
        my $mapped_slice2 = $slice2->project($slice1->coord_system->name)->[0];
        next unless(defined($mapped_slice2)); # no projection, so pair of slices are different
        my $proj_slice2 = $mapped_slice2->to_Slice;
        if ($slice1->seq_region_name eq $proj_slice2->seq_region_name &&
            $slice1->start           eq $proj_slice2->start           &&
            $slice1->end             eq $proj_slice2->end) {
          $low_cov_same_slice{$member_id1} = $member_id2;
        }
      }
    }
  }

  foreach my $member_id1 (keys %low_cov_same_slice) {
    my $member_id2 = $low_cov_same_slice{$member_id1};
    if (defined ($low_cov_leaves_pmember_id_slice_to_check_coord_system{$member_id2})) {
      # We found this slice in the genomic alignment, but it's same
      # slice as another higher rank slice, so goes to the delete list
      my $stable_id2 = $low_cov_leaves_pmember_id_slice_to_check_coord_system{$member_id2};
      # $DB::single=1;1;
      $self->param('low_cov_leaves_to_delete_pmember_id')->{$member_id2} = $stable_id2;
    }
  }
}

sub remove_low_cov_predictions {
  my $self = shift;
  my $nc_tree = $self->param('nc_tree');
  my $root_id = $nc_tree->root_id;

  # Remove low cov members that are not best in alignment
  foreach my $leaf (@{$nc_tree->get_all_leaves}) {
    if(my $removed_stable_id = $self->param('low_cov_leaves_to_delete_pmember_id')->{$leaf->member_id}) {
      print STDERR "removing low_cov prediction $removed_stable_id\n" if($self->debug);
      my $removed_genome_db_id = $leaf->genome_db_id;
      $leaf->disavow_parent;
      $self->param('treenode_adaptor')->delete_flattened_leaf($leaf);
      my $sth = $self->compara_dba->dbc->prepare
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
  my $leafcount = scalar(@{$nc_tree->get_all_leaves});

  ## Remove the tree if now it is too small
  if ($leafcount < 2) {
      my $gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor;
      $gene_tree_adaptor->delete_tree($nc_tree);

      ## TODO: Dying here prevents storing the tag for a disappeared tree.
      ## The problem is that it also prevents adding new members by add_matching_predictions below.
      ## For now, this is not a problem, since add_matching_predictions is not finished, but we may need to
      ## make sure that it is running properly once it is finished.
      $self->input_job->incomplete(0);
      die ("$root_id tree has become too short ($leafcount leaf/ves)\n");
  }
  $nc_tree->store_tag('gene_count', $leafcount);

  return 1;
}

sub add_matching_predictions {
  my $self = shift;

  # Insert the members that are found new and have matching Acc
  foreach my $gene_stable_id_to_add (keys %{$self->param('predictions_to_add')}) {
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_source_stable_id('ENSEMBLGENE',$gene_stable_id_to_add);
    # Incorporate this member into the cluster
    my $node = new Bio::EnsEMBL::Compara::GeneTreeMember;
    $node->member_id($gene_member->get_canonical_SeqMember->member_id);
    $self->param('nc_tree')->root->add_child($node);

    #the building method uses member_id's to reference unique nodes
    #which are stored in the node_id value, copy to member_id
    # We won't do the store until the end, otherwise it will affect the main loop
    print STDERR "adding matching prediction $gene_stable_id_to_add\n" if($self->debug);
    $self->param('treenode_adaptor')->store($node);
  }

  #calc residue count total
  my $leafcount = scalar(@{$self->param('nc_tree')->get_all_leaves});
  $self->param('nc_tree')->store_tag('gene_count', $leafcount);

  return 1;
}

1;
