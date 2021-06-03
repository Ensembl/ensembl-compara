=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA

=head1 DESCRIPTION

This module is an abstract RunnableDB used to run a multiple alignment on a
gene tree. It is currently implemented in Mafft and MCoffee.

The parameter 'gene_tree_id' is obligatory.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA;

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Path;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        escape_branch   => undef,
        cmd_max_runtime => undef,
        check_seq       => 1,
        tmp_dir         => undef,
    };
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

    if (defined $self->param('escape_branch')) {
      my $max_retry_count = $self->input_job->analysis->max_retry_count;
      $max_retry_count //= $self->db->hive_pipeline->hive_default_max_retry_count if $self->db;
      if (defined $max_retry_count && ($self->input_job->retry_count >= $max_retry_count)) {
        $self->dataflow_output_id(undef, $self->param('escape_branch'));
        $self->input_job->autoflow(0);
        $self->complete_early("The MSA failed $max_retry_count times. Trying another method.");
      }
    }


    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
    $self->param('protein_tree', $self->param('tree_adaptor')->fetch_by_dbID($self->param_required('gene_tree_id')));
    $self->throw("no input protein_tree") unless $self->param('protein_tree');

    print "RETRY COUNT: ".$self->input_job->retry_count()."\n" if ($self->debug);

    my $tmp_dir = $self->param('tmp_dir') || $self->worker_temp_directory;
    $self->param('tmp_dir', $tmp_dir);

    $self->param('input_fasta', $self->dumpProteinTreeToWorkdir($self->param('protein_tree')) );

  #
  # Ways to fail the job before running.
  #

  # Error writing input Fasta file.
  if (!$self->param('input_fasta')) {
    $self->post_cleanup;
    $self->throw("error writing input Fasta");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs the alignment
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    $self->param('msa_starttime', time()*1000);
    return if ($self->param('single_peptide_tree'));
    $self->run_msa;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse the alignment and update protein_tree_member tables
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    if ($self->param('single_peptide_tree')) {
        $self->param('protein_tree')->aln_method('identical_seq');
        $self->param('protein_tree')->aln_length($self->param('protein_tree')->aln_length);
    } else {
        my $method = ref($self);
        $method =~ /::([^:]*)$/;
        $self->param('protein_tree')->aln_method($1);

        my $aln_ok = $self->parse_and_store_alignment_into_proteintree;
        unless ($aln_ok) {
            # Probably an ongoing MEMLIMIT
            # Let's wait a bit to let LSF kill the worker as it should
            sleep 30;
            # If we're still there, there is something weird going on.
            # Perhaps not a MEMLIMIT, after all. Let's die and hope that
            # next run will be better
            die "There is no output file !\n";
        }
    }

    # The second parameter is 1 to make sure we don't have "leftovers" from
    # previous runs
    $self->compara_dba->get_GeneAlignAdaptor->store($self->param('protein_tree'), 1);

    # Store various alignment tags:
    $self->_store_aln_tags($self->param('protein_tree'));

}

# Wrapper around Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks
# NB: this will be testing $self->param('gene_tree_id')
sub post_healthcheck {
    my $self = shift;
    Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks::_embedded_call($self, 'alignment');
}


sub post_cleanup {
    my $self = shift;

    if($self->param('protein_tree')) {
        $self->param('protein_tree')->release_tree;
        $self->param('protein_tree', undef);
    }

    $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}

##########################################
#
# internal methods
#
##########################################


sub run_msa {
    my $self = shift;
    my $input_fasta = $self->param('input_fasta');

    # Make a temp dir.
    my $tempdir = $self->param('tmp_dir');
    print "TEMP DIR: $tempdir\n" if ($self->debug);

    my $msa_output = sprintf("$tempdir/output.%08d.mfa", $self->input_job->dbID);
    $msa_output =~ s/\/\//\//g;
    $self->param('msa_output', $msa_output);

    my $cmd = $self->get_msa_command_line;

    my $cmd_out = $self->run_command("cd $tempdir; $cmd", { timeout => $self->param('cmd_max_runtime') });

    if ($cmd_out->exit_code == -2) {
        $self->dataflow_output_id(undef, -2);
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("The command is taking more than %d seconds to complete.\n", $self->param('cmd_max_runtime')));
    } elsif ($cmd_out->exit_code) {
        # I know ... The following should be in the sub-class MCoffee
        if ($cmd_out->err =~ /The Program .* Needed by T-COFFEE Could not be found/) {
            # If the path cannot be found, retrying the job won't help (and
            # we won't risk the escape route being triggered)
            $self->input_job->transient_error(0);
        }
        $cmd_out->die_with_log;
    }
}

########################################################
#
# ProteinTree input/output section
#
########################################################

sub update_single_peptide_tree {
  my $self   = shift;
  my $tree   = shift;

  $tree->expand_subtrees;  # TODO: remove this additional call once ENSCOMPARASW-4276 is resolved
  foreach my $member (@{$tree->get_all_Members}) {
    $member->cigar_line(length($member->sequence)."M");
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
    $tree->aln_length(length($member->sequence));
  }
}

sub dumpProteinTreeToWorkdir {
  my $self = shift;
  my $tree = shift;

  my $fastafile = $self->param('tmp_dir').'/proteintree_'.($tree->root_id).'.fasta';

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if (-e $fastafile);
  print("fastafile = '$fastafile'\n") if ($self->debug);

  $tree->expand_subtrees;   # In case we are given a supertree
  my $num_pep = $tree->print_sequences_to_file($fastafile, -uniq_seq => 1, -id_type => 'SEQUENCE');

  if ($num_pep <= 1) {
    $self->update_single_peptide_tree($tree);
    $self->param('single_peptide_tree', 1);
  } else {
    $self->param('single_peptide_tree', 0);
  }

  return $fastafile;
}


sub parse_and_store_alignment_into_proteintree {
  my $self = shift;


  return 1 if ($self->param('single_peptide_tree'));

  my $msa_output =  $self->param('msa_output');

  return 0 unless($msa_output and -e $msa_output);

  $self->param('protein_tree')->load_cigars_from_file($msa_output, -FORMAT => 'fasta', -ID_TYPE => 'SEQUENCE', -CHECK_SEQ => $self->param('check_seq'));

  return 1;
}


sub _store_aln_tags {
    my $self = shift;
    my $tree = shift;

    print "Storing Alignment tags...\n";

    my $sa = $tree->get_SimpleAlign(-SEQ_TYPE => $self->param('cdna') ? 'cds' : undef);

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment runtime.
    if ($self->param('msa_starttime')) {
        my $aln_runtime = int(time()*1000-$self->param('msa_starttime'));
        $tree->store_tag("aln_runtime",$aln_runtime);
    }

    # Alignment residue count.
    my $aln_num_residues = $sa->num_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

    $tree->store_tag('aln_length', $tree->aln_length);
}


1;
