=head1 LICENSE

  Copyright (c) 1999-2010 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncsecstructtree = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecModels->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncsecstructtree->fetch_input(); #reads from DB
$ncsecstructtree->run();
$ncsecstructtree->output();
$ncsecstructtree->write_output(); #writes to DB

=head1 DESCRIPTION

This RunnableDB builds phylogenetic trees using RAxML. RAxML can use several secondary
structure substitution models. This Runnable can run several of them in a row, but it
is recommended to run them in parallel.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
  +- Bio::EnsEMBL::Hive::Process

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::PrepareSecStructModels;

use strict;
use Time::HiRes qw(time);
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'models'      => [qw/S16B S16A S7B S7C S6A S6B S6C S6D S6E S7A S7D S7E S7F S16/],
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
    my $self = shift @_;

    $self->input_job->transient_error(0);
    my $nc_tree_id = $self->param('nc_tree_id') || die "'nc_tree_id' is an obligatory numeric parameter\n";
    $self->input_job->transient_error(1);

    my $nc_tree    = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($nc_tree_id) or $self->throw("Could not fetch nc_tree with id=$nc_tree_id");
    $self->param('nc_tree', $nc_tree);

    if(my $input_aln = $self->_dumpMultipleAlignmentStructToWorkdir($nc_tree) ) {
        $self->param('input_aln', $input_aln);
    } else {
        die "I can't write input alignment";
    }
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;
    my $nc_tree_id = $self->param('nc_tree_id');
    # First check the size of the alignents to compute:
    if ($self->param('tag_residue_count') > 150000) {
        $self->dataflow_output_id (
                                   {
                                    'nc_tree_id' => $nc_tree_id,
                                   }, -1
                                  );
        # Should we die here? Nothing more to do in the Runnable
        $self->input_job->incomplete(0);
        die "$nc_tree_id family is too big. Only fast trees will be computed\n";
    } else {
    # Run RAxML without any structure info first
        $self->_run_bootstrap_raxml;
    }
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    # Run RAxML with all selected secondary structure substitution models
    # $self->_run_ncsecstructtree;

#    my $input_aln = $self->param('input_aln');
#    my $struct_aln = $self->param('struct_aln');
    my $nc_tree_id = $self->param('nc_tree_id');
    my $models = $self->param('models');
    my $bootstrap_num = $self->param('bootstrap_num');

    for my $model (@$models) {
        $self->dataflow_output_id ( {
                                     'model' => $model,
                                     'nc_tree_id' => $nc_tree_id,
#                                     'input_aln' => $input_aln,
#                                     'struct_aln' => $struct_aln,
                                     'bootstrap_num' => $bootstrap_num
                                    }, 2); # fan
    }

}

sub _run_bootstrap_raxml {
    my $self = shift;

  my $aln_file = $self->param('input_aln');
  return unless (defined($aln_file));

  my $raxml_tag = $self->param('nc_tree')->node_id . "." . $self->worker->process_id . ".raxml";
  my $raxml_executable = $self->param('raxml_exe') || '/software/ensembl/compara/raxml/RAxML-7.2.8-ALPHA/raxmlHPC-SSE3';
  $self->throw("can't find a raxml executable to run: $raxml_executable\n") unless(-e $raxml_executable);
  $self->throw("Not an executable program: $raxml_executable\n") unless(-x $raxml_executable);

  my $bootstrap_num = 10;
  my $root_id = $self->param('nc_tree')->node_id;
  my $tag = 'ml_IT_' . $bootstrap_num;

  # Checks if the bootstrap tree is already in the DB (is this a rerun?)
  my $sql1 = "select value from nc_tree_tag where node_id=$root_id and tag='$tag'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  my $raxml_tree_string = $sth1->fetchrow_hashref;
  $sth1->finish;
  if ($raxml_tree_string->{value}) {
    my $eval_tree;
    # Checks the tree string can be parsed succsesfully
    eval {
      $eval_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($raxml_tree_string->{value});
    };
    if (defined($eval_tree) and !$@ and !$self->debug) {
      # The bootstrap RAxML tree has been obtained already and the tree can be parsed successfully.
      return;
    }
  }
#  return 0 unless(!defined($raxml_tree_string->{value}) || $@ || $self->debug);

  # /software/ensembl/compara/raxml/RAxML-7.2.8-ALPHA/raxmlHPC-SSE3
  # -m GTRGAMMA -s nctree_20327.aln -N 10 -n nctree_20327.raxml.10
  my $cmd = $raxml_executable;
  $cmd .= " -T 2"; # ATTN, you need the PTHREADS version of raxml for this
  $cmd .= " -m GTRGAMMA";
  $cmd .= " -s $aln_file";
  $cmd .= " -N $bootstrap_num";
  $cmd .= " -n $raxml_tag.$bootstrap_num";

  my $worker_temp_directory = $self->worker_temp_directory;
  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print "$cmd\n" if($self->debug);
  my $bootstrap_starttime = time()*1000;

  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    $self->throw("error running raxml\ncd $worker_temp_directory; $cmd\n $!\n");
  }
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $bootstrap_msec = int(time()*1000-$bootstrap_starttime);

  my $ideal_msec = 30000; # 5 minutes
  my $time_per_sample = $bootstrap_msec / $bootstrap_num;
  my $ideal_bootstrap_num = $ideal_msec / $time_per_sample;
  if ($ideal_bootstrap_num < 10) {
    if   ($ideal_bootstrap_num < 5) { $self->param('bootstrap_num',  1); }
    else                            { $self->param('bootstrap_num', 10); }
  } elsif ($ideal_bootstrap_num > 100) {
    $self->param('bootstrap_num', 100);
  } else {
    $self->param('bootstrap_num', int($ideal_bootstrap_num) );
  }

  my $raxml_output = $self->worker_temp_directory . "RAxML_bestTree." . "$raxml_tag.$bootstrap_num";

  $self->_store_newick_into_nc_tree_tag_string($tag,$raxml_output);

  # Unlink run files
  my $temp_dir = $self->worker_temp_directory;
  my $temp_regexp = $temp_dir."*$raxml_tag.$bootstrap_num.RUN.*";
  system("rm -f $temp_regexp");
  return 1;
}

sub _dumpMultipleAlignmentStructToWorkdir {
  my $self = shift;
  my $tree = shift;

  my $leafcount = scalar(@{$tree->get_all_leaves});
  if($leafcount<4) {
      $self->input_job->incomplete(0);
      #printf(STDERR "tree cluster %d has <4 proteins - can not build a raxml tree\n", $tree->node_id);
      my $tree_id = $tree->node_id;
      die "tree cluster $tree_id has <4 proteins -- can not build a raxml tree\n";
  }

  my $file_root = $self->worker_temp_directory. "nctree_". $tree->node_id;
  $file_root    =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . ".aln";
#   if($self->debug) {
#     printf("dumpMultipleAlignmentStructToWorkdir : %d members\n", $leafcount);
#     print("aln_file = '$aln_file'\n");
#   }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = ($self->param('use_genomedb_id')) ?	('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  my $sa = $tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     %sa_params,
    );
  $sa->set_displayname_flat(1);

  # Phylip header
  print OUTSEQ $sa->no_sequences, " ", $sa->length, "\n";
  $self->param('tag_residue_count', $sa->no_sequences * $sa->length);
  # Phylip body
  my $count = 0;
  foreach my $aln_seq ($sa->each_seq) {
    print OUTSEQ $aln_seq->display_id, " ";
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

  my $struct_string = $self->param('nc_tree')->get_tagvalue('ss_cons');
  # Allowed Characters are "( ) < > [ ] { } " and "."
  $struct_string =~ s/[^\(^\)^\<^\>^\[^\]^\{^\}^\.]/\./g;
  my $struct_file = $file_root . ".struct";
  if ($struct_string =~ /^\.+$/) {
    $struct_file = undef;
    # No struct file
  } else {
    open(STRUCT, ">$struct_file")
      or $self->throw("Error opening $struct_file for write");
    print STRUCT "$struct_string\n";
    close STRUCT;
  }
  $self->param('input_aln', $aln_file);
  $self->param('struct_aln', $struct_file);
  return $aln_file;
}

sub _store_newick_into_nc_tree_tag_string {
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

  $self->param('nc_tree')->store_tag($tag, $newick);
  if (defined($self->param('model'))) {
    my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
    $self->param('nc_tree')->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
  }
}


1;
