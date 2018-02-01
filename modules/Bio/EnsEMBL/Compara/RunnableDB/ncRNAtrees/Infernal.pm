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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $infernal = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$infernal->fetch_input(); #reads from DB
$infernal->run();
$infernal->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
hmm_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;

use Bio::AlignIO;
use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::HMMProfile;
use Bio::EnsEMBL::Compara::Utils::Cigars;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub param_defaults {
    return {
            'method'      => 'Infernal',
            'cmalign_threads'   => 1,
           };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";
    $self->param('gene_tree', $nc_tree);

    my %model_id_hash = ();
    my @no_acc_members = ();
    foreach my $member (@{$nc_tree->get_all_Members}) {
        my $description = $member->description;
        unless (defined($description) && $description =~ /Acc\:(\w+)/) {
            warn "No accession for [$description]";
            push @no_acc_members, $member->dbID;
        } else {
            $model_id_hash{$1} = 1;
        }
    }
    unless (keys %model_id_hash) {
        die "No Accs found for gene_tree_id $nc_tree_id : ", join ",",@no_acc_members;
    }
    if (scalar keys %model_id_hash > 1) {
        print STDERR "WARNING: More than one model: ", join(",",keys %model_id_hash), "\n";
    }

    $self->param('input_fasta', $self->dump_sequences_to_workdir($nc_tree));

    $self->param('infernal_starttime', time()*1000);
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;

    $self->run_infernal;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores nctree
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->parse_and_store_alignment_into_tree;
    print STDERR "ALIGNMENT ID IS: ", $self->param('alignment_id'), "\n";
    $self->store_refined_profile if $self->param('refined_profile');
    $self->_store_aln_tags;

    $self->call_one_hc('alignment');

    my $gene_tree_id = $self->param('gene_tree_id');

    $self->dataflow_output_id ( {
                                 'gene_tree_id' => $gene_tree_id,
                                 'alignment_id' => $self->param('alignment_id'),
                                },1
                              );
}


##########################################
#
# internal methods
#
##########################################

1;

sub dump_sequences_to_workdir {
  my $self = shift;
  my $cluster = shift;

  my $root_id = $cluster->root_id;
  my $fastafile = $self->worker_temp_directory . "/cluster_" . $root_id . ".fasta";
  print STDERR "fastafile: $fastafile\n" if($self->debug);

  my $tag_gene_count = scalar(@{$cluster->get_all_leaves});
  if ($tag_gene_count < 2) {
      $self->input_job->autoflow(0);
      $self->complete_early("Only one member for cluster [$root_id]");
  }
  print STDERR "Counting number of members\n" if ($self->debug);

  my $count = $cluster->print_sequences_to_file( $fastafile, -uniq_seq => 1, -id_type => 'SEQUENCE');

  if ($count == 1) {
    $self->update_single_peptide_tree($cluster);
    $self->param('single_peptide_tree', 1);
  }

  my $perc_unique = ($count / $tag_gene_count) * 100;
  print "Percent unique sequences: $perc_unique ($count / $tag_gene_count)\n" if ($self->debug);

  return $fastafile;
}

sub update_single_peptide_tree {
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->compara_dba->get_GeneTreeNodeAdaptor->store_node($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}

sub run_infernal {
  my $self = shift;

  my $stk_output = $self->worker_temp_directory . "/output.stk";
  my $nc_tree_id = $self->param('gene_tree_id');

  my $cmalign_exe = $self->require_executable('cmalign_exe');

  my $model_id = $self->param('gene_tree')->get_value_for_tag('model_id') or $self->throw("'model_id' tag for this tree is not defined");
  $self->param('model_id', $model_id );

  print STDERR "Model_id : $model_id\n" if ($self->debug);
  my $ret1 = $self->dump_model( $model_id );
  if ($ret1) {
    $self->param('gene_tree')->release_tree;
    $self->param('gene_tree', undef);
    $self->input_job->transient_error(0);
    die ("Failed to find '$model_id' both in the 'hmm_profile' table");
  }


  my $cmd = $cmalign_exe;
  my $infernal_mxsize = $self->param('infernal_mxsize');
  # infernal -o cluster_6357.stk RF00599_profile.cm cluster_6357.fasta

  $cmd .= " --mxsize $infernal_mxsize " if(defined $self->param('infernal_mxsize') && ($self->input_job->retry_count >= 1)); # large alignments FIXME separate Infernal_huge
  $cmd .= " -o " . $stk_output;
  $cmd .= " --cpu " . $self->param_required('cmalign_threads');
  $cmd .= " " . $self->param('profile_file');
  $cmd .= " " . $self->param('input_fasta');

  $self->run_command($cmd, { die_on_failure => 1 });

  # cmbuild --refine the alignment
  ######################
  # Attempt to refine the alignment before building the CM using
  # expectation-maximization (EM). A CM is first built from the
  # initial alignment as usual. Then, the sequences in the alignment
  # are realigned optimally (with the HMM banded CYK algorithm,
  # optimal means optimal given the bands) to the CM, and a new CM is
  # built from the resulting alignment. The sequences are then
  # realigned to the new CM, and a new CM is built from that
  # alignment. This is continued until convergence, specifically when
  # the alignments for two successive iterations are not significantly
  # different (the summed bit scores of all the sequences in the
  # alignment changes less than 1% be- tween two successive
  # iterations). The final alignment (the alignment used to build the
  # CM that gets written to cmfile) is written to <f>.

  # cmbuild --refine output.stk.new -F mir-32_profile.cm.new output.stk
  my $refined_stk_output = $stk_output . ".refined";
  my $refined_profile = $self->param('profile_file') . ".refined";

  my $cmbuild_exe = $self->require_executable('cmbuild_exe');

  $cmd = $cmbuild_exe;
  #Increasing the maximum allowable DP matrix size to <x> Mb  default(2048.0)
  # This may be necessary if cmbuild crashes.
  if(defined $self->param('infernal_mxsize') && ($self->input_job->retry_count >= 1)){
    $cmd .= " --mxsize $infernal_mxsize"; # large alignments FIXME separate Infernal_huge
  }
  $cmd .= " --refine $refined_stk_output";
  $cmd .= " -F $refined_profile";
  $cmd .= " $stk_output";

  my $cmd_return_value = $self->run_command($cmd);
  my $log_message = $cmd_return_value->err;

  #Deals with error: Z got insanely large. It bypass the refined profiles and uses the original ones.
  if ($log_message =~ /Error: Calculating QDBs, Z got insanely large /){
      $self->warning("Could not refine the alignment: $log_message");
      $self->param('stk_output', $stk_output);

  } elsif ($cmd_return_value->exit_code) {
      die sprintf("Could not run %s, got %s\nSTDOUT %s\nSTDERR %s\n", $cmd, $cmd_return_value->exit_code, $cmd_return_value->out, $log_message);

  }
  else{
      $self->param('stk_output', $refined_stk_output);
      $self->param('refined_profile', $refined_profile);
  }

  return 0;
}

sub dump_model {
    my ($self, $model_id) = @_;

    my $nc_profile_obj = $self->compara_dba->get_HMMProfileAdaptor()->fetch_all_by_model_id_type($model_id, 'infernal')->[0];
    my $nc_profile = $nc_profile_obj->profile();

    unless (defined($nc_profile)) {
        return 1;
    }
    my $profile_file = $self->worker_temp_directory . "/" . $model_id . "_profile.cm";
    $self->_spurt($profile_file, $nc_profile);

    $self->param('profile_file', $profile_file);
    $self->param('profile_name', $nc_profile_obj->name);
    return 0;
}

sub parse_and_store_alignment_into_tree {
  my $self = shift;
  my $stk_output =  $self->param('stk_output');
  my $tree = $self->param('gene_tree');

  return unless($stk_output);

  #
  # parse SS_cons lines and store into nc_tree_tag
  #
  open (STKFILE, $stk_output) or $self->throw("Couldnt open STK file [$stk_output]");
  my $ss_cons_string = '';
  while(<STKFILE>) {
    next unless ($_ =~ /SS_cons/);
    my $line = $_;
    $line =~ /\#=GC\s+SS_cons\s+(\S+)\n/;
    $self->throw("Malformed SS_cons line") unless (defined($1));
    $ss_cons_string .= $1;
  }
  close(STKFILE);

  #
  # parse alignment file into hash: combine alignment lines
  #
  my %align_hash;

  # fasta format
  my $aln_io = Bio::AlignIO->new
    (-file => "$stk_output",
     -format => 'stockholm');
  my $aln = $aln_io->next_aln || die "Could not get align";
  foreach my $seq ($aln->each_seq) {
    $align_hash{$seq->display_id} = $seq->seq;
  }
  $aln_io->close;

  my $new_align_hash = $self->remove_gaps_in_alignment($ss_cons_string, {%align_hash});
  $self->store_fasta_alignment($new_align_hash);

  my $ss_cons_filtered_string = $self->remove_gaps_in_ss_cons($ss_cons_string);

  $self->param('gene_tree')->store_tag('ss_cons', $ss_cons_string);
  $self->param('gene_tree')->store_tag('ss_cons_filtered', $ss_cons_filtered_string);

  my ($cigar_hash, $alignment_length) = $self->get_cigar_lines({%align_hash});

  $tree->aln_method('infernal');
  $tree->aln_length($alignment_length);

  #
  # align cigar_line to member and store
  #
  foreach my $member (@{$tree->get_all_leaves}) {
    if ($align_hash{$member->sequence_id} eq "") {
      $self->throw("infernal produced an empty cigar_line for ".$member->stable_id."\n");
    }

    $member->cigar_line($cigar_hash->{$member->sequence_id});

    ## Check that the cigar length (Ms) matches the sequence length
    my @cigar_match_lengths = map { $_ || 1 } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
    my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
    my $member_sequence = $member->sequence(); $member_sequence =~ s/\*//g;
    if ($seq_cigar_length != length($member_sequence)) {
        $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
    }

  }
  $self->compara_dba->get_GeneAlignAdaptor->store($tree);
  return undef;
}

sub get_cigar_lines {
    my ($self, $align_hash) = @_;
    #
    # convert alignment string into a cigar_line
    #
    my $cigar_hash;
    my $alignment_length;
    foreach my $id (keys %$align_hash) {
        my $alignment_string = $align_hash->{$id};
        unless (defined $alignment_length) {
            $alignment_length = length($alignment_string);
        } else {
            if ($alignment_length != length($alignment_string)) {
                $self->throw("While parsing the alignment, some id did not return the expected alignment length\n");
            }
        }

        # From the Infernal UserGuide:
        # ###########################
        # In the aligned sequences, a '.' character indicates an inserted column
        # relative to consensus; the '.' character is an alignment pad. A '-'
        # character is a deletion relative to consensus.  The symbols in the
        # consensus secondary structure annotation line have the same meaning
        # that they did in a pairwise alignment from cmsearch. The #=GC RF line
        # is reference annotation. Non-gap characters in this line mark
        # consensus columns; cmalign uses the residues of the consensus sequence
        # here, with UPPER CASE denoting STRONGLY CONSERVED RESIDUES, and LOWER
        # CASE denoting WEAKLY CONSERVED RESIDUES. Gap characters (specifically,
        # the '.' pads) mark insertions relative to consensus. As described below,
        # cmbuild is capable of reading these RF lines, so you can specify which
        # columns are consensus and which are inserts (otherwise, cmbuild makes
        # an automated guess, based on the frequency of gaps in each column)
        $alignment_string =~ s/\./\-/g;            # Infernal returns dots even though they are gaps
        $cigar_hash->{$id} = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string(uc($alignment_string));
    }
    return ($cigar_hash, $alignment_length);
}

sub store_fasta_alignment {
    my ($self, $new_align_hash) = @_;

    my ($new_cigar_hash, $alignment_length) = $self->get_cigar_lines($new_align_hash);

    my $aln = $self->param('gene_tree')->deep_copy();
    my %original_members = map {$_->stable_id => $_} @{$self->param('gene_tree')->get_all_leaves};

    for my $member (@{$aln->get_all_leaves}) {

        if ($new_align_hash->{$member->sequence_id} eq "") {
            $self->throw("infernal produced an empty cigar_line for ". $member->stable_id . "\n");
        }
        print STDERR "NEW CIGAR LINE: ", $new_cigar_hash->{$member->sequence_id}, "\n";
        $member->cigar_line($new_cigar_hash->{$member->sequence_id});

        ## Check that the cigar length (Ms) matches the sequence length
#         my @cigar_match_lengths = map { if ($_ eq '') {$_ = 1} else {$_ = $_;} } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
#         my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
#         my $member_sequence = $member->other_sequence('filtered');
#         $member_sequence =~ s/\*//g;
#         print STDERR "MEMBER_SEQUENCE: $member_sequence\n";
#         print STDERR "+++ $seq_cigar_length +++ \n";#, length($member_sequence) , "\n";
#         if ($seq_cigar_length != length($member_sequence)) {
#             $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
#         }
    }


    bless $aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet';
    $aln->seq_type('filtered');
    $aln->aln_method('infernal');
    $aln->aln_length($alignment_length);

    my $sequence_adaptor = $self->compara_dba->get_SequenceAdaptor;
    my $n_deleted_members = 0;
    for my $member (@{$aln->get_all_Members}) {
        my $seq = $new_align_hash->{$member->sequence_id};
        $seq =~ s/-//g;
        unless ($seq) {
            # After filtering the sequence may become empty
            $self->compara_dba->get_GeneTreeNodeAdaptor->remove_seq_member($original_members{$member->stable_id});
            # We can call remove_Member because the latter creates a new
            # array-ref within the MemberSet, so the cursor of the above
            # for loop is unaffected
            $aln->remove_Member($member);
            $n_deleted_members++;
            next;
        }
        $sequence_adaptor->store_other_sequence($member, $seq, 'filtered');
    }

    if ($n_deleted_members) {
        # Empty the cached array of members, so that $self->param('gene_tree')->get_all_Members doesn't see the removed members any more
        delete $self->param('gene_tree')->{'_member_array'};
        # Adjust the gene_count
        $self->param('gene_tree')->store_tag('gene_count', $self->param('gene_tree')->get_value_for_tag('gene_count')-$n_deleted_members);
    }

    $self->compara_dba->get_GeneAlignAdaptor->store($aln);
    $self->param('alignment_id', $aln->dbID);
#    $aln->root->release_tree();
#    $aln->clear();

    return;
}

sub remove_gaps_in_ss_cons {
    my ($self, $str) = @_;
    $str =~ s/\.//g;
    return $str;
}

sub get_filter_positions {
    my ($self, $str) = @_;
    my @positions = ();
    for (my $i = 0; $i < length($str); $i++) {
        if (substr ($str, $i, 1) eq ".") {
            push @positions, $i;
        }
    }
    return [reverse @positions];
}


sub remove_gaps_in_alignment {
    my ($self, $ss_cons, $align_hash) = @_;

    my $filter_positions = $self->get_filter_positions($ss_cons);
    for my $s (keys %$align_hash) {
        my $seq = $align_hash->{$s};
        for my $pos (@$filter_positions) {
            substr ($seq, $pos, 1, '');
        }
        $align_hash->{$s} = $seq;
    }

    return $align_hash;
}

sub _store_aln_tags {
    my $self = shift;
    my $tree = $self->param('gene_tree');
    return unless($tree);

    print STDERR "Storing Alignment tags...\n" if ($self->debug());
    my $sa = $tree->get_SimpleAlign;

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment runtime.
    if ($self->param('infernal_starttime')) {
        my $aln_runtime = int(time()*1000-$self->param('infernal_starttime'));
        $tree->store_tag("aln_runtime",$aln_runtime);
    }

    # Alignment residue count.
    my $aln_num_residues = $sa->num_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

}

sub store_refined_profile {
    my ($self) = @_;
    my $model_id = $self->param('model_id');
    my $type = "infernal-refined";
    my $refined_profile_file = $self->param('refined_profile');
    my $hmmProfile_Adaptor = $self->compara_dba->get_HMMProfileAdaptor();
    my $name = $self->param('profile_name');

    my $refined_profile = $self->_slurp($refined_profile_file);

    my $new_profile = Bio::EnsEMBL::Compara::HMMProfile->new();
    $new_profile->model_id($model_id);
    $new_profile->name($name);
    $new_profile->type($type);
    $new_profile->profile($refined_profile);

    $hmmProfile_Adaptor->store($new_profile);
}

1;
