#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=cut

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $mcoffee = Bio::EnsEMBL::Compara::RunnableDB::Mcoffee->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$mcoffee->fetch_input(); #reads from DB
$mcoffee->run();
$mcoffee->output();
$mcoffee->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a protein_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the protein_tree_member and protein_tree_member_score table.

input_id/parameters format eg: "{'protein_tree_id'=>726093, 'clusterset_id'=>1}"
    protein_tree_id       : use family_id to run multiple alignment on its members
    options               : commandline options to pass to the 'mcoffee' program

=cut

=head1 CONTACT

  Contact Albert Vilella on module implemetation/design detail: avilella@ebi.ac.uk
  Contact Javier Herrero on EnsEMBL/Compara: jherrero@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee;

use strict;
use IO::File;
use File::Basename;
use File::Path;

use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'use_exon_boundaries'   => 0,                       # careful: 0 and undef have different meanings here
        'method'                => 'fmcoffee',              # the style of MCoffee to be run for this alignment
        'output_table'          => 'protein_tree_member',   # self-explanatory
        'options'               => '',
        'cutoff'                => 2,                       # for filtering
        'max_gene_count'        => 400,                     # if the resulting cluster is bigger, it is dataflown to QuickTreeBreak
    };
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

  $self->check_if_exit_cleanly;

    $self->param('tree_adaptor', $self->compara_dba->get_ProteinTreeAdaptor);
    my $protein_tree_id = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";

    $self->param('protein_tree', $self->param('tree_adaptor')->fetch_node_by_node_id($protein_tree_id) );

  # Auto-switch to fmcoffee on two failures.
  if ($self->input_job->retry_count >= 2) {
    $self->param('method', 'fmcoffee');
  }
  # Auto-switch to mafft on a third failure.
  if ($self->input_job->retry_count >= 3) {
    $self->param('method', 'mafft');
    # actually, we are going to run mafft directly here, not through mcoffee
    # maybe in the future we want to use this option in tcoffee:
    #       t_coffee ..... -dp_mode myers_miller_pair_wise
  }
  # Auto-switch to mafft if gene count is too big.
  if ($self->param('method') eq 'cmcoffee') {
    if (200 < @{$self->param('protein_tree')->get_all_leaves}) {
      $self->param('method', 'mafft');
      print "MCoffee, auto-switch method to mafft because gene count >= 200 \n";
    }
  }

  # We check if it took more than two hours in the previous release. If
  # it did, then we go mafft
  my $reuse_aln_runtime = $self->param('protein_tree')->get_tagvalue('reuse_aln_runtime');
  if ($reuse_aln_runtime ne '') {
    my $hours = $reuse_aln_runtime / 3600000;
    if ($hours > 2) { 
      $self->param('method', 'mafft');
    }
  }

  if ($self->param('method') eq 'mafft') { $self->param('use_exon_boundaries', undef); }

  print "RETRY COUNT: ".$self->input_job->retry_count()."\n";

  print "MCoffee alignment method: ".$self->param('method')."\n";

  #
  # A little logic, depending on the input params.
  #
  # Protein Tree input.
  if (defined $self->param('protein_tree_id')) {
    $self->param('protein_tree')->flatten_tree; # This makes retries safer
    # The extra option at the end adds the exon markers
    $self->param('input_fasta', $self->dumpProteinTreeToWorkdir($self->param('protein_tree'), $self->param('use_exon_boundaries')) );
  }

  if (defined($self->param('redo')) && $self->param('method') eq 'unalign') {
    # Redo - take previously existing alignment - post-process it
    my $redo_sa = $self->param('protein_tree')->get_SimpleAlign(-id_type => 'MEMBER');
    $redo_sa->set_displayname_flat(1);
    $self->param('redo_alnname', $self->worker_temp_directory . $self->param('protein_tree')->node_id.'.fasta' );
    my $alignout = Bio::AlignIO->new(-file => ">".$self->param('redo_alnname'),
                                     -format => "fasta");
    $alignout->write_aln( $redo_sa );
  }

  #
  # Ways to fail the job before running.
  #

  # No input specified.
  if (!defined($self->param('protein_tree'))) {
    $self->DESTROY;
    $self->throw("MCoffee job no input protein_tree");
  }
  # Error writing input Fasta file.
  if (!$self->param('input_fasta')) {
    $self->DESTROY;
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

  $self->check_if_exit_cleanly;
  $self->param('mcoffee_starttime', time()*1000);
  $self->run_mcoffee;
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

    $self->check_if_exit_cleanly;
    $self->parse_and_store_alignment_into_proteintree;

        # Store various alignment tags:
    $self->_store_aln_tags unless ($self->param('redo'));


    my $protein_tree   = $self->param('protein_tree');
    my $gene_count     = $protein_tree && $protein_tree->get_tagvalue('gene_count');
    my $max_gene_count = $self->param('max_gene_count');

    if($gene_count > $max_gene_count) {
        $self->dataflow_output_id($self->input_id, 3);
        $protein_tree->release_tree;
        $self->param('protein_tree', undef);
        $self->input_job->incomplete(0);
        die "Cluster size ($gene_count) over threshold ($max_gene_count), dataflowing to QuickTreeBreak\n";
    }
}

sub DESTROY {
    my $self = shift;

    if($self->param('protein_tree')) {
        $self->param('protein_tree')->release_tree;
        $self->param('protein_tree', undef);
    }

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

##########################################
#
# internal methods
#
##########################################


sub run_mcoffee {
  my $self = shift;
  return if ($self->param('single_peptide_tree'));
  my $input_fasta = $self->param('input_fasta');

  #
  # Make the t_coffee temp dir.
  #
  my $tempdir = $self->worker_temp_directory;
  print "TEMP DIR: $tempdir\n" if ($self->debug);

  my $msa_output = $tempdir . 'output.mfa';
  $msa_output =~ s/\/\//\//g;
  $self->param('msa_output', $msa_output);

  # (Note: t_coffee automatically uses the .mfa output as the basename for the score output)
  my $mcoffee_scores = $msa_output . '.score_ascii';
  $mcoffee_scores =~ s/\/\//\//g;
  $self->param('mcoffee_scores', $mcoffee_scores);

  my $tree_temp = $tempdir . 'tree_temp.dnd';
  $tree_temp =~ s/\/\//\//g;

  my $method_string = '-method=';
  if ($self->param('method') and ($self->param('method') eq 'cmcoffee') ) {
      # CMCoffee, slow, comprehensive multiple alignments.
      $method_string .= "mafftgins_msa, muscle_msa, kalign_msa, t_coffee_msa "; #, probcons_msa";
  } elsif ($self->param('method') eq 'fmcoffee') {
      # FMCoffee, fast but accurate alignments.
      $method_string .= "mafft_msa, muscle_msa, clustalw_msa, kalign_msa";
  } elsif ($self->param('method') eq 'mafft') {
      # MAFFT FAST: very quick alignments.
      $method_string .= "mafft_msa";
  } elsif ($self->param('method') eq 'prank') {
      # PRANK: phylogeny-aware alignment.
      $method_string .= "prank_msa";
  } elsif (defined($self->param('redo')) and ($self->param('method') eq 'unalign') ) {
    my $cutoff = $self->param('cutoff') || 2;
      # Unalign module
    $method_string = " -other_pg seq_reformat -in " . $self->param('redo_alnname') ." -action +aln2overaln unalign 2 30 5 15 0 1>$msa_output";
  } else {
      throw ("Improper method parameter: ".$self->param('method'));
  }

  #
  # Output the params file.
  #
  my $paramsfile = $tempdir. 'temp.params';
  $paramsfile =~ s/\/\//\//g;  # converts any // in path to /
  open(OUTPARAMS, ">$paramsfile")
    or $self->throw("Error opening $paramsfile for write");

  my $extra_output = '';
  if ($self->param('use_exon_boundaries')) {
    if (1 == $self->param('use_exon_boundaries')) {
      $method_string .= ", exon_pair";
      my $exon_file = $self->param('input_fasta_exons');
      print OUTPARAMS "-template_file=$exon_file\n";
    } elsif (2 == $self->param('use_exon_boundaries')) {
      $self->param('mcoffee_scores', undef);
      $extra_output .= ',overaln  -overaln_param unalign -overaln_P1 99999 -overaln_P2 1'; # overaln_P1 150 and overaln_P2 30 was dealigning too aggressively
    }
  }
  $method_string .= "\n";

  print OUTPARAMS $method_string;
  print OUTPARAMS "-mode=mcoffee\n";
  print OUTPARAMS "-output=fasta_aln,score_ascii" . $extra_output . "\n";
  print OUTPARAMS "-outfile=$msa_output\n";
  print OUTPARAMS "-newtree=$tree_temp\n";
  close OUTPARAMS;

  my $t_env_filename = $tempdir . "t_coffee_env";
  open(TCOFFEE_ENV, ">$t_env_filename")
    or $self->throw("Error opening $t_env_filename for write");
  print TCOFFEE_ENV "http_proxy_4_TCOFFEE=\n";
  print TCOFFEE_ENV "EMAIL_4_TCOFFEE=cedric.notredame\@europe.com\n";
  close TCOFFEE_ENV;

    my $cmd       = '';
    my $prefix    = '';
    if ($self->param('method') eq 'mafft') {

        my $mafft_exe      = $self->param('mafft_exe')
            or die "'mafft_exe' is an obligatory parameter";

        die "Cannot execute '$mafft_exe'" unless(-x $mafft_exe);

        my $mafft_binaries = $self->param('mafft_binaries')
            or die "'mafft_binaries' is an obligatory parameter";

        $ENV{MAFFT_BINARIES} = $mafft_binaries;

        $self->param('mcoffee_scores', undef); #these wont have scores

        $cmd = "$mafft_exe --auto $input_fasta > $msa_output";

    } else {

        my $mcoffee_exe = $self->param('mcoffee_exe')
            or die "'mcoffee_exe' is an obligatory parameter";

        die "Cannot execute '$mcoffee_exe'" unless(-x $mcoffee_exe);

        $cmd = $mcoffee_exe;
        $cmd .= ' '.$input_fasta unless ($self->param('redo'));
        $cmd .= ' '. $self->param('options');
        if (defined($self->param('redo')) and ($self->param('method') eq 'unalign') ) {
            $self->param('mcoffee_scores', undef); #these wont have scores
            $cmd .= ' '. $method_string;
        } else {
            $cmd .= " -parameters=$paramsfile";
        }
        #
        # Output some environment variables for tcoffee
        #
        $prefix = "export HOME_4_TCOFFEE=\"$tempdir\";" if ! $ENV{HOME_4_TCOFFEE};
        $prefix .= "export DIR_4_TCOFFEE=\"$tempdir\";" if ! $ENV{DIR_4_TCOFFEE};
        $prefix .= "export TMP_4_TCOFFEE=\"$tempdir\";";
        $prefix .= "export CACHE_4_TCOFFEE=\"$tempdir\";";
        $prefix .= "export NO_ERROR_REPORT_4_TCOFFEE=1;";

        print "Using default mafft location\n" if $self->debug();
        $prefix .= 'export MAFFT_BINARIES=/software/ensembl/compara/tcoffee-7.86b/install4tcoffee/bin/linux ;';
            # path to t_coffee components:
        $prefix .= 'export PATH=$PATH:/software/ensembl/compara/tcoffee-7.86b/install4tcoffee/bin/linux ;';
    }

    #
    # Run the command:
    #
    $self->compara_dba->dbc->disconnect_when_inactive(1);

    print STDERR "Running:\n\t$prefix $cmd\n" if ($self->debug);
    if(system($prefix.$cmd)) {
        my $system_error = $!;

        $self->DESTROY;
        die "Failed to execute [$prefix $cmd]: $system_error ";
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

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->compara_dba->get_ProteinTreeAdaptor->store($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}

sub dumpProteinTreeToWorkdir {
  my $self = shift;
  my $tree = shift;
  my $use_exon_boundaries = shift;

  my $fastafile;
  if (defined($use_exon_boundaries)) {
      $fastafile = $self->worker_temp_directory. "proteintree_exon_". $tree->node_id. ".fasta";
  } else {
    my $node_id = $tree->node_id;
    $fastafile = $self->worker_temp_directory. "proteintree_". $node_id. ".fasta";
  }

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile && !defined($use_exon_boundaries));
  print("fastafile = '$fastafile'\n") if ($self->debug);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write!");

  my $seq_id_hash = {};
  my $residues = 0;
  my $member_list = $tree->get_all_leaves;

  $self->param('tag_gene_count', scalar(@{$member_list}) );
  my $has_canonical_issues = 0;
  foreach my $member (@{$member_list}) {

    # Double-check we are only using canonical
    my $gene_member; my $canonical_member = undef;
    eval {
      $gene_member = $member->gene_member; 
      $canonical_member = $gene_member->get_canonical_peptide_Member;
    };
    if($self->debug() and $@) { print "ERROR IN EVAL (node_id=".$member->node_id.") : $@"; }
    unless (defined($canonical_member) && ($canonical_member->member_id eq $member->member_id) ) {
      my $canonical_member2 = $gene_member->get_canonical_peptide_Member;
      my $clustered_stable_id = $member->stable_id;
      my $canonical_stable_id = $canonical_member->stable_id;
      $tree->store_tag('canon.'.$clustered_stable_id."_".$canonical_stable_id,1);
      $has_canonical_issues++;
#       $member->disavow_parent;
#       $self->param('tree_adaptor')->delete_flattened_leaf($member);
#       my $updated_gene_count = scalar(@{$tree->get_all_leaves});
#       $tree->adaptor->delete_tag($tree->node_id,'gene_count');
#       $tree->store_tag('gene_count', $updated_gene_count);
#       next;
    }
    ####

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

  return if ($self->param('single_peptide_tree'));
  my $msa_output =  $self->param('msa_output');
  my $mcoffee_scores = $self->param('mcoffee_scores');
  my $format = 'fasta';
  my $tree = $self->param('protein_tree');

  if (2 == $self->param('use_exon_boundaries')) {
    $msa_output .= ".overaln";
  }
  return unless($msa_output and -e $msa_output);

  #
  # Read in the alignment using Bioperl.
  #
  use Bio::AlignIO;
  my $alignio = Bio::AlignIO->new(-file => "$msa_output",
				  -format => "$format");
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
      eval { $tree->store_tag('decaf.'.$id, join(":",@overalignments));};
    }
  }

  #
  # Read in the scores file manually.
  #
  my %score_hash;
  if (defined $mcoffee_scores) {
    my $FH = IO::File->new();
    $FH->open($mcoffee_scores) || $self->throw("Could not open alignment scores file [$mcoffee_scores]");
    <$FH>; #skip header
    my $i=0;
    while(<$FH>) {
      $i++;
      next if ($i < 7); # skip first 7 lines.
      next if($_ =~ /^\s+/);  #skip lines that start with space
      if ($_ =~ /:/) {
        my ($id,$overall_score) = split(/:/,$_);
        $id =~ s/^\s+|\s+$//g;
        $overall_score =~ s/^\s+|\s+$//g;
        print "___".$id."___".$overall_score."___\n";
        next;
      }
      chomp;
      my ($id, $align) = split;
      $score_hash{$id} ||= '';
      $score_hash{$id} .= $align;
    }
    $FH->close;
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
  }

  if (defined($self->param('redo')) and ($self->param('output_table') eq 'protein_tree_member') ) {
    # We clone the tree, attach it to the new clusterset_id, then store it.
    # protein_tree_member is now linked to the new one
    my ($from_clusterset_id, $to_clusterset_id) = split(':', $self->param('redo'));
    $self->throw("malformed redo option: ". $self->param('redo')." should be like 1:1000000")
      unless (defined($from_clusterset_id) && defined($to_clusterset_id));
    my $clone_tree = $self->param('protein_tree')->copy;
    my $clusterset = $self->param('tree_adaptor')->fetch_node_by_node_id($to_clusterset_id);
    $clusterset->add_child($clone_tree);
    $self->param('tree_adaptor')->store($clone_tree);
    # Maybe rerun indexes - restore
    # $self->param('tree_adaptor')->sync_tree_leftright_index($clone_tree);
    $self->_store_aln_tags($clone_tree);
    # Point $tree object to the new tree from now on
    $tree->release_tree; $tree = $clone_tree;
  }

  #
  # Align cigar_lines to members and store
  #
  foreach my $member (@{$tree->get_all_leaves}) {
      # Redo alignment is member_id based, new alignment is sequence_id based
      if ($align_hash{$member->sequence_id} eq "" && $align_hash{$member->member_id} eq "") {
	  $self->throw("mcoffee produced an empty cigar_line for ".$member->stable_id."\n");
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

      if ($self->param('output_table') eq 'protein_tree_member') {
	  #
	  # We can use the default store method for the $member.
          $self->compara_dba->get_ProteinTreeAdaptor->store($member);
      } else {
	  #
	  # Do a manual insert into the correct output table.
	  #
	  my $table_name = $self->param('output_table');
	  printf("Updating $table_name %s : %s\n",$member->stable_id,$member->cigar_line) if ($self->debug);
	  my $sth = $self->param('tree_adaptor')->prepare("INSERT ignore INTO $table_name
                               (node_id,member_id,method_link_species_set_id,cigar_line)  VALUES (?,?,?,?)");
	  $sth->execute($member->node_id,$member->member_id,$member->method_link_species_set_id,$member->cigar_line);
	  $sth->finish;
      }
      if (defined $self->param('mcoffee_scores')) {
        #
        # Do a manual insert of the *scores* into the correct score output table.
        #
        my $table_name = $self->param('output_table') . "_score";
        my $sth = $self->param('tree_adaptor')->prepare("INSERT ignore INTO $table_name
                               (node_id,member_id,root_id,method_link_species_set_id,cigar_line)  VALUES (?,?,?,?,?)");
        my $score_string = $score_hash{$member->sequence_id} || '';
        $score_string =~ s/[^\d-]/9/g;   # Convert non-digits and non-dashes into 9s. This is necessary because t_coffee leaves some leftover letters.
        printf("Updating $table_name %s : %s\n",$member->stable_id,$score_string) if ($self->debug);

        $sth->execute($member->node_id,$member->member_id, $tree->node_id, $member->method_link_species_set_id,$score_string);
        $sth->finish;
      }
  }
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
    my $tree = shift || $self->param('protein_tree');
    my $output_table = $self->param('output_table');
    my $pta = $self->compara_dba->get_ProteinTreeAdaptor;

    print "Storing Alignment tags...\n";

    #
    # Retrieve a tree with the "correct" cigar lines.
    #
    if ($output_table ne "protein_tree_member") {
        $tree = $self->_get_alternate_alignment_tree($pta,$tree->node_id,$output_table);
    }

    my $sa = $tree->get_SimpleAlign;

    # Alignment percent identity.
    my $aln_pi = $sa->average_percentage_identity;
    $tree->store_tag("aln_percent_identity",$aln_pi);

    # Alignment length.
    my $aln_length = $sa->length;
    $tree->store_tag("aln_length",$aln_length);

    # Alignment runtime.
    my $aln_runtime = int(time()*1000-$self->param('mcoffee_starttime'));
    $tree->store_tag("aln_runtime",$aln_runtime);

    # Alignment method.
    my $aln_method = $self->param('method');
    $tree->store_tag("aln_method",$aln_method);

    # Alignment residue count.
    my $aln_num_residues = $sa->no_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

    # Alignment redo mapping.
    my ($from_clusterset_id, $to_clusterset_id) = split(':', $self->param('redo'));
    my $redo_tag = "MCoffee_redo_".$from_clusterset_id."_".$to_clusterset_id;
    $tree->store_tag("$redo_tag",$self->param('protein_tree_id')) if ($self->param('redo'));
}

sub _get_alternate_alignment_tree {
    my $self = shift;
    my $pta = shift;
    my $node_id = shift;
    my $table = shift;

    my $tree = $pta->fetch_node_by_node_id($node_id);

    foreach my $leaf (@{$tree->get_all_leaves}) {
        # "Release" the stored / cached values for the alignment strings.
        undef $leaf->{'cdna_alignment_string'};
        undef $leaf->{'alignment_string'};

        # Grab the correct cigar line for each leaf node.
        my $id = $leaf->member_id;
        my $sql = "SELECT cigar_line FROM $table where member_id=$id;";
        my $sth = $pta->prepare($sql);
        $sth->execute();
        my $data = $sth->fetchrow_hashref();
        $sth->finish();
        my $cigar = $data->{'cigar_line'};

        die "No cigar line for member $id!\n" unless ($cigar);
        $leaf->cigar_line($cigar);
    }
    return $tree;
}

1;
