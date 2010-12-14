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
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::SimpleAlign;
use Bio::AlignIO;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'max_gene_count'        => 1000000,
            'cdna'                  => 0,
            'sreformat'             => '/usr/local/ensembl/bin/sreformat',
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

    $self->check_if_exit_cleanly;

    my $protein_tree_id     = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
    my $protein_tree        = $self->compara_dba->get_ProteinTreeAdaptor->fetch_node_by_node_id( $protein_tree_id )
                                        or die "Could not fetch protein_tree with protein_tree_id='$protein_tree_id'";
    $self->param('protein_tree', $protein_tree);

    my $hmm_type = $self->param('cdna') ? 'dna' : 'aa';

    if ($self->param('notaxon')) {
        $hmm_type .= "_notaxon" . "_" . $self->param('notaxon');
    }
    if ($self->param('taxon_ids')) {
        $hmm_type .= "_" . join(':', @{$self->param('taxon_ids')});
    }
    $self->param('hmm_type', $hmm_type);

    my $node_id = $self->param('protein_tree')->node_id;
    my $table_name = 'protein_tree_hmmprofile';
    my $query = "SELECT hmmprofile FROM $table_name WHERE type=\"$hmm_type\" AND node_id=$node_id";
    print STDERR "$query\n" if ($self->debug);
    my $sth = $self->compara_dba->dbc->prepare($query);
    $sth->execute;
    my $result = $sth->fetch;
    if (defined($result)) { # Has been done already
        $self->param('done', 1);
        return;
    }

    if ($self->param('protein_tree')->get_tagvalue('gene_count') > $self->param('max_gene_count')) {
        $self->dataflow_output_id($self->input_id, 2);      # this does not seem to be wired to anything at the moment?
        $self->param('protein_tree')->release_tree;
        $self->param('protein_tree', undef);
        $self->input_job->transient_error(0);
        $self->throw("BuildHMM : cluster size over threshold");    # maybe we should make the success/failure dependent on the success of the dataflow?
    }

  my @to_delete;

  if ($self->param('notaxon')) {
    foreach my $leaf (@{$protein_tree->get_all_leaves}) {
      next unless ($leaf->taxon_id eq $self->param('notaxon'));
      push @to_delete, $leaf;
    }
    $protein_tree = $protein_tree->remove_nodes(\@to_delete);
  }

  if ($self->param('taxon_ids')) {
    my $taxon_ids_to_keep;
    foreach my $taxon_id (@{$self->param('taxon_ids')}) {
      $taxon_ids_to_keep->{$taxon_id} = 1;
    }
    foreach my $leaf (@{$protein_tree->get_all_leaves}) {
      next if (defined($taxon_ids_to_keep->{$leaf->taxon_id}));
      push @to_delete, $leaf;
    }
    $protein_tree = $protein_tree->remove_nodes(\@to_delete);
  }

  if (!defined($protein_tree)) {
    $self->param('done', 1);
  }

  if (2 > (scalar @{$protein_tree->get_all_leaves})) {
    $self->param('done', 1);
  }
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

    $self->check_if_exit_cleanly;

    unless($self->param('done')) {
        $self->run_buildhmm;
    }
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores hmmprofile
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->check_if_exit_cleanly;

    unless($self->param('done')) {
        $self->store_hmmprofile;
    }
}


sub DESTROY {
  my $self = shift;

  if($self->param('protein_tree')) {
    printf("BuildHMM::DESTROY  releasing tree\n") if($self->debug);
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


sub run_buildhmm {
  my $self = shift;

  my $starttime = time()*1000;

  my $stk_file = $self->dumpTreeMultipleAlignmentToWorkdir ( $self->param('protein_tree') ) or return;
  return if($self->param('done'));

  my $hmm_file = $self->param('hmm_file', $stk_file . '_hmmbuild.hmm');

  my $hmmer_dir = "/software/ensembl/compara/hmmer3/hmmer-3.0/src/";
  my $buildhmm_executable = $self->analysis()->program_file();
  unless (-e $buildhmm_executable) {
    if (-e "/proc/version") {
      $buildhmm_executable = $hmmer_dir . "hmmbuild";
    }
  }
  $self->throw("can't find a hmmbuild executable to run\n") 
    unless(-e $buildhmm_executable);

  ## as in treefam
  # $hmmbuild --amino -g -F $file.hmm $file >/dev/null

  my $cmd = $buildhmm_executable;
  $cmd .= ($self->param('cdna') ? ' --dna ' : ' --amino ');

  $cmd .= $hmm_file;
  $cmd .= " ". $stk_file;
  $cmd .= " 2>&1 > /dev/null" unless($self->debug);

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  my $worker_temp_directory = $self->worker_temp_directory;
  $cmd = "cd $worker_temp_directory ; $cmd";
  if(system($cmd)) {
    $self->throw("could not run '$cmd': $!\n");
  }

  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $runtime = time()*1000-$starttime;

  $self->param('protein_tree')->store_tag('BuildHMM_runtime_msec', $runtime);
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $protein_tree = shift;
  
  my $leafcount = scalar(@{$protein_tree->get_all_leaves});

  my $file_root = $self->worker_temp_directory. $protein_tree->node_id;
  $file_root =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . '.aln';
#  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  my $sa = $protein_tree->get_SimpleAlign (
     -id_type => 'MEMBER',
     -cdna => $self->param('cdna'),
     -stop2x => 1
  );
  $sa->set_displayname_flat(1);

  # Pairwise alns can sometimes be empty
  if (0 == scalar($sa->each_seq)) {
    return $self->param('done', 1);
  }

  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  unless(-e $aln_file and -s $aln_file) {
    $self->throw("There are no alignments in '$aln_file', cannot continue");
  }

  my $stk_file = $file_root . '.stk';
  my $sreformat = $self->param('sreformat');
  my $cmd = "$sreformat stockholm $aln_file > $stk_file";
  if(system($cmd)) {
    $self->throw("could not run '$cmd': $!\n");
  }
  unless(-e $stk_file and -s $stk_file) {
    $self->throw("'$cmd' did not produce any data in '$stk_file'");
  }

  return $stk_file;
}


sub store_hmmprofile {
  my $self = shift;
  my $hmm_file =  $self->param('hmm_file');
  my $protein_tree = $self->param('protein_tree');
  
  #parse hmmer file
  print("load from file $hmm_file\n") if($self->debug);
  open (FH, $hmm_file) or $self->throw("Couldnt open hmm_file [$hmm_file]");
  my $hmm_text = join('', <FH>);
  close(FH);

  my $table_name = 'protein_tree_hmmprofile';
  my $sth = $self->compara_dba->dbc->prepare("INSERT INTO $table_name VALUES (?,?,?)");
  $sth->execute($protein_tree->node_id, $self->param('hmm_type'), $hmm_text);
}

1;
