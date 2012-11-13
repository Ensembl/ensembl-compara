#
# You may distribute this module under the same terms as perl itself
#
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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::Infernal;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;

use Bio::AlignIO;
use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::Member;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'method'      => 'Infernal',
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

    $self->input_job->transient_error(0);
    my $nc_tree_id = $self->param('gene_tree_id') || die "'gene_tree_id' is an obligatory numeric parameter\n";
    $self->input_job->transient_error(1);

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";

#     my $n_nodes = $nc_tree->get_tagvalue('gene_count');
#     if ($n_nodes == 1) {
#         die "Only one member in tree $nc_tree_id";
#     }

    $self->param('nc_tree', $nc_tree);

    $self->param('model_id_hash', {});

    $self->param('input_fasta', $self->dump_sequences_to_workdir($nc_tree));

    print STDERR Dumper $self->param('model_id_hash') if ($self->debug);

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
    $self->_store_aln_tags;

    my $gene_tree_id = $self->param('gene_tree_id');

    $self->dataflow_output_id ( {
                                 'gene_tree_id' => $gene_tree_id,
                                },3
                              );
    $self->dataflow_output_id ( {
                                 'gene_tree_id' => $gene_tree_id,
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

  print STDERR Dumper $cluster if ($self->debug);

  my $fastafile = $self->worker_temp_directory . "cluster_" . $cluster->root_id . ".fasta";
  print STDERR "fastafile: $fastafile\n" if($self->debug);

  my $seq_id_hash;
  my $residues = 0;
  print STDERR "fetching sequences...\n" if ($self->debug);

  my $root_id = $cluster->root_id;
  my $member_list = $cluster->get_all_leaves;
  if (2 > scalar @$member_list) {
#      $self->input_job->transient_error(0);
      $self->input_job->incomplete(0);
      die ("Only one member for cluster [$root_id]");
#      return undef
  }
  print STDERR "Counting number of members\n" if ($self->debug);
  my $tag_gene_count = scalar(@{$member_list});

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write!");
  my $count = 0;

  my @no_acc_members = ();
  foreach my $member (@{$member_list}) {
    my $sequence_id;
    eval {$sequence_id = $member->sequence_id;};
    if ($@) {
      $DB::single=1;1;
    }
    next if($seq_id_hash->{$sequence_id});
    my $description;
    eval { $description = $member->description; };
    unless (defined($description) && $description =~ /Acc\:(\w+)/) {
      warn ("No accession for [$description]");
      push @no_acc_members, $member->dbID;
    }
    $seq_id_hash->{$sequence_id} = 1;
    $count++;
    my $member_model_id = $1;
    $self->param('model_id_hash')->{$member_model_id} = 1;

    my $seq = $member->sequence;
    $residues += $member->seq_length;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;
    print STDERR $member->sequence_id. "\n" if ($self->debug);
    print OUTSEQ ">". $member->sequence_id. "\n$seq\n";
    print STDERR "sequences $count\n" if ($count % 50 == 0);
  }
  close(OUTSEQ);
  unless (keys %{$self->param('model_id_hash')}) {
      die "No Accs found for gene_tree_id $root_id : ", join ",",@no_acc_members;
  }


  if(scalar keys (%{$seq_id_hash}) <= 1) {
    $self->update_single_peptide_tree($cluster);
    $self->param('single_peptide_tree', 1);
  }

  my $this_hash_count = scalar keys %$seq_id_hash;
  my $perc_unique = ($this_hash_count / $tag_gene_count) * 100;
  print "tag_gene_count $tag_gene_count\n";
  print "Percent unique sequences: $perc_unique ($this_hash_count / $tag_gene_count)\n" if ($self->debug);

  return $fastafile;
}

sub update_single_peptide_tree {
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    next unless($member->sequence);
    $DB::single=1;1;
    $member->cigar_line(length($member->sequence)."M");
    $self->compara_dba->get_GeneTreeNodeAdaptor->store_node($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}


sub run_infernal {
  my $self = shift;

  my $stk_output = $self->worker_temp_directory . "output.stk";
  my $nc_tree_id = $self->param('gene_tree_id');

  my $cmalign_exe = $self->param('cmalign_exe')
    or die "'cmalign_exe' is an obligatory parameter";

  die "Cannot execute '$cmalign_exe'" unless(-x $cmalign_exe);


  my $model_id;

#   if (1 < scalar keys %{$self->param('model_id_hash')}) {
#     # We revert to the clustering_id tag, which maps to the RFAM
#     # 'name' field in hmm_profile (e.g. 'mir-135' instead of 'RF00246')
#     print STDERR "WARNING: More than one model: ", join(",",keys %{$self->param('model_id_hash')}), "\n";
#     $model_id = $self->param('nc_tree')->get_tagvalue('clustering_id') or $self->throw("'clustering_id' tag for this tree is not defined");
#     # $self->throw("This cluster has more than one associated model");
#   } else {
#     my @models = keys %{$self->param('model_id_hash')};
#     $model_id = $models[0] or die ("model_id_hash is empty?");
#   }

  if (scalar keys %{$self->param('model_id_hash')} > 1) {
      print STDERR "WARNING: More than one model: ", join(",",keys %{$self->param('model_id_hash')}), "\n";
  }
  $model_id = $self->param('nc_tree')->get_tagvalue('clustering_id') or $self->throw("'clustering_id' tag for this tree is not defined");

  $self->param('model_id', $model_id );

  print STDERR "Model_id : $model_id\n" if ($self->debug);
  my $ret1 = $self->dump_model('model_id', $model_id );
  my $ret2 = $self->dump_model('name',     $model_id ) if (1 == $ret1);
  if (1 == $ret2) {
    $self->param('nc_tree')->release_tree;
    $self->param('nc_tree', undef);
    $self->input_job->transient_error(0);
    die ("Failed to find '$model_id' both in 'model_id' and 'name' fields of 'hmm_profile' table");
  }


  my $cmd = $cmalign_exe;
  # infernal -o cluster_6357.stk RF00599_profile.cm cluster_6357.fasta

  $cmd .= " --mxsize 4000 " if($self->input_job->retry_count >= 1); # large alignments FIXME separate Infernal_huge
  $cmd .= " -o " . $stk_output;
  $cmd .= " " . $self->param('profile_file');
  $cmd .= " " . $self->param('input_fasta');

#  $DB::single=1;1; ## What for?
  my $command = $self->run_command($cmd);
  if ($command->exit_code) {
      $self->throw("error running infernal, $!\n");
  }

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

  my $cmbuild_exe = $self->param('cmbuild_exe')
    or die "'cmbuild_exe' is an obligatory parameter";

  die "Cannot execute '$cmbuild_exe'" unless(-x $cmbuild_exe);

  $cmd = $cmbuild_exe;
  $cmd .= " --refine $refined_stk_output";
  $cmd .= " -F $refined_profile";
  $cmd .= " $stk_output";

  $command = $self->run_command($cmd);
  if ($command->exit_code) {
      $self->throw("error running cmbuild refine, $!\n");
  }

  $self->param('stk_output', $refined_stk_output);

  # Reformat with sreformat
  my $fasta_output = $self->worker_temp_directory . "output.fasta";
  my $cmd = "/usr/local/ensembl/bin/sreformat a2m $refined_stk_output > $fasta_output";
  $command = $self->run_command($cmd);
  if($command->exit_code) {
    print STDERR "$cmd\n";
    $self->throw("error running sreformat, $!\n");
  }

  $self->param('infernal_output', $fasta_output);

  return 0;
}

sub dump_model {
  my $self = shift;
  my $field = shift;
  my $model_id = shift;

  my $sql = 
    "SELECT hc_profile FROM hmm_profile ".
      "WHERE $field=\"$model_id\"";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  my $nc_profile  = $sth->fetchrow;
  unless (defined($nc_profile)) {
    return 1;
  }
  my $profile_file = $self->worker_temp_directory . $model_id . "_profile.cm";
  open FILE, ">$profile_file" or die "$!";
  print FILE $nc_profile;
  close FILE;

  $self->param('profile_file', $profile_file);
  return 0;
}

sub parse_and_store_alignment_into_tree {
  my $self = shift;
  my $infernal_output =  $self->param('infernal_output');
  my $tree = $self->param('nc_tree');

  return unless($infernal_output);

  #
  # parse SS_cons lines and store into nc_tree_tag
  #

  my $stk_output = $self->param('stk_output');
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
  $self->param('nc_tree')->store_tag('ss_cons', $ss_cons_string);

  #
  # parse alignment file into hash: combine alignment lines
  #
  my %align_hash;

  # fasta format
  my $aln_io = Bio::AlignIO->new
    (-file => "$infernal_output",
     -format => 'fasta');
  my $aln = $aln_io->next_aln;
  foreach my $seq ($aln->each_seq) {
    $align_hash{$seq->display_id} = $seq->seq;
  }
  $aln_io->close;

  #
  # convert alignment string into a cigar_line
  #

  my $alignment_length;
  foreach my $id (keys %align_hash) {
    my $alignment_string = $align_hash{$id};
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
    $alignment_string = uc($alignment_string); # Infernal can lower-case regions
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
    $align_hash{$id} = $cigar_line;
  }
 
  $tree->aln_method('infernal');
  $tree->aln_length($alignment_length);

  #
  # align cigar_line to member and store
  #
  foreach my $member (@{$tree->get_all_leaves}) {
    if ($align_hash{$member->sequence_id} eq "") {
      $self->throw("infernal produced an empty cigar_line for ".$member->stable_id."\n");
    }

    $member->cigar_line($align_hash{$member->sequence_id});
    ## Check that the cigar length (Ms) matches the sequence length
    my @cigar_match_lengths = map { if ($_ eq '') {$_ = 1} else {$_ = $_;} } map { $_ =~ /^(\d*)/ } ( $member->cigar_line =~ /(\d*[M])/g );
    my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
    my $member_sequence = $member->sequence; $member_sequence =~ s/\*//g;
    if ($seq_cigar_length != length($member_sequence)) {
      $self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
    }
    #
#    printf("update nc_tree_member %s : %s\n",$member->stable_id, $member->cigar_line) if($self->debug);
    #$self->compara_dba->get_GeneTreeNodeAdaptor->store_node($member);
  }
  $self->compara_dba->get_AlignedMemberAdaptor->store($tree);
  return undef;
}

sub _store_aln_tags {
    my $self = shift;
    my $tree = $self->param('nc_tree');
    return unless($tree);

    print "Storing Alignment tags...\n";
    my $sa = $tree->get_SimpleAlign;
    $DB::single=1;1;
    # Model id
    $tree->store_tag("model_id",$self->param('model_id') );

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment runtime.
    if ($self->param('infernal_starttime')) {
        my $aln_runtime = int(time()*1000-$self->param('infernal_starttime'));
        $tree->store_tag("aln_runtime",$aln_runtime);
    }

    # Alignment residue count.
    my $aln_num_residues = $sa->no_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

}


1;
