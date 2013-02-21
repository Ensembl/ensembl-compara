=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::MSA

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

package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::MSA;

use strict;

use IO::File;
use File::Basename;
use File::Path;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::SearchIO;
use Bio::DB::Fasta;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $db;

sub param_defaults {
    return {
        'use_exon_boundaries'   => 0,                       # careful: 0 and undef have different meanings here
        'escape_branch'         => -1,
    };
}

sub load_allclusters{
    my $self = shift @_;

    my $hcluster_parse_out = $self->param('hcluster_parse');
    my %allclusters;
    $self->param('allclusters', \%allclusters);

    open(FILE, $hcluster_parse_out) or die "Could not open '$hcluster_parse_out' for reading : $!";
    while (<FILE>) {
      # 330   3       UPI00015FF1FD,UPI000000093E,UPI0001C22EF4
      chomp $_;
      my ($cluster_id,$cluster_size,$cluster_list) = split("\t",$_);
      # If it's a singleton, we don't store it as a protein tree
      next if ($cluster_size < 3); 
      $cluster_list    		=~ s/\,$//;
      $cluster_list 		=~ s/_[0-9]*//g;
      my @cluster_list 		= split(",", $cluster_list);
      $allclusters{$cluster_id} = { 'members' => \@cluster_list };
    }

return;
}

sub create_fasta_db {
    my $self =shift @_;

    my $fasta_file = $self->param('fasta_file');
    $db            = Bio::DB::Fasta->new($fasta_file);

return;
}

sub prepare_input_fasta {
    my $self =shift @_;

    my $blast_tmp_dir = $self->param('blast_tmp_dir');    
    my $cluster_id    = $self->param('cluster_id');
    my $allclusters   = $self->param('allclusters');
    
    my @genes         = @{$allclusters->{$cluster_id}->{'members'}};
    my $cluster_fasta = $blast_tmp_dir.'/cluster_'.$cluster_id.'.fasta'; 

    open(FILE, ">$cluster_fasta") or die "Could not open '$cluster_fasta' for writing : $!";

    foreach my $gene (@genes){
	
	my $seq = $db->seq($gene);

	print FILE ">".$gene."\n";
	print FILE $seq."\n";
    }
    close FILE;

    $self->param('input_fasta',$cluster_fasta); 	

return;
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for mcoffee from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

    $self->load_allclusters;
    $self->create_fasta_db;
    $self->prepare_input_fasta;    

    if (defined $self->param('escape_branch') and $self->input_job->retry_count >= 3) {
        my $jobs = $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
        if (scalar(@$jobs)) {
            $self->input_job->incomplete(0);
            die "The MSA failed 3 times. Trying another method.\n";
        }
    }

#x    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
#x    $self->param('protein_tree', $self->param('tree_adaptor')->fetch_by_dbID($self->param('gene_tree_id')));
#x    $self->param('protein_tree')->preload();

  # No input specified.
#x  if (!defined($self->param('protein_tree'))) {
#x    $self->post_cleanup;
#x    $self->throw("MCoffee job no input protein_tree");
#x  }

  print "RETRY COUNT: ".$self->input_job->retry_count()."\n";

  print "MCoffee alignment method: ".$self->param('method')."\n";

  #
  # A little logic, depending on the input params.
  #
  # Protein Tree input.
    #$self->param('protein_tree')->flatten_tree; # This makes retries safer
    # The extra option at the end adds the exon markers
#x    $self->param('input_fasta', $self->dumpProteinTreeToWorkdir($self->param('protein_tree'), $self->param('use_exon_boundaries')) );

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
    $self->throw("MCoffee: error writing input Fasta");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs MCOFFEE
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

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   parse mcoffee output and update protein_tree_member tables
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    unlink $self->param('input_fasta');

=pod
    if ($self->param('single_peptide_tree')) {
        $self->param('protein_tree')->aln_method('identical_seq');
    } else {
        my $method = ref($self);
        $method =~ /::([^:]*)$/;
        $self->param('protein_tree')->aln_method($1);
    }
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

    $self->compara_dba->get_AlignedMemberAdaptor->store($self->param('protein_tree'));
    # Store various alignment tags:
    $self->_store_aln_tags($self->param('protein_tree'));
=cut
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

    my $msa_dir     = $self->param('msa_dir');

    chdir $msa_dir;
    my $files_count  = `find ./ -type f -name '*.msa' | wc -l`;

    if ($files_count < 1000){
       $msa_dir      = $msa_dir.'/msa_0';
    }
    else {
       my $remainder = $files_count % 1000;
       my $quotient  = ($files_count - $remainder)/1000;
       $msa_dir      = $msa_dir.'/msa_'.$quotient; 
    }

    unless (-e $msa_dir) { ## Make sure the directory exists
        print STDERR "$msa_dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $msa_dir (0755)\n" if ($self->debug());
        die "Impossible create directory $msa_dir\n" unless (mkdir($msa_dir, 0755));
    }
	
     my $msa_output  = $msa_dir.'/cluster_'.$self->param('cluster_id').'_output.msa';
     #my $msa_output =~ s/\/\//\//g;
     $self->param('msa_output', $msa_output);
     my $cmd = $self->get_msa_command_line;

     $self->compara_dba->dbc->disconnect_when_inactive(1);

     print STDERR "Running:\n\t$cmd\n" if ($self->debug);
     my $ret = system("cd $msa_dir; $cmd");

     print STDERR "Exit status: $ret\n" if $self->debug;
	if($ret) {
         my $system_error = $!;         
         $self->post_cleanup;
         die "Failed to execute [$cmd]: $system_error ";
     }
    $self->compara_dba->dbc->disconnect_when_inactive(0);
=pod
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
=cut
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
  my $use_exon_boundaries = shift;

  my $fastafile =$self->worker_temp_directory.($use_exon_boundaries ? 'proteintree_exon_' : 'proteintree_').($tree->root_id).'.fasta';

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if((-e $fastafile) and not $use_exon_boundaries);
  print("fastafile = '$fastafile'\n") if ($self->debug);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write!");

  my $seq_id_hash = {};
  my $residues = 0;
  my $member_list = $tree->get_all_Members;

#  $self->param('tag_gene_count', scalar(@{$member_list}) );
  my $has_canonical_issues = 0;
  foreach my $member (@{$member_list}) {

    # Double-check we are only using canonical
    my $gene_member; my $canonical_member = undef;
    eval {
      $gene_member = $member->gene_member; 
      $canonical_member = $gene_member->get_canonical_Member;
    };
    if($self->debug() and $@) { print "ERROR IN EVAL (node_id=".$member->node_id.") : $@"; }
    unless (defined($canonical_member) && ($canonical_member->member_id eq $member->member_id) ) {
      my $canonical_member2 = $gene_member->get_canonical_Member;
      my $clustered_stable_id = $member->stable_id;
      my $canonical_stable_id = $canonical_member->stable_id;
      $tree->store_tag('canon.'.$clustered_stable_id."_".$canonical_stable_id,1);
      $has_canonical_issues++;
    }

      return undef unless ($member->isa("Bio::EnsEMBL::Compara::GeneTreeMember"));
      next if($seq_id_hash->{$member->sequence_id});
      $seq_id_hash->{$member->sequence_id} = 1;

      my $seq = '';
      if ($use_exon_boundaries) {
          $seq = $member->sequence_exon_bounded;
      } else {
          $seq = $member->sequence;
      }
      $residues += $member->seq_length;
      $seq =~ s/(.{72})/$1\n/g;
      chomp $seq;

      print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
  }
  close OUTSEQ;

  $self->throw("Cluster has canonical transcript issues: [$has_canonical_issues]\n") if (0 < $has_canonical_issues);

  if(scalar keys (%$seq_id_hash) <= 1) {
    $self->update_single_peptide_tree($tree);
    $self->param('single_peptide_tree', 1);
  }

  $self->param('tag_residue_count', $residues);
  return $fastafile;
}


sub parse_and_store_alignment_into_proteintree {
  my $self = shift;


  return 1 if ($self->param('single_peptide_tree'));

  my $msa_output =  $self->param('msa_output');
  my $format = 'fasta';
  my $tree = $self->param('protein_tree');

  if (2 == $self->param('use_exon_boundaries')) {
    $msa_output .= ".overaln";
  }
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
    $align_hash{$id} = $self->_to_cigar_line(uc($alignment_string));
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
      my $member_sequence = $member->sequence; $member_sequence =~ s/\*//g;
      if ($seq_cigar_length != length($member_sequence)) {
        print $member_sequence."\n".$member->cigar_line."\n" if ($self->debug);
        $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
      }
  }
  return 1;
}

# Converts the given alignment string to a cigar_line format.
sub _to_cigar_line {
    my $self = shift;
    my $alignment_string = shift;

    $alignment_string =~ s/\-([A-Z])/\- $1/g;
    $alignment_string =~ s/([A-Z])\-/$1 \-/g;
    my @cigar_segments = split " ",$alignment_string;
    my $cigar_line = "";
    foreach my $segment (@cigar_segments) {
      my $seglength = length($segment);
      $seglength = "" if ($seglength == 1);
      if ($segment =~ /^\-+$/) {
        $cigar_line .= $seglength . "D";
      } else {
        $cigar_line .= $seglength . "M";
      }
    }
    return $cigar_line;
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
