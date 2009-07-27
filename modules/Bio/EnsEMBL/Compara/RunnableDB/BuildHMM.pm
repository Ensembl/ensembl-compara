#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildHMM

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $buildhmm = Bio::EnsEMBL::Compara::RunnableDB::BuildHMM->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$buildhmm->fetch_input(); #reads from DB
$buildhmm->run();
$buildhmm->output();
$buildhmm->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input create a HMMER HMM profile

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::BuildHMM;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::SimpleAlign;
use Bio::AlignIO;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'max_gene_count'} = 1000000;

  $self->check_job_fail_options;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  $self->check_if_exit_cleanly;

  $self->{'hmm_type'} = 'dna' if     defined($self->{'cdna'});
  $self->{'hmm_type'} = 'aa'  unless defined($self->{'cdna'});
  if (defined($self->{notaxon})) {
    $self->{'hmm_type'} .= "_notaxon" . "_" . $self->{notaxon};
  }
  my $type = 'aa'; $type = 'dna' if defined($self->{'cdna'});
  my $node_id = $self->{'protein_tree'}->node_id;
  my $table_name = 'protein_tree_hmmprofile' . "_" . $type;
  my $hmm_type = $self->{'hmm_type'};
  my $query = "SELECT hmmprofile FROM $table_name WHERE type=\"$hmm_type\" AND node_id=$node_id";
  print STDERR "$query\n" if ($self->debug);
  my $sth = $self->{comparaDBA}->dbc->prepare($query);
  $sth->execute;
  my $result = $sth->fetch;
  if (defined($result)) {
    # Has been done already
    $self->{done} = 1;
    return;
  }

  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }
  if ($self->{'protein_tree'}->get_tagvalue('gene_count') 
      > $self->{'max_gene_count'}) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
    throw("BuildHMM : cluster size over threshold and FAIL it");
  }

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut


sub run {
  my $self = shift;

  $self->check_if_exit_cleanly;
  if ($self->{done}) {return;}
  $self->run_buildhmm;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores proteintree
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  $self->check_if_exit_cleanly;
  if ($self->{done}) {return;}
  $self->store_hmmprofile;
}


sub DESTROY {
  my $self = shift;

  if($self->{'protein_tree'}) {
    printf("BuildHMM::DESTROY  releasing tree\n") if($self->debug);
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
  }

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

  if (defined $params->{'analysis_data_id'}) {
    my $analysis_data_id = $params->{'analysis_data_id'};
    my $ada = $self->db->get_AnalysisDataAdaptor;
    my $new_params = eval($ada->fetch_by_dbID($analysis_data_id));
    if (defined $new_params) {
      $params = $new_params;
    }
  }

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  if(defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree'} =
         $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
         fetch_node_by_node_id($params->{'protein_tree_id'});
  }
  if(defined($params->{'cdna'})) {
      $self->{'cdna'} = $params->{'cdna'};
  }

  if(defined($params->{'notaxon'})) {
      $self->{'notaxon'} = $params->{'notaxon'};
  }

  $self->{'max_gene_count'} = 
    $params->{'max_gene_count'} if(defined($params->{'max_gene_count'}));

  if(defined($params->{'species_tree_file'})) {
    $self->{'species_tree_file'} = $params->{'species_tree_file'};
  }

  if(defined($params->{'honeycomb_dir'})) {
    $self->{'honeycomb_dir'} = $params->{'honeycomb_dir'};
  }

  return;

}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id   : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
}


sub run_buildhmm
{
  my $self = shift;

  my $starttime = time()*1000;

  $self->{'input_aln'} = $self->dumpTreeMultipleAlignmentToWorkdir
    (
     $self->{'protein_tree'}
    );
  return unless($self->{'input_aln'});

  $self->{'hmm_file'} = $self->{'input_aln'} . "_hmmbuild.hmm ";

  my $hmmer_dir = "/software/pfam/src/hmmer-3.0.a1/bin/";
  my $buildhmm_executable;
  unless (-e $buildhmm_executable) {
    if (-e "/proc/version") {
      $buildhmm_executable = $hmmer_dir . "hmmbuild";
    }
  }
  throw("can't find a hmmbuild executable to run\n") 
    unless(-e $buildhmm_executable);

  ## as in treefam
  # $hmmbuild --amino -g -F $file.hmm $file >/dev/null

  my $cmd = $buildhmm_executable;
  $cmd .= " --dna "   if      defined($self->{'cdna'});
  $cmd .= " --amino " unless  defined($self->{'cdna'});
  $cmd .= $self->{'hmm_file'};
  $cmd .= " ". $self->{'input_aln'};
  $cmd .= " 2>&1 > /dev/null" unless($self->debug);

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  my $worker_temp_directory = $self->worker_temp_directory;
  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    $self->check_job_fail_options;
    throw("error running hmmbuild, $!\n");
  }

# HMMER3
#   my $calibratehmm_executable;
#   $DB::single=1;1;
#   unless (-e $calibratehmm_executable) {
#     if (-e "/proc/version") {
#       $calibratehmm_executable = $hmmer_dir . "hmmcalibrate";
#     }
#   }
#   throw("can't find a hmmcalibrate executable to run\n") 
#     unless(-e $calibratehmm_executable);

#   $cmd = '';
#   $cmd = $calibratehmm_executable;
#   $cmd .= ' --cpu 1';
#   $cmd .= ' --num 5000';
#   $cmd .= " " . $self->{'hmm_file'};
#   $cmd .= " 2>&1 > /dev/null" unless($self->debug);
#   unless(system("cd $worker_temp_directory; $cmd") == 0) {
#     print("$cmd\n");
#     $self->check_job_fail_options;
#     throw("error running hmmcalibrate, $!\n");
#   }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  my $runtime = time()*1000-$starttime;

  $self->{'protein_tree'}->store_tag('BuildHMM_runtime_msec', $runtime);
}


sub check_job_fail_options
{
  my $self = shift;

  if($self->input_job->retry_count >= 2) {
    $self->dataflow_output_id($self->input_id, 2);
    $self->input_job->update_status('FAILED');
  
    if($self->{'protein_tree'}) {
      $self->{'protein_tree'}->release_tree;
      $self->{'protein_tree'} = undef;
    }
    throw("BuildHMM job failed >=3 times: try something else and FAIL it");
  }
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir
{
  my $self = shift;
  my $tree = shift;
  
  my $leafcount = scalar(@{$tree->get_all_leaves});

  $self->{'file_root'} = 
    $self->worker_temp_directory. $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $self->{'file_root'} . ".aln";
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  my @to_delete;
  $DB::single=1;1;
  if (defined($self->{notaxon})) {
    foreach my $leaf (@{$tree->get_all_leaves}) {
      next unless ($leaf->taxon_id eq $self->{notaxon});
      push @to_delete, $leaf;
    }
    $tree = $tree->remove_nodes(\@to_delete);
  }

  my $sa = $tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     -cdna=>$self->{'cdna'},
     -stop2x => 1
    );
  $sa->set_displayname_flat(1);
  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  my $stk_file = $self->{'file_root'} . ".stk";
  my $cmd = "/usr/local/ensembl/bin/sreformat stockholm $aln_file > $stk_file";
  unless( system("$cmd") == 0) {
    print("$cmd\n");
    $self->check_job_fail_options;
    throw("error running sreformat, $!\n");
  }

  $self->{'input_aln'} = $stk_file;
  return $stk_file;
}


sub store_hmmprofile
{
  my $self = shift;
  my $hmm_file =  $self->{'hmm_file'};
  my $tree = $self->{'protein_tree'};
  
  #parse hmmer file
  print("load from file $hmm_file\n") if($self->debug);
  open (FH, $hmm_file) or throw("Couldnt open hmm_file [$hmm_file]");
  $self->{'hmm_text'} = join('', <FH>);
  close(FH);

  my $type = undef; $type = 'dna' if defined($self->{'cdna'});
  my $table_name = 'protein_tree_hmmprofile' . "_" . $type;
  my $sth = $self->{comparaDBA}->dbc->prepare("INSERT INTO $table_name VALUES (?,?,?)");
  $sth->execute($tree->node_id, $self->{hmm_type},$self->{hmm_text});

  return undef;
}

1;
