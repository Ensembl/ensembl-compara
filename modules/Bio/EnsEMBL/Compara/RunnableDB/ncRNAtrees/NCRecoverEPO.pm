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

  Please email comments or questions to the public Ensembl 
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverEPO;

use strict;
use warnings;
use Data::Dumper;

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

  my $mlss_id    = $self->param_required('mlss_id');
  my $nc_tree_id = $self->param_required('gene_tree_id');

  $self->param('nc_tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id));
  $self->param('nc_tree') || die "Could not fetch the tree for root_id=$nc_tree_id";

  if ($self->param('max_members') and scalar(@{$self->param('nc_tree')->get_all_Members}) > $self->param('max_members')) {
    $self->input_job->autoflow(0);
    $self->dataflow_output_id(undef, -1);
    $self->complete_early('Too many members, going to _himem');
  }

  $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
  $self->param('treenode_adaptor', $self->compara_dba->get_GeneTreeNodeAdaptor);

  my $epo_dba = $self->get_cached_compara_dba('epo_db');
  $self->param('epo_gab_adaptor', $epo_dba->get_GenomicAlignBlockAdaptor);
  $self->param('epo_mlss_adaptor', $epo_dba->get_MethodLinkSpeciesSetAdaptor);
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

  # $self->run_ncrecoverepo;
  $self->iterate_over_lowcov_mlsss;
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

#  $self->param('predictions_to_add', {});
  $self->remove_low_cov_predictions;
#  $self->add_matching_predictions;
}


##########################################
#
# internal methods
#
##########################################

# This is currently not called
sub run_ncrecoverepo {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->root_id;

  my %present_gdbs     = ();
  my %absent_gdbs      = ();
  my %present_epo_gdbs = ();
  
  # NOTE: 'epo_gdb' used to be a hash { genome_db_id => 1 } containing all the low-coverage species
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
              my $gene_member = $self->param('gene_member_adaptor')->fetch_by_stable_id($found_gene_stable_id);
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
              my $acc_description = $1 || '';
              my $model_id = $self->param('nc_tree')->get_value_for_tag('model_id');
              if ($acc_description eq $model_id) {
                $self->param('predictions_to_add')->{$found_gene_stable_id} = 1;
              } else {
                print STDERR "#     found_prediction but Acc not mapped: $acc_description [$model_id]\n" if ($self->debug);
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

# This one is called
sub iterate_over_lowcov_mlsss {
    my $self = shift @_;
    my $epolow_mlsss = $self->param('epo_mlss_adaptor')->fetch_all_by_method_link_type('EPO_LOW_COVERAGE');
    unless (scalar(@$epolow_mlsss)) {
        die "Could not find an 'EPO_LOW_COVERAGE' MLSS in ".$self->param('epo_db')."\n";
    }
    my @gab_ids;
    $self->param('low_cov_leaves_to_delete', []);
    foreach my $epo_low_mlss (@$epolow_mlsss) {
        my $epo_hc_mlss = $self->param('epo_mlss_adaptor')->fetch_by_dbID($epo_low_mlss->get_value_for_tag('high_coverage_mlss_id'))
            || die "Could not find the matching 'EPO' MLSS in ".$self->param('epo_db')."\n";
        my %hc_gdb_id = (map {$_->dbID => 1} @{$epo_hc_mlss->species_set->genome_dbs});
        my @lowcov_gdbs = grep {not exists $hc_gdb_id{$_->dbID}} @{$epo_low_mlss->species_set->genome_dbs};
        my %low_gdb_id = (map {$_->dbID => 1} @lowcov_gdbs);
        my $gab_id = $self->run_low_coverage_best_in_alignment($epo_low_mlss, \%hc_gdb_id, \%low_gdb_id);
        push @gab_ids, $gab_id if $gab_id;
    }
    $self->param('nc_tree')->store_tag('ncrecoverepo_filter_gab_id', \@gab_ids) if scalar(@gab_ids);
}

# This one too
sub run_low_coverage_best_in_alignment {
  my $self = shift;
  my $epo_low_mlss = shift;
  my $hc_gdb_id = shift;
  my $lc_gdb_id = shift;

  my %gdb_per_dbID = map {$_->dbID => $_} @{ $self->compara_dba->get_GenomeDBAdaptor->fetch_all() };
  # now we can disconnect
  $self->compara_dba->dbc->disconnect_if_idle();

  my %members_per_genome_db_id;
  foreach my $member (@{ $self->param('nc_tree')->get_all_Members }) {
      push @{ $members_per_genome_db_id{$member->genome_db_id} }, $member;
  }

  my %all_seen_gab_ids = ();

  # First round to get the candidate GenomicAlignTrees
  # We first iterate over the high-coverage genome_dbs
  # This way, we group the queries to the same core database
  foreach my $gdb_id (keys %{$hc_gdb_id}) {

   my $genome_db = $gdb_per_dbID{$gdb_id};
   if (! defined $genome_db){
       $self->warning("genome_db_id: $gdb_id is not found in the current DB. Probably an old id was being used.");
       next;
   }

   my $gdb_name = $genome_db->name;
   print STDERR "doing $gdb_name\n" if $self->debug;

   my $leaves = $members_per_genome_db_id{$gdb_id};
   my $core_db_adaptor = $genome_db->db_adaptor;
   $core_db_adaptor->dbc->prevent_disconnect( sub {
   foreach my $leaf (@$leaves) {
    my $slice = $core_db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    my $genomic_align_blocks = $self->param('epo_gab_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss, $slice);
    print STDERR scalar(@$genomic_align_blocks), " blocks for ", $leaf->stable_id, "\n" if $self->debug;
    foreach my $genomic_align_block (@$genomic_align_blocks) {
        if (not defined $genomic_align_block->dbID) {
            # Happens when the block has been restricted
            next;
        }
      $all_seen_gab_ids{$genomic_align_block->dbID}++;
    }
   }
   } );
  }

  # This selects the GAB with the highest number of species
  my $max = 0; my $max_gabID;
  foreach my $gabID (keys %all_seen_gab_ids) {
    my $count = $all_seen_gab_ids{$gabID};
    if ($count > $max) {$max = $count; $max_gabID = $gabID};
  }
  return undef unless $max;
  print STDERR "BEST_GAB: $max_gabID ($max species)\n" if $self->debug;

  # Second round to get the low-covs on the max_gabID
  # We apply the same trick as above
  foreach my $gdb_id (keys %{$lc_gdb_id}) {

   my $genome_db = $gdb_per_dbID{$gdb_id};
   if (! defined $genome_db){
       $self->warning("genome_db_id: $gdb_id is not found in the current DB. Probably an old id was being used.");
       next;
   }
   my $gdb_name = $genome_db->name;
   print STDERR "working on $gdb_name\n" if $self->debug;
   my $leaves = $members_per_genome_db_id{$gdb_id};
   my $core_db_adaptor = $genome_db->db_adaptor;
   $core_db_adaptor->dbc->prevent_disconnect( sub {
   foreach my $leaf (@$leaves) {
    my $slice = $core_db_adaptor->get_SliceAdaptor->fetch_by_transcript_stable_id($leaf->stable_id);
    my $low_cov_genomic_align_blocks = $self->param('epo_gab_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_low_mlss,$slice);
    unless (0 < scalar(@$low_cov_genomic_align_blocks)) {
      push @{ $self->param('low_cov_leaves_to_delete') }, $leaf;
      print STDERR $leaf->stable_id, " has no alignments -> will be removed\n" if $self->debug;
      next;
    }
    print STDERR scalar(@$low_cov_genomic_align_blocks), " blocks for ", $leaf->stable_id, "\n" if $self->debug;
    my $deleted = 0;
    foreach my $low_cov_genomic_align_block (@$low_cov_genomic_align_blocks) {
        die unless $max_gabID;
      if ($low_cov_genomic_align_block->original_dbID != $max_gabID) {
        # We delete this leaf because it's a low_cov slice that is not in the epo_low_cov, so it's the best in alignment
        push @{ $self->param('low_cov_leaves_to_delete') }, $leaf;
        print STDERR $leaf->stable_id, " is not in GAB $max_gabID -> will be removed\n" if $self->debug;
        $deleted = 1;
        last;
      }
    }
    unless ($deleted) {
      print STDERR $leaf->stable_id, " is in GAB $max_gabID -> will be kept \n" if $self->debug;
    }
   }
   } );
  }
  # We don't need the connection to the EPO database any more;
  $self->param('epo_gab_adaptor')->dbc->disconnect_if_idle();

  return $max_gabID;
  $self->param('nc_tree')->store_tag('ncrecoverepo_best_gab_id', $max_gabID);
}

sub remove_low_cov_predictions {
  my $self = shift;
  my $nc_tree = $self->param('nc_tree');
  my $root_id = $nc_tree->root_id;

  # Remove low cov members that are not best in alignment
  foreach my $leaf_to_delete (@{ $self->param('low_cov_leaves_to_delete') }) {
      print STDERR "removing low_cov prediction ", $leaf_to_delete->stable_id, "\n" if($self->debug);
      $self->call_within_transaction(sub {
        $self->param('treenode_adaptor')->remove_seq_member($leaf_to_delete);
      });
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
      $self->input_job->autoflow(0);
      $self->complete_early("$root_id tree has become too short ($leafcount leaf/ves)\n");
  }
  $nc_tree->store_tag('gene_count', $leafcount);

  return 1;
}

# This is currently not called
sub add_matching_predictions {
  my $self = shift;

  # Insert the members that are found new and have matching Acc
  foreach my $gene_stable_id_to_add (keys %{$self->param('predictions_to_add')}) {
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_stable_id($gene_stable_id_to_add);
    # Incorporate the canonical seq_member into the cluster
    my $node = new Bio::EnsEMBL::Compara::GeneTreeMember;
    $node->seq_member_id($gene_member->get_canonical_SeqMember->seq_member_id);
    $self->param('nc_tree')->root->add_child($node);

    #the building method uses seq_member_id's to reference unique nodes
    #which are stored in the node_id value, copy to seq_member_id
    # We won't do the store until the end, otherwise it will affect the main loop
    print STDERR "adding matching prediction $gene_stable_id_to_add\n" if($self->debug);
    $self->param('treenode_adaptor')->store_node($node);
  }

  #calc residue count total
  my $leafcount = scalar(@{$self->param('nc_tree')->get_all_leaves});
  $self->param('nc_tree')->store_tag('gene_count', $leafcount);

  return 1;
}

1;
