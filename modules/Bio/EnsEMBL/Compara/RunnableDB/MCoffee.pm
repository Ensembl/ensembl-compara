#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MCoffee

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

package Bio::EnsEMBL::Compara::RunnableDB::MCoffee;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use File::Path;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Time::HiRes qw(time gettimeofday tv_interval);
# use POSIX qw(ceil floor);

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for mcoffee from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  ### DEFAULT PARAMETERS ###
  my $p = '';

  $p = 'use_exon_boundaries';
  $self->{$p} = 0;
  $p = 'method';
  $self->{$p} = 'fmcoffee';
  $p = 'output_table';
  $self->{$p} = 'protein_tree_member';
  $p = 'max_gene_count';
  $self->{$p} = 1500;
  $p = 'options';
  $self->{$p} = '';

  #########################

  # Fetch parameters from the two possible locations. Input_id takes precedence!
  # and parameters can point to an entry in analysis_data
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->check_if_exit_cleanly;

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $id = $self->{'protein_tree_id'};
  $DB::single=1;1;
  $self->{'protein_tree'} = $self->{treeDBA}->fetch_node_by_node_id($id);

#   if ($self->input_job->retry_count >= 1) {
#     if ($self->{'protein_tree'}->get_tagvalue('gene_count') > 200) {
#       $self->{'method'} = 'mafft';
#       # # HIGHMEM ensembl-hive code still experimental
#       #       unless (defined($self->worker->{HIGHMEM})) {
#       #         $self->input_job->update_status('HIGHMEM');
#       #         $self->DESTROY;
#       #         throw("Mcoffee job too big: try something else and FAIL it");
#       #       }
#     }
#   }

  # Auto-switch to fmcoffee on two failures.
  if ($self->input_job->retry_count >= 2) {
    $self->{'method'} = 'fmcoffee';
  }
  # Auto-switch to muscle on a third failure.
  if ($self->input_job->retry_count >= 3) {
    $self->{'method'} = 'mafft'; $self->{'use_exon_boundaries'} = undef;
    # actually, we are going to run mafft directly here, not through mcoffee
    # maybe in the future we want to use this option in tcoffee:
    #       t_coffee ..... -dp_mode myers_miller_pair_wise
  }
  # Auto-switch to fmcoffee if gene count is too big.
  if ($self->{'method'} eq 'cmcoffee') {
    if (200 < @{$self->{'protein_tree'}->get_all_leaves}) {
      $self->{'method'} = 'mafft'; $self->{'use_exon_boundaries'} = undef;
      #       $self->{'method'} = 'fmcoffee';
      print "MCoffee, auto-switch method to mafft because gene count > 100 \n";
    }
  }
  print "RETRY COUNT: ".$self->input_job->retry_count()."\n";

  print "MCoffee alignment method: ".$self->{'method'}."\n";

  #
  # A little logic, depending on the input params.
  #
  # Protein Tree input.
  if (defined $self->{'protein_tree_id'}) {
    $self->{'protein_tree'}->flatten_tree; # This makes retries safer
    # The extra option at the end adds the exon markers
    $self->{'input_fasta'} = $self->dumpProteinTreeToWorkdir($self->{'protein_tree'},$self->{'use_exon_boundaries'});
  }

  if (defined($self->{'redo'}) && $self->{'method'} eq 'unalign') {
    # Redo - take previously existing alignment - post-process it
    $self->{redo_sa} = $self->{'protein_tree'}->get_SimpleAlign(-id_type => 'MEMBER');
    $self->{redo_sa}->set_displayname_flat(1);
    $self->{redo_alnname} = $self->worker_temp_directory . $self->{protein_tree}->node_id . ".fasta";
    my $alignout = Bio::AlignIO->new(-file => ">".$self->{redo_alnname},
                                     -format => "fasta");
    $alignout->write_aln($self->{redo_sa});
  }

  #
  # Ways to fail the job before running.
  #

  # No input specified.
  if (!defined($self->{'protein_tree'})) {
    $self->DESTROY;
    throw("MCoffee job no input protein_tree");
  }
  # Error writing input Fasta file.
  if (!$self->{'input_fasta'}) {
    $self->DESTROY;
    throw("MCoffee job, error writing input Fasta");
  }
#  # Gene count too big.
#   if ($self->{'protein_tree'}->get_tagvalue('gene_count') > $self->{'max_gene_count'}) {
#     $self->dataflow_output_id($self->input_id, 2);
#     $self->input_job->update_status('FAILED');
#     $self->DESTROY;
#     throw("Mcoffee job too big: try something else and FAIL it");
#   }
  # Retry count >= 3.
  if ($self->input_job->retry_count >= 5) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');
    $self->DESTROY;
    throw("Mcoffee job failed >=3 times: try something else and FAIL it");
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

sub run
{
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->{'mcoffee_starttime'} = time()*1000;
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
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->parse_and_store_alignment_into_proteintree;

  #
  # Store various alignment tags.
  #
  $self->_store_aln_tags unless ($self->{redo});
}

sub DESTROY {
    my $self = shift;

    if($self->{'protein_tree'}) {
	$self->{'protein_tree'}->release_tree;
	$self->{'protein_tree'} = undef;
    }

    # Cleanup temp files and stuff.
    # unlink ($self->{'input_params'}) if($self->{'input_params'});
    # unlink ($self->{'input_fasta'}) if($self->{'input_fasta'});
    # if($self->{'mcoffee_output'}) {
	# unlink ($self->{'mcoffee_output'});
	# unlink ($self->{'mcoffee_output'} . ".log");
    # }

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key\t=>\t", $params->{$key}, "\n");
    }
  }

  my $p;
  
  #First if this was an analysis data id then we rerun get params for it
  $p = 'analysis_data_id';
  if(defined $params->{$p}) {
  	my $adid = $params->{$p};
  	my $ad_a = $self->db()->get_AnalysisDataAdaptor();
  	my $next_param_string = $ad_a->fetch_by_dbID($adid);
  	$self->get_params($next_param_string);
  }
  #The continue onto other params

  # METHOD: The style of MCoffee to be run for this alignment.
  # Could be: fmcoffee or cmcoffee
  $p = 'method';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # cutoff: for filtering
  $p = 'cutoff';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # OUTPUT_TABLE: self-explanatory.
  $p = 'output_table';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # Loads the protein tree if we have a protein_tree_id
  $p = 'protein_tree_id';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # clusterset_id
  $p = 'clusterset_id';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # Extra command-line options.
  $p = 'options';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # Set a limit on the number of members to align.
  $p = 'max_gene_count';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  $p = 'use_exon_boundaries';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));

  # This is analysis, not production: 'redo' e.g. '1:1000000' from clusterset_id 1 to a different clusterset_id 10000000
  $p = 'redo';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));
  
  # This is looking for a mafft binary which overides other binary settings
  $p = 'mafft';
  $self->{$p} = $params->{$p} if (defined($params->{$p}));
  
  return;
}


sub run_mcoffee
{
  my $self = shift;
  return if (1 == $self->{single_peptide_tree});
  my $input_fasta = $self->{'input_fasta'};

  my $mcoffee_output = $self->worker_temp_directory . "output.mfa";
  $mcoffee_output =~ s/\/\//\//g; $self->{'mcoffee_output'} = $mcoffee_output;

  # (Note: t_coffee automatically uses the .mfa output as the basename for the score output)
  my $mcoffee_scores = $mcoffee_output . ".score_ascii";
  $mcoffee_scores =~ s/\/\//\//g; $self->{'mcoffee_scores'} = $mcoffee_scores;

  my $tree_temp = $self->worker_temp_directory . "tree_temp.dnd";
  $tree_temp =~ s/\/\//\//g; $self->{'mcoffee_tree'} = $tree_temp;

  my $mcoffee_executable = $self->analysis->program_file;
    unless (-e $mcoffee_executable) {
      print "Using default T-Coffee executable!\n";
      $mcoffee_executable = "/nfs/acari/avilella/src/tcoffee/compara/t_coffee";
  }
  throw("can't find a M-Coffee executable to run\n") unless(-e $mcoffee_executable);

  #
  # Make the t_coffee temp dir.
  #
  my $tempdir = $self->worker_temp_directory;
  print "TEMP DIR: $tempdir\n" if ($self->debug);

  #
  # Output the params file.
  #
  $self->{'input_params'} = $self->worker_temp_directory. "temp.params";
  my $paramsfile = $self->{'input_params'};
  $paramsfile =~ s/\/\//\//g;  # converts any // in path to /
  open(OUTPARAMS, ">$paramsfile")
    or throw("Error opening $paramsfile for write");

  my $method_string = '-method=';
  if ($self->{'method'} && $self->{'method'} eq 'cmcoffee') {
      # CMCoffee, slow, comprehensive multiple alignments.
      $method_string .= "mafftgins_msa, muscle_msa, kalign_msa, t_coffee_msa "; #, probcons_msa";
  } elsif ($self->{'method'} eq 'fmcoffee') {
      # FMCoffee, fast but accurate alignments.
      $method_string .= "mafft_msa, muscle_msa, clustalw_msa, kalign_msa";
  } elsif ($self->{'method'} eq 'muscle') {
      # MUSCLE: quick, kind of crappy alignments.
      $method_string .= "muscle_msa";
  } elsif ($self->{'method'} eq 'mafft') {
      # MAFFT FAST: very quick alignments.
      $method_string .= "mafft_msa";
  } elsif ($self->{'method'} eq 'prank') {
      # PRANK: phylogeny-aware alignment.
      $method_string .= "prank_msa";
  } elsif (defined($self->{'redo'}) && $self->{'method'} eq 'unalign') {
    my $cutoff = $self->{'cutoff'} || 2;
      # Unalign module
    $method_string = " -other_pg seq_reformat -in " . $self->{redo_alnname} ." -action +aln2overaln unalign 2 30 5 15 0 1>$mcoffee_output";
  }  else {
      throw ("Improper method parameter: ".$self->{'method'});
  }

  my $extra_output = '';
  if ($self->{'use_exon_boundaries'}) {
    my $exon_file = $self->{'input_fasta_exons'};
    if (1 == $self->{use_exon_boundaries}) {
      $method_string .= ", exon_pair";
      print OUTPARAMS "-template_file=$exon_file\n";
    } elsif (2 == $self->{use_exon_boundaries}) {
      $self->{'mcoffee_scores'} = undef;
      $extra_output .= ',overaln  -overaln_param unalign -overaln_P1 150 -overaln_P2 30';
    }
  }
  $method_string .= "\n";

  print OUTPARAMS $method_string;
  print OUTPARAMS "-mode=mcoffee\n";
  print OUTPARAMS "-output=fasta_aln,score_ascii" . $extra_output . "\n";
  print OUTPARAMS "-outfile=$mcoffee_output\n";
  print OUTPARAMS "-newtree=$tree_temp\n";
  close(OUTPARAMS);

  my $t_env_filename = $tempdir . "t_coffee_env";
  open(TCOFFEE_ENV, ">$t_env_filename")
    or throw("Error opening $t_env_filename for write");
  print TCOFFEE_ENV "http_proxy_4_TCOFFEE=\n";
  print TCOFFEE_ENV "EMAIL_4_TCOFFEE=cedric.notredame\@europe.com\n";
  close TCOFFEE_ENV;

  # Commandline
  my $cmd = $mcoffee_executable;
  $cmd .= " ".$input_fasta unless ($self->{redo});
  $cmd .= " ". $self->{'options'};
  if (defined($self->{'redo'}) && $self->{'method'} eq 'unalign') {
    $self->{'mcoffee_scores'} = undef; #these wont have scores
    $cmd .= " ". $method_string;
  } else {
    $cmd .= " -parameters=$paramsfile";
  }

  print("$cmd\n") if($self->debug);

  #
  # Output some environment variables for tcoffee
  #
  my $prefix = "export HOME_4_TCOFFEE=\"$tempdir\";";
  $prefix .= "export DIR_4_TCOFFEE=\"$tempdir\";";
  $prefix .= "export TMP_4_TCOFFEE=\"$tempdir\";";
  $prefix .= "export CACHE_4_TCOFFEE=\"$tempdir\";";
  $prefix .= "export NO_ERROR_REPORT_4_TCOFFEE=1;";
  
  if(defined $self->{mafft}) {
  	print "Using defined mafft location $self->{mafft}. Make sure MAFFT_BINARIES is setup correctly\n" if $self->debug();
  }
  else {
  	print "Using default mafft location\n" if $self->debug();
  	$prefix .= "export MAFFT_BINARIES=/nfs/acari/avilella/src/tcoffee/T-COFFEE_distribution_Version_7.86/install4tcoffee/bin/linux;";
  }
  print $prefix.$cmd."\n" if ($self->debug);
  $DB::single=1;1;
  #
  # Run the command.
  #
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  my $rc;
  if ($self->{'method'} eq 'mafft') {
  	my ($mafft_env, $mafft_executable);
  	if(defined $self->{mafft}) {
  		$mafft_executable = $self->{mafft};
  	}
  	else {
    	$mafft_executable = "/software/ensembl/compara/mafft-6.707/bin/mafft";
    	$mafft_env = '/software/ensembl/compara/mafft-6.707/binaries';
  	}

  	$ENV{MAFFT_BINARIES} = $mafft_env if $mafft_env;
    print STDERR "### $mafft_executable --auto $input_fasta > $mcoffee_output\n";
    $rc = system("$mafft_executable --auto $input_fasta > $mcoffee_output");
    $self->{'mcoffee_scores'} = undef; #these wont have scores
  } else {
    $DB::single=1;
    $rc = system($prefix.$cmd);
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  unless($rc == 0) {
      $self->DESTROY;
      throw("MCoffee job, error running executable: $\n");
  }
}

########################################################
#
# ProteinTree input/output section
#
########################################################

sub update_single_peptide_tree
{
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->{'comparaDBA'}->get_ProteinTreeAdaptor->store($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}

sub dumpProteinTreeToWorkdir {
  my $self = shift;
  my $tree = shift;
  my $use_exon_boundaries = shift;
  $DB::single=1;1;
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

  $self->{'tag_gene_count'} = scalar(@{$member_list});
  foreach my $member (@{$member_list}) {

    # Double-check we are only using longest
    my $gene_member; my $longest_member = undef;
    eval {$gene_member = $member->gene_member; $longest_member = $gene_member->get_longest_peptide_Member; };
    unless (defined($longest_member) && ($longest_member->member_id eq $member->member_id) ) {
      $DB::single=1;1;
      $member->disavow_parent;
      $self->{treeDBA}->delete_flattened_leaf($member);
      my $updated_gene_count = scalar(@{$tree->get_all_leaves});
      $tree->adaptor->delete_tag($tree->node_id,'gene_count');
      $tree->store_tag('gene_count', $updated_gene_count);
      next;
    }
    ####

      return undef unless ($member->isa("Bio::EnsEMBL::Compara::AlignedMember"));
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

  if(scalar keys (%{$seq_id_hash}) <= 1) {
    $self->update_single_peptide_tree($tree);
    $self->{single_peptide_tree} = 1;
  }

  $self->{'tag_residue_count'} = $residues;
  return $fastafile;
}

sub parse_and_store_alignment_into_proteintree
{
  my $self = shift;

  return if (1 == $self->{single_peptide_tree});
  my $mcoffee_output =  $self->{'mcoffee_output'};
  my $mcoffee_scores = $self->{'mcoffee_scores'};
  my $format = 'fasta';
  my $tree = $self->{'protein_tree'};

  if (2 == $self->{use_exon_boundaries}) {
    $mcoffee_output .= ".overaln";
    # $format = 'clustalw';
  }
  return unless($mcoffee_output and -e $mcoffee_output);

  #
  # Read in the alignment using Bioperl.
  #
  use Bio::AlignIO;
  my $alignio = Bio::AlignIO->new(-file => "$mcoffee_output",
				  -format => "$format");
  my $aln = $alignio->next_aln();
  my %align_hash;
  foreach my $seq ($aln->each_seq) {
      my $id = $seq->display_id;
      $align_hash{$id} = $seq->seq;
  }

  #
  # Read in the scores file manually.
  #
  my %score_hash;
  if (defined $mcoffee_scores) {
    my $FH = IO::File->new();
    $FH->open($mcoffee_scores) || throw("Could not open alignment scores file [$mcoffee_scores]");
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
        $DB::single=1;1;
        throw("While parsing the alignment, some id did not return the expected alignment length\n");
      }
    }
    # Call the method to do the actual conversion
    $align_hash{$id} = $self->_to_cigar_line(uc($alignment_string));
  }

  if (defined($self->{redo}) && $self->{'output_table'} eq 'protein_tree_member') {
    # We clone the tree, attach it to the new clusterset_id, then store it.
    # protein_tree_member is now linked to the new one
    my ($from_clusterset_id, $to_clusterset_id) = split(":",$self->{'redo'});
    throw("malformed redo option: ". $self->{'redo'}." should be like 1:1000000") 
      unless (defined($from_clusterset_id) && defined($to_clusterset_id));
    my $clone_tree = $self->{protein_tree}->copy;
    my $clusterset = $self->{treeDBA}->fetch_node_by_node_id($to_clusterset_id);
    $clusterset->add_child($clone_tree);
    $self->{treeDBA}->store($clone_tree);
    # Maybe rerun indexes - restore
    # $self->{treeDBA}->sync_tree_leftright_index($clone_tree);
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
	  throw("mcoffee produced an empty cigar_line for ".$member->stable_id."\n");
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
	  throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
      }

      if ($self->{'output_table'} eq 'protein_tree_member') {
	  #
	  # We can use the default store method for the $member.
          $self->{'comparaDBA'}->get_ProteinTreeAdaptor->store($member);
      } else {
	  #
	  # Do a manual insert into the correct output table.
	  #
	  my $table_name = $self->{'output_table'};
	  printf("Updating $table_name %s : %s\n",$member->stable_id,$member->cigar_line) if ($self->debug);
	  my $sth = $self->{treeDBA}->prepare("INSERT ignore INTO $table_name 
                               (node_id,member_id,method_link_species_set_id,cigar_line)  VALUES (?,?,?,?)");
	  $sth->execute($member->node_id,$member->member_id,$member->method_link_species_set_id,$member->cigar_line);
	  $sth->finish;
      }
      if (defined $self->{'mcoffee_scores'}) {
        #
        # Do a manual insert of the *scores* into the correct score output table.
        #
        my $table_name = $self->{'output_table'} . "_score";
        my $sth = $self->{treeDBA}->prepare("INSERT ignore INTO $table_name 
                               (node_id,member_id,method_link_species_set_id,cigar_line)  VALUES (?,?,?,?)");
        my $score_string = $score_hash{$member->sequence_id} || '';
        $score_string =~ s/[^\d-]/9/g;   # Convert non-digits and non-dashes into 9s. This is necessary because t_coffee leaves some leftover letters.
        printf("Updating $table_name %s : %s\n",$member->stable_id,$score_string) if ($self->debug);

        $sth->execute($member->node_id,$member->member_id,$member->method_link_species_set_id,$score_string);
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
    my $tree = shift || $self->{'protein_tree'};
    my $output_table = $self->{'output_table'};
    my $pta = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

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
    my $aln_runtime = int(time()*1000-$self->{'mcoffee_starttime'});
    $tree->store_tag("aln_runtime",$aln_runtime);

    # Alignment method.
    my $aln_method = $self->{'method'};
    $tree->store_tag("aln_method",$aln_method);

    # Alignment residue count.
    my $aln_num_residues = $sa->no_residues;
    $tree->store_tag("aln_num_residues",$aln_num_residues);

    # Alignment redo mapping.
    my ($from_clusterset_id, $to_clusterset_id) = split(":",$self->{'redo'});
    my $redo_tag = "MCoffee_redo_".$from_clusterset_id."_".$to_clusterset_id;
    $tree->store_tag("$redo_tag",$self->{'protein_tree_id'}) if ($self->{'redo'});
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
        my $cmd = "SELECT cigar_line FROM $table where member_id=$id;";
        my $sth = $pta->prepare($cmd);
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
