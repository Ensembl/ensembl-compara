=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA

=head1 DESCRIPTION

This module is an abstract RunnableDB used to run a multiple alignment on a
gene tree. It is currently implemented in Mafft and MCoffee.

The parameter 'gene_tree_id' is obligatory.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA;

use strict;
use warnings;

use IO::File;
use File::Basename;
use File::Path;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Utils::Cigars;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'escape_branch'         => -1,
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

    if (defined $self->param('escape_branch') and $self->input_job->retry_count >= 3) {
        my $jobs = $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
        if (scalar(@$jobs)) {
            $self->input_job->incomplete(0);
            die "The MSA failed 3 times. Trying another method.\n";
        }
    }


    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
    $self->param('protein_tree', $self->param('tree_adaptor')->fetch_by_dbID($self->param('gene_tree_id')));
    $self->param('protein_tree')->preload();

  # No input specified.
  if (!defined($self->param('protein_tree'))) {
    $self->post_cleanup;
    $self->throw("no input protein_tree");
  }

  print "RETRY COUNT: ".$self->input_job->retry_count()."\n";

  #
  # A little logic, depending on the input params.
  #
  # Protein Tree input.
    #$self->param('protein_tree')->flatten_tree; # This makes retries safer
    # The extra option at the end adds the exon markers
    $self->param('input_fasta', $self->dumpProteinTreeToWorkdir($self->param('protein_tree')) );

#  if ($self->param('redo')) {
#    # Redo - take previously existing alignment - post-process it
#    my $other_trees = $self->param('tree_adaptor')->fetch_all_linked_trees($self->param('protein_tree'));
#    my ($other_tree) = grep {$_->clusterset_id eq $self->param('redo')} @$other_trees;
#    if ($other_tree) {
#        my $redo_sa = $other_tree->get_SimpleAlign(-id_type => 'MEMBER');
#        $redo_sa->set_displayname_flat(1);
#        $self->param('redo_alnname', $self->worker_temp_directory . $self->param('gene_tree_id').'.fasta' );
#        my $alignout = Bio::AlignIO->new(-file => ">".$self->param('redo_alnname'), -format => "fasta");
#        $alignout->write_aln( $redo_sa );
#    }
#  }

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

    return if ($self->param('single_peptide_tree'));
    $self->param('msa_starttime', time()*1000);
    $self->run_msa;
}


=head2 write_output
`
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
    } else {
        my $method = ref($self);
        $method =~ /::([^:]*)$/;
        $self->param('protein_tree')->aln_method($1);

        my $aln_ok = $self->parse_and_store_alignment_into_proteintree;
        unless ($aln_ok) {
            # Probably an ongoing MEMLIMIT
            # We have 10 seconds to dataflow and exit;
            my $new_job = $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
            if (scalar(@$new_job)) {
                $self->input_job->incomplete(0);
                $self->input_job->lethal_for_worker(1);
                die 'Probably not enough memory. Switching to the _himem analysis.';
            } else {
                die 'Error in the alignment but cannot switch to an analysis with more memory.';
            }
        }
    }

    $self->compara_dba->get_GeneAlignAdaptor->store($self->param('protein_tree'));
    # Store various alignment tags:
    $self->_store_aln_tags($self->param('protein_tree'));

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
    my $tempdir = $self->worker_temp_directory;
    print "TEMP DIR: $tempdir\n" if ($self->debug);

    my $msa_output = $tempdir . 'output.mfa';
    $msa_output =~ s/\/\//\//g;
    $self->param('msa_output', $msa_output);

    my $cmd = $self->get_msa_command_line;

    $self->compara_dba->dbc->disconnect_when_inactive(1);

    print STDERR "Running:\n\t$cmd\n" if ($self->debug);
    my $ret = system("cd $tempdir; $cmd");
    print STDERR "Exit status: $ret\n" if $self->debug;
    if($ret) {
        my $system_error = $!;

        $self->post_cleanup;
        die "Failed to execute [$cmd]: $system_error ";
    }

    $self->compara_dba->dbc->disconnect_when_inactive(0);
}

########################################################
#
# ProteinTree input/output section
#
########################################################

sub update_single_peptide_tree {
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_Members}) {
    $member->cigar_line(length($member->sequence)."M");
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
    $tree->aln_length(length($member->sequence));
  }
}

sub dumpProteinTreeToWorkdir {
  my $self = shift;
  my $tree = shift;

  my $fastafile =$self->worker_temp_directory.'proteintree_'.($tree->root_id).'.fasta';

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if (-e $fastafile);
  print("fastafile = '$fastafile'\n") if ($self->debug);

  my $num_pep = $tree->print_sequences_to_file(-file => $fastafile, -uniq_seq => 1, -id_type => 'SEQUENCE');

  if ($num_pep <= 1) {
    $self->update_single_peptide_tree($tree);
    $self->param('single_peptide_tree', 1);
  }

  return $fastafile;
}


sub parse_and_store_alignment_into_proteintree {
  my $self = shift;


  return 1 if ($self->param('single_peptide_tree'));

  my $msa_output =  $self->param('msa_output');
  my $format = 'fasta';
  my $tree = $self->param('protein_tree');

  return 0 unless($msa_output and -e $msa_output);

  #
  # Read in the alignment using Bioperl.
  #
  use Bio::AlignIO;
  my $alignio = Bio::AlignIO->new(-file => $msa_output, -format => $format);
  my $aln = $alignio->next_aln();
  my %align_hash;
  foreach my $seq ($aln->each_seq) {
    my $id = $seq->display_id;
    my $sequence = $seq->seq;
    $self->throw("Error fetching sequence from output alignment") unless(defined($sequence));
    print STDERR "# ", $sequence, "\n" if ($self->debug);
    $align_hash{$id} = $sequence;
    # Lowercase aminoacids in the output alignment -- decaf has found overalignments
    if (my @overalignments = $sequence =~ /([gastplimvdneqfywkrhcx]+)/g) {
      eval { $tree->tree->store_tag('decaf.'.$id, join(":",@overalignments));};
    }
  }

  #
  # Convert alignment strings into cigar_lines
  #
  my $alignment_length;
  my %align_string;
  foreach my $id (keys %align_hash) {
      next if ($id eq 'cons');
    my $alignment_string = $align_hash{$id};
    unless (defined $alignment_length) {
      $alignment_length = length($alignment_string);
    } else {
      if ($alignment_length != length($alignment_string)) {
        $self->throw("While parsing the alignment, some id did not return the expected alignment length\n");
      }
    }
    # Call the method to do the actual conversion
    $align_hash{$id} = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string(uc($alignment_string));
    $align_string{$id} = uc($alignment_string);
    #print "The cigar_line of $id is: ", $align_hash{$id}, "\n";
  }
  $tree->aln_length($alignment_length);

  #
  # Align cigar_lines to members and store
  #
  foreach my $member (@{$tree->get_all_Members}) {
      # Redo alignment is member_id based, new alignment is sequence_id based
      if ($align_hash{$member->sequence_id} eq "" && $align_hash{$member->member_id} eq "") {
        #$self->throw("empty cigar_line for ".$member->stable_id."\n");
        $self->warning("empty cigar_line for ".$member->stable_id."\n");
        return 0;
      }
      # Redo alignment is member_id based, new alignment is sequence_id based
      $member->cigar_line($align_hash{$member->sequence_id} || $align_hash{$member->member_id});

      ## Check that the cigar length (Ms) matches the sequence length
      # Take the M lengths into an array
      my @cigar_match_lengths = map { if ($_ eq '') {$_ = 1} else {$_ = $_;} } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
      # Sum up the M lengths
      my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
      my $member_sequence = $member->sequence;
      if ($seq_cigar_length != length($member_sequence)) {
        print $member->sequence_id.":$seq_cigar_length:".length($member_sequence).":".$member_sequence."\n".$member->cigar_line."\n".$align_string{$member->sequence_id}."\n" if ($self->debug);
        $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
      }
  }
  return 1;
}


sub _store_aln_tags {
    my $self = shift;
    my $tree = shift;

    print "Storing Alignment tags...\n";

    my $sa = $tree->get_SimpleAlign;

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment runtime.
    if ($self->param('msa_starttime')) {
        my $aln_runtime = int(time()*1000-$self->param('msa_starttime'));
        $tree->store_tag("aln_runtime",$aln_runtime);
    }

    # Alignment residue count.
    my $aln_num_residues = $sa->no_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

}


1;
