#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NCSecStructTree

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncsecstructtree = Bio::EnsEMBL::Compara::RunnableDB::NCSecStructTree->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncsecstructtree->fetch_input(); #reads from DB
$ncsecstructtree->run();
$ncsecstructtree->output();
$ncsecstructtree->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::NCSecStructTree;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  my $self = shift;

  my $starttime = time()*1000;

  $self->{'cdna'} = 1; #always use cdna for njtree_phyml
  $self->{'input_aln'} = $self->dumpMultipleAlignmentStructToWorkdir
    (
     $self->{'nc_tree'}
    );
  return unless($self->{'input_aln'});

# For long parameters, look at analysis_data
  if($self->{analysis_data_id}) {
    my $analysis_data_id = $self->{analysis_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[param1 param2 param3 analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} = 
         $self->compara_dba->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
  }

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_bootstrap_raxml;
  $self->run_ncsecstructtree;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

}


##########################################
#
# internal methods
#
##########################################


sub run_bootstrap_raxml {
  my $self = shift;

  my $aln_file    = $self->{'input_aln'};
  return unless (defined($aln_file));

  my $raxml_tag = $self->{nc_tree}->node_id . "." . $self->worker->process_id . ".raxml";
  my $raxml_executable = $self->analysis->program_file;
    unless (-e $raxml_executable) {
      print "Using default cmalign executable!\n";
      $raxml_executable = "/software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3";
  }
  $self->throw("can't find a raxml executable to run\n") unless(-e $raxml_executable);

  my $bootstrap_num = 10;
  my $root_id = $self->{nc_tree}->node_id;
  my $tag = 'ml_IT_' . $bootstrap_num;
  my $sql1 = "select value from nc_tree_tag where node_id=$root_id and tag='$tag'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  my $raxml_tree_string = $sth1->fetchrow_hashref;
  $sth1->finish;
  my $eval_tree;
  eval {
    $eval_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($raxml_tree_string->{value});
  };
  next unless(!defined($raxml_tree_string->{value}) || $@ || $self->debug);

  # /software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-PTHREADS-SSE3
  # -m GTRGAMMA -s nctree_20327.aln -N 10 -n nctree_20327.raxml.10
  my $cmd = $raxml_executable;
  $cmd .= " -T 2"; # ATTN, you need the PTHREADS version of raxml for this
  $cmd .= " -m GTRGAMMA";
  $cmd .= " -s $aln_file";
  $cmd .= " -N $bootstrap_num";
  $cmd .= " -n $raxml_tag.$bootstrap_num";

  my $worker_temp_directory = $self->worker_temp_directory;
  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  my $bootstrap_starttime = time()*1000;
  #  $DB::single=1;1;
  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    $self->throw("error running raxml, $!\n");
  }
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $bootstrap_msec = int(time()*1000-$bootstrap_starttime);

  my $ideal_msec = 30000; # 5 minutes
  my $time_per_sample = $bootstrap_msec / $bootstrap_num;
  my $ideal_bootstrap_num = $ideal_msec / $time_per_sample;
  if ($ideal_bootstrap_num < 10) {
    if   ($ideal_bootstrap_num < 5) { $self->{bootstrap_num} = 1; }
    else                            { $self->{bootstrap_num} = 10; }
  } elsif ($ideal_bootstrap_num > 100) {
    $self->{bootstrap_num} = 100;
  } else {
    $self->{bootstrap_num} = int($ideal_bootstrap_num);
  }

  my $raxml_output = $self->worker_temp_directory . "RAxML_bestTree." . "$raxml_tag.$bootstrap_num";

  $self->store_newick_into_protein_tree_tag_string($tag,$raxml_output);

  # Unlink run files
  my $temp_dir = $self->worker_temp_directory;
  my $temp_regexp = $temp_dir."*$raxml_tag.$bootstrap_num.RUN.*";
  system("rm -f $temp_regexp");
  return 1;
}

sub run_ncsecstructtree {
  my $self = shift;

  my $aln_file    = $self->{'input_aln'};
  return unless (defined($aln_file));
  my $struct_file = $self->{'struct_aln'};

  my $raxml_tag = $self->{nc_tree}->node_id . "." . $self->worker->process_id . ".raxml";
  my $raxml_executable = $self->analysis->program_file;
    unless (-e $raxml_executable) {
      print "Using default cmalign executable!\n";
      $raxml_executable = "/software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3";
  }
  $self->throw("can't find a raxml executable to run\n") unless(-e $raxml_executable);

  my $root_id = $self->{nc_tree}->node_id;
  foreach my $model ( qw(S16B S16A S7B S7C S6A S6B S6C S6D S6E S7A S7D S7E S7F S16) ) {
    my $tag = 'ss_IT_' . $model;
    my $sql1 = "select value from nc_tree_tag where node_id=$root_id and tag='$tag'";
    my $sth1 = $self->dbc->prepare($sql1);
    $sth1->execute;
    my $raxml_tree_string = $sth1->fetchrow_hashref;
    $sth1->finish;
    my $eval_tree;
    eval {
      $eval_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($raxml_tree_string->{value});
    };
    next unless(!defined($raxml_tree_string->{value}) || $@ || $self->debug);

    # /software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3
    # -m GTRGAMMA -s nctree_20327.aln -S nctree_20327.struct -A S7D -n nctree_20327.raxml
    my $cmd = $raxml_executable;
    $cmd .= " -T 2"; # ATTN, you need the PTHREADS version of raxml for this
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -S $struct_file" if (defined($struct_file));
    $cmd .= " -A $model";
    $cmd .= " -n $raxml_tag.$model";
    $cmd .= " -N " . $self->{bootstrap_num} if (defined($self->{bootstrap_num}));

    my $worker_temp_directory = $self->worker_temp_directory;
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);

    my $starttime = time()*1000;
    unless(system("cd $worker_temp_directory; $cmd") == 0) {
      $self->throw("error running raxml, $!\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(0);
    my $runtime_msec = int(time()*1000-$starttime);

    my $raxml_output = $self->worker_temp_directory . "RAxML_bestTree." . "$raxml_tag.$model";
    $self->{model} = $model;

    $self->store_newick_into_protein_tree_tag_string($tag,$raxml_output);
    my $model_runtime = $self->{model} . "_runtime_msec";
    $self->{'nc_tree'}->store_tag($model_runtime, $runtime_msec);

    # Unlink run files
    my $temp_dir = $self->worker_temp_directory;
    my $temp_regexp = $temp_dir."*$raxml_tag.$model.RUN.*";
    $DB::single=1;1;#??
    system("rm -f $temp_regexp");
  }

  return 1;
}

sub dumpMultipleAlignmentStructToWorkdir
{
  my $self = shift;
  my $tree = shift;

  my $leafcount = scalar(@{$tree->get_all_leaves});
  if($leafcount<4) {
    printf(STDERR "tree cluster %d has <4 proteins - can not build a raxml tree\n", 
           $tree->node_id);
    return undef;
  }

  $self->{'file_root'} = 
    $self->worker_temp_directory. "nctree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $self->{'file_root'} . ".aln";
  if($self->debug) {
    printf("dumpMultipleAlignmentStructToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = ($self->{use_genomedb_id}) ?	('-APPEND_GENOMEDB_ID', 1) :
    ('-APPEND_TAXON_ID', 1);

  my $sa = $tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     %sa_params,
    );
  $sa->set_displayname_flat(1);

  # Phylip header
  print OUTSEQ $sa->no_sequences, " ", $sa->length, "\n";
  # Phylip body
  my $count = 0;
  foreach my $aln_seq ($sa->each_seq) {
    print OUTSEQ $aln_seq->display_id, "\n";
    my $seq = $aln_seq->seq;

    # Here we do a trick for all Ns sequences by changing the first
    # nucleotide to an A so that raxml can at least do the tree for
    # the rest of the sequences, instead of giving an error
    if ($seq =~ /N+/) { $seq =~ s/^N/A/; }

    print OUTSEQ "$seq\n";
    $count++;
    print STDERR "sequences $count\n" if ($count % 50 == 0);
  }
  close OUTSEQ;

  my $struct_string = $self->{nc_tree}->get_tagvalue('ss_cons');
  # Allowed Characters are "( ) < > [ ] { } " and "."
  $struct_string =~ s/[^\(^\)^\<^\>^\[^\]^\{^\}^\.]/\./g;
  my $struct_file = $self->{'file_root'} . ".struct";
  if ($struct_string =~ /^\.+$/) {
    $struct_file = undef;
    # No struct file
  } else {
    open(STRUCT, ">$struct_file")
      or $self->throw("Error opening $struct_file for write");
    print STRUCT "$struct_string\n";
    close STRUCT;
  }
  $self->{'input_aln'} = $aln_file;
  $self->{'struct_aln'} = $struct_file;
  return $aln_file;
}

sub store_newick_into_protein_tree_tag_string {
  my $self = shift;
  my $tag = shift;
  my $newick_file = shift;

  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) {
    chomp $_;
    $newick .= $_;
  }
  close(FH);
  $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits

  $self->{'nc_tree'}->store_tag($tag, $newick);
  if (defined($self->{model})) {
    my $bootstrap_tag = $self->{model} . "_bootstrap_num";
    $self->{'nc_tree'}->store_tag($bootstrap_tag, $self->{bootstrap_num});
  }
}


1;
