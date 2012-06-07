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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input into the NJTREE PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $njtree_phyml = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$njtree_phyml->fetch_input(); #reads from DB
$njtree_phyml->run();
$njtree_phyml->output();
$njtree_phyml->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML;

use strict;

use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;

use Bio::AlignIO;
use Bio::SimpleAlign;

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub param_defaults {
    return {
            'cdna'              => 1,   # always use cdna for njtree_phyml
            'bootstrap'         => 1,
		'check_split_genes' => 1,
            'store_tree_support'    => 1,
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->check_if_exit_cleanly;

    $self->param('member_adaptor', $self->compara_dba->get_MemberAdaptor);
    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $protein_tree_id     = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
    my $protein_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $protein_tree_id )
                                        or die "Could not fetch protein_tree with protein_tree_id='$protein_tree_id'";
    $protein_tree->print_tree(10) if($self->debug);

    $self->param('protein_tree', $protein_tree);
}


sub run {
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->run_njtree_phyml;
}


sub write_output {
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->store_genetree($self->param('protein_tree'));
  if (defined $self->param('output_dir')) {
    system("zip -r -9 ".($self->param('output_dir'))."/".($self->param('protein_tree_id')).".zip ".$self->worker_temp_directory);
  }
}


sub DESTROY {
  my $self = shift;

  if(my $protein_tree = $self->param('protein_tree')) {
    printf("NJTREE_PHYML::DESTROY  releasing tree\n") if($self->debug);
    $protein_tree->release_tree;
    $self->param('protein_tree', undef);
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################


sub run_njtree_phyml {
  my $self = shift;

    my $protein_tree = $self->param('protein_tree');

  my $starttime = time()*1000;

  my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir ( $protein_tree->root ) or return;

  my $newick_file = $input_aln . "_njtree_phyml_tree.txt ";

  my $treebest_exe = $self->param('treebest_exe')
      or die "'treebest_exe' is an obligatory parameter";

  die "Cannot execute '$treebest_exe'" unless(-x $treebest_exe);

  my $species_tree_file = $self->get_species_tree_file();

    $self->compara_dba->dbc->disconnect_when_inactive(1);
  # ./njtree best -f spec-v4.1.nh -p tree -o $BASENAME.best.nhx \
  # $BASENAME.nucl.mfa -b 100 2>&1/dev/null

  if (1 == $self->param('bootstrap')) {
    my $comput_ok = 0;
    until ($comput_ok) {

    my $cmd = $treebest_exe;
    $cmd .= " best ";
    if(my $max_diff_lk = $self->param('max_diff_lk')) {
        $cmd .= " -Z $max_diff_lk";
    }
    if ($species_tree_file) {
      $cmd .= " -f ". $species_tree_file;
    }
    $cmd .= " ". $input_aln;
    $cmd .= " -p interm ";
    $cmd .= " -o " . $newick_file;
    if ($self->param('extra_args')) {
      $cmd .= " ".($self->param('extra_args')).' ';
    }
    my $logfile = $self->worker_temp_directory. "proteintree_". $protein_tree->root_id . ".log";
    my $errfile = $self->worker_temp_directory. "proteintree_". $protein_tree->root_id . ".err";
    $cmd .= " 1>$logfile 2>$errfile";
    #     $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    my $worker_temp_directory = $self->worker_temp_directory;
    my $full_cmd = defined $worker_temp_directory ? "cd $worker_temp_directory; $cmd" : "$cmd";
    print STDERR "Running:\n\t$full_cmd\n" if($self->debug);

    if(my $rc = system($full_cmd)) {
      my $system_error = $!;

      if(my $segfault = (($rc != -1) and ($rc & 127 == 11))) {
          $self->throw("'$full_cmd' resulted in a segfault");
      }
      print STDERR "$full_cmd\n";
      open(ERRFILE, $errfile) or die "Could not open logfile '$errfile' for reading : $!\n";
	my $logfile = "";
	my $handled_failure = 0;
      while (<ERRFILE>) {
        if (!($_ =~ /^Large distance/)) {
	     $logfile .= $_;
        }
        if (($_ =~ /NNI/) || ($_ =~ /Optimize_Br_Len_Serie/) || ($_ =~ /Optimisation failed/) || ($_ =~ /Brent failed/))  {
	     $handled_failure = 1;
	  }
	}
	if ($handled_failure) {
	    # Increase the tolerance max_diff_lk in the computation

          my $max_diff_lk_value = $self->param('max_diff_lk') ?  $self->param('max_diff_lk') : 1e-5;
	    $max_diff_lk_value *= 10;
          $self->param('max_diff_lk', $max_diff_lk_value);
      }
      $self->throw("error running njtree phyml: $system_error\n$logfile");
    } else {
        $comput_ok = 1;
    }
    }
  } elsif (0 == $self->param('bootstrap')) {
    # first part
    # ./njtree phyml -nS -f species_tree.nh -p 0.01 -o $BASENAME.cons.nh $BASENAME.nucl.mfa
    my $cmd = $treebest_exe;
    $cmd .= " phyml -nS";
    if($species_tree_file) {
      $cmd .= " -f ". $species_tree_file;
    }
    $cmd .= " ". $input_aln;
    $cmd .= " -p 0.01 ";

    my $intermediate_newick_file = $input_aln . "_intermediate_njtree_phyml_tree.txt ";
    $cmd .= " -o " . $intermediate_newick_file;
    $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    if(system("cd $worker_temp_directory; $cmd")) {
      my $system_error = $!;
      $self->throw("Error running njtree phyml noboot (step 1 of 2) : $system_error");
    }
    # second part
    # nice -n 19 ./njtree sdi -s species_tree.nh $BASENAME.cons.nh > $BASENAME.cons.nhx
    $cmd = $treebest_exe;
    $cmd .= " sdi ";
    if ($species_tree_file) {
      $cmd .= " -s ". $species_tree_file;
    }
    $cmd .= " ". $intermediate_newick_file;
    $cmd .= " 1> " . $newick_file;
    $cmd .= " 2> /dev/null" unless($self->debug);

    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    if(system("cd $worker_temp_directory; $cmd")) {
      my $system_error = $!;
      $self->throw("Error running njtree phyml noboot (step 2 of 2) : $system_error");
    }
  } else {
    $self->throw("NJTREE PHYML -- wrong bootstrap option");
  }

  $self->compara_dba->dbc->disconnect_when_inactive(0);
      #parse the tree into the datastucture:
  $self->parse_newick_into_tree( $newick_file, $self->param('protein_tree') );

  my $runtime = time()*1000-$starttime;

  $protein_tree->store_tag('NJTREE_PHYML_runtime_msec', $runtime);
}


########################################################
#
# GeneTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $protein_tree = shift;

  my $alignment_edits = $self->param('alignment_edits');

  my $leafcount = scalar(@{$protein_tree->get_all_leaves});
  if($leafcount<3) {
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", 
           $protein_tree->node_id);
    return undef;
  }

  my $file_root = $self->worker_temp_directory. "proteintree_". $protein_tree->node_id;
  $file_root =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . '.aln';
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = $self->param('use_genomedb_id') ? ('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  my %split_genes;

  ########################################
  # Gene split mirroring code
  #
  # This will have the effect of grouping the different
  # fragments of a gene split event together in a subtree
  #
  if ($self->param('check_split_genes')) {
    my $sth = $self->compara_dba->dbc->prepare('SELECT DISTINCT gene_split_id FROM split_genes JOIN gene_tree_member USING (member_id) JOIN gene_tree_node USING (node_id) WHERE root_id = ?');
    $sth->execute($self->param('protein_tree_id'));
    my $gene_splits = $sth->selectall_arrayref();
    $sth = $self->compara_dba->dbc->prepare('SELECT node_id FROM split_genes JOIN gene_tree_member USING (member_id) WHERE gene_split_id = ?');
    foreach my $gene_split (@$gene_splits) {
      $sth->execute($gene_split->{gene_split_id});
      my $partial_genes = $sth->fetchall_arrayref;
      my $node1 = shift @$partial_genes;
      my $protein1 = $protein_tree->find_leaf_by_node_id($node1->{node_id});
      #print STDERR "node1 ", $node1, " ", $protein1, "\n";
      my $name1 = ($protein1->member_id)."_".($self->param('use_genomedb_id') ? $protein1->genome_db_id : $protein1->taxon_id);
      my $cdna = $protein1->cdna_alignment_string;
      #print STDERR "cnda1 $cdna\n";
      foreach my $node2 (@$partial_genes) {
        my $protein2 = $protein_tree->find_leaf_by_node_id($node2->{node_id});
        #print STDERR "node2 ", $node2, " ", $protein2, "\n";
        my $name2 = ($protein2->member_id)."_".($self->param('use_genomedb_id') ? $protein2->genome_db_id : $protein2->taxon_id);
        $split_genes{$name2} = $name1;
        #print STDERR Dumper(%split_genes);
        print STDERR "Joining in ", $protein1->stable_id, " / $name1 and ", $protein2->stable_id, " / $name2 in input cdna alignment\n" if ($self->debug);
        my $other_cdna = $protein2->cdna_alignment_string;
        $cdna =~ s/-/substr($other_cdna, pos($cdna), 1)/eg;
        #print STDERR "cnda2 $cdna\n";
      }
      $protein1->{'cdna_alignment_string'} = $cdna;
        # We start with the original cdna alignment string of the first gene, and
        # add the position in the other cdna for every gap position, and iterate
        # through all the other cdnas
        # cdna1 = AAA AAA AAA AAA AAA --- --- --- --- --- --- --- --- --- --- --- ---
        # cdna2 = --- --- --- --- --- --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # become
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # and now then paired with 3, they becomes the full gene model:
        # cdna3 = --- --- --- --- --- --- --- --- --- --- --- --- CCC CCC CCC CCC CCC
        # and form:
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- CCC CCC CCC CCC CCC
        # We then directly override the cached cdna_alignment_string
        # hash, which will be used next time is called for
    }
  }
  ########################################

  print STDERR "fetching alignment\n" if ($self->debug);
  my $sa = $protein_tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     -cdna=>$self->param('cdna'),
     -stop2x => 1,
     %sa_params
    );
  # Removing duplicate sequences of split genes
  print STDERR "split_genes hash: ", Dumper(%split_genes), "\n" if $self->debug;
  foreach my $gene_to_remove (keys %split_genes) {
    $sa->remove_seq($sa->each_seq_with_id($gene_to_remove));
  }
  $self->param('split_genes', \%split_genes);

  $sa->set_displayname_flat(1);

  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  return $aln_file;
}


1;
