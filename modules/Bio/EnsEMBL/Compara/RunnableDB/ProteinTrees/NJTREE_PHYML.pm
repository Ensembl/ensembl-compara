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
use Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree');


sub param_defaults {
    return {
            'cdna'              => 1,   # always use cdna for njtree_phyml
            'bootstrap'         => 1,
		'check_split_genes' => 1,
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
  $self->store_proteintree;
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

  $self->check_for_split_genes if ($self->param('check_split_genes')) ;

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
  $self->parse_newick_into_proteintree( $newick_file );

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
  unless ($self->param('gs_mirror') =~ /FALSE/) {
    my $holding_node = $alignment_edits->holding_node;
    foreach my $link (@{$holding_node->links}) {
      my $node1 = $link->get_neighbor($holding_node);
      my $protein1 = $protein_tree->find_leaf_by_node_id($node1->node_id);
      #print STDERR "node1 ", $node1, " ", $protein1, "\n";
      my $name1 = ($protein1->member_id)."_".($self->param('use_genomedb_id') ? $protein1->genome_db_id : $protein1->taxon_id);
      my $cdna = $protein1->cdna_alignment_string;
      #print STDERR "cnda1 $cdna\n";
      foreach my $node2 (@{$node1->all_nodes_in_graph}) {
        my $protein2 = $protein_tree->find_leaf_by_node_id($node2->node_id);
        #print STDERR "node2 ", $node2, " ", $protein2, "\n";
        next if $node2->node_id eq $node1->node_id;
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

sub store_proteintree
{
    my $self = shift;

    my $tree = $self->param('protein_tree') or return;
    my $tree_adaptor = $self->param('tree_adaptor');

    printf("PHYML::store_proteintree\n") if($self->debug);

    $tree->root->build_leftright_indexing(1);
    $tree_adaptor->store($tree);
    $self->compara_dba->get_GeneTreeNodeAdaptor->delete_nodes_not_in_tree($tree->root);

    if($self->debug >1) {
        print("done storing - now print\n");
        $tree->print_tree;
    }

    $self->store_tags($tree->root);

    $self->_store_tree_tags;

}

sub store_tags
{
    my $self = shift;
    my $node = shift;

    if (not $node->is_leaf) {
        my $node_type;
        if ($node->has_tag('node_type')) {
            $node_type = $node->get_tagvalue('node_type');
        } elsif ($node->get_tagvalue("DD", 0)) {
            $node_type = 'dubious';
        } elsif ($node->get_tagvalue('Duplication', '') eq '1') {
            $node_type = 'duplication';
        } else {
            $node_type = 'speciation';
        }
        $node->store_tag('node_type', $node_type);
        if ($self->debug) {
            print "store node_type: $node_type"; $node->print_node;
        }
    }

    if ($node->has_tag("E")) {
        my $n_lost = $node->get_tagvalue("E");
        $n_lost =~ s/.{2}//;        # get rid of the initial $-
        my @lost_taxa = split('-', $n_lost);
        foreach my $taxon (@lost_taxa) {
            if ($self->debug) {
                printf("store lost_taxon_id : $taxon "); $node->print_node;
            }
            $node->store_tag('lost_taxon_id', $taxon, 1);
        }
    }

    my %mapped_tags = ('B' => 'bootstrap', 'SIS' => 'species_intersection_score', 'T' => 'tree_support');
    foreach my $tag (keys %mapped_tags) {
        if ($node->has_tag($tag)) {
            my $value = $node->get_tagvalue($tag);
            my $db_tag = $mapped_tags{$tag};
            # Because the duplication_confidence_score won't be computed for dubious nodes
            $db_tag = 'duplication_confidence_score' if ($node->get_tagvalue('node_type') eq 'dubious' and $tag eq 'SIS');
            $node->store_tag($db_tag, $value);
            if ($self->debug) {
                printf("store $tag as $db_tag: $value"); $node->print_node;
            }
        }
    }

    foreach my $child (@{$node->children}) {
        $self->store_tags($child);
    }
}

sub parse_newick_into_proteintree {
  my $self = shift;
  my $newick_file = shift;

  my $tree = $self->param('protein_tree');
  
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $tree->root->flatten_tree;
  $tree->root->print_tree(20) if($self->debug);
  foreach my $node (@{$tree->root->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);

  my $newroot = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, "Bio::EnsEMBL::Compara::GeneTreeNode");
  $newroot->print_tree(20) if($self->debug > 1);

  my $nsplits = 0;
  my $split_genes = $self->param('split_genes');
  print STDERR "Retrieved split_genes hash: ", Dumper($split_genes) if $self->debug;

  while ( my ($name, $other_name) = each(%{$split_genes})) {
        print STDERR "$name is split_gene of $other_name\n" if $self->debug;
        my $node = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $node->name($name);
        my $othernode = $newroot->find_node_by_name($other_name);
        print STDERR "$node is split_gene of $othernode\n" if $self->debug;
        my $newnode = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $nsplits++;
        $newnode->node_id(-$nsplits);
        $othernode->parent->add_child($newnode);
        $newnode->add_child($othernode);
        $newnode->add_child($node);
        $newnode->add_tag('node_type', 'gene_split');
        $newnode->print_tree(10);
    }

  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_id = $1;
    $leaf->add_tag('name', $member_id);
  }
  $newroot->print_tree(20) if($self->debug > 1);

  # Leaves of newick tree are named with member_id of members from
  # input tree move members (leaves) of input tree into newick tree to
  # mirror the 'member_id' nodes
  foreach my $member (@{$tree->root->get_all_leaves}) {
    my $tmpnode = $newroot->find_node_by_name($member->member_id);
    if($tmpnode) {
      $member->Bio::EnsEMBL::Compara::AlignedMember::copy($tmpnode);
      bless $tmpnode, 'Bio::EnsEMBL::Compara::GeneTreeMember';
      $tmpnode->node_id($member->node_id);
      $tmpnode->adaptor($member->adaptor);
    } else {
      print("unable to find node in newick for member");
      $member->print_member;
    }
  }

  $newroot->node_id($tree->node_id);
  $newroot->adaptor($tree->root->adaptor);
  # to keep the link to the super-tree
  if ($tree->root->has_parent) {
      $tree->root->parent->add_child($newroot);
   }

  # Newick tree is now empty so release it
  $tree->root->release_tree;
  $tree->root($newroot);
  $newroot->tree($tree);

  $newroot->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMembers as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
      $self->throw("Phyml tree does not have all leaves as GeneTreeMembers\n");
    }
  }
  return $newroot;
}

sub _store_tree_tags {
    my $self = shift;
    my $tree = $self->param('protein_tree');

    print "Storing Tree tags...\n";

    my @leaves = @{$tree->root->get_all_leaves};
    my @nodes = @{$tree->root->get_all_nodes};

    # Tree number of leaves.
    my $tree_num_leaves = scalar(@leaves);
    $tree->store_tag("tree_num_leaves",$tree_num_leaves);

    # Tree number of human peptides contained.
    my $num_hum_peps = 0;
    foreach my $leaf (@leaves) {
	$num_hum_peps++ if ($leaf->taxon_id == 9606);
    }
    $tree->store_tag("tree_num_human_peps",$num_hum_peps);

    # Tree max root-to-tip distance.
    my $tree_max_length = $tree->root->max_distance;
    $tree->store_tag("tree_max_length",$tree_max_length);

    # Tree max single branch length.
    my $tree_max_branch = 0;
    foreach my $node (@nodes) {
        my $dist = $node->distance_to_parent;
        $tree_max_branch = $dist if ($dist > $tree_max_branch);
    }
    $tree->store_tag("tree_max_branch",$tree_max_branch);

    # Tree number of duplications and speciations.
    my $num_dups = 0;
    my $num_specs = 0;
    foreach my $node (@nodes) {
        my $node_type = $node->get_tagvalue("node_type");
        if ((defined $node_type) and ($node_type ne 'speciation')) {
            $num_dups++;
        } else {
            $num_specs++;
        }
    }
    $tree->store_tag("tree_num_dup_nodes",$num_dups);
    $tree->store_tag("tree_num_spec_nodes",$num_specs);

    print "Done storing stuff!\n" if ($self->debug);
}

sub check_for_split_genes {
  my $self = shift;
  my $protein_tree = $self->param('protein_tree');

  my $alignment_edits = $self->param('alignment_edits', new Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs);

  my $tmp_time = time();

  my @all_protein_leaves = @{$protein_tree->get_all_leaves};
  printf("%1.3f secs to fetch all leaves\n", time()-$tmp_time) if ($self->debug);

  if($self->debug) {
    printf("%d proteins in tree\n", scalar(@all_protein_leaves));
  }
  printf("build paralogs graph\n") if($self->debug);
  my @genepairlinks;
  my $graphcount = 0;
  my $tree_node_id = $protein_tree->node_id;
  while (my $protein1 = shift @all_protein_leaves) {
    foreach my $protein2 (@all_protein_leaves) {
      next unless ($protein1->genome_db_id == $protein2->genome_db_id);
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link
        (
         $protein1, $protein2, 0
        );
      $genepairlink->add_tag("tree_node_id", $tree_node_id);
      push @genepairlinks, $genepairlink;
      print STDERR "build graph $graphcount\n" if ($graphcount++ % 10 == 0);
    }
  }
  printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);

  # We sort the pairings by seq_region (chr) name, then by distance between
  # the start of link_node pairs.
  # This is to try to do the joining up of cdnas in the best order in
  # cases of e.g. 2 cases of 3-way split genes in same species.
  my @sorted_genepairlinks = sort { 
    $a->{_link_node1}->chr_name <=> $b->{_link_node1}->chr_name 
 || $a->{_link_node2}->chr_name <=> $b->{_link_node2}->chr_name 
 || abs($a->{_link_node1}->chr_start - $a->{_link_node2}->chr_start) <=> abs($b->{_link_node1}->chr_start - $b->{_link_node2}->chr_start) } @genepairlinks;

  foreach my $genepairlink (@sorted_genepairlinks) {
    my $type = 'within_species_paralog';
    my ($protein1, $protein2) = $genepairlink->get_nodes;
    my ($cigar_line1, $perc_id1, $perc_pos1,
        $cigar_line2, $perc_id2, $perc_pos2) = 
        $self->generate_attribute_arguments($protein1, $protein2,$type);
    print STDERR "Pair: ", $protein1->stable_id, " - ", $protein2->stable_id, "\n" if ($self->debug);

    # Checking for gene_split cases
    if ($type eq 'within_species_paralog' && 0 == $perc_id1 && 0 == $perc_id2 && 0 == $perc_pos1 && 0 == $perc_pos2) {

      # Condition A1: If same seq region and less than 1MB distance
      my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;
      if ($gene_member1->chr_name eq $gene_member2->chr_name 
          && (1000000 > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
          && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

        # Condition A2: there have to be the only 2 or 3 protein coding
        # genes in the range defined by the gene pair. This should
        # strictly be 2, only the pair in question, but in clean perc_id
        # = 0 cases, we allow for 2+1: the rare case where one extra
        # protein coding gene is partially or fully embedded in another.
        my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
        my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
        if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
        if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
        my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;
        print STDERR "Checking split genes overlap\n";
        my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};

        if (3 < scalar @genes_in_range) {
          foreach my $gene (@genes_in_range) {
            print STDERR "More than 2 genes in range...";
            print STDERR "Genes in range ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n";
          }
          next;
        }
        $alignment_edits->add_connection($protein1->node_id, $protein2->node_id);
      }


      # This is a second level of contiguous gene split events, more
      # stringent on contig but less on alignment, for "skidding"
      # alignment cases.

      # These cases take place when a few of the aminoacids in the
      # alignment have been wrongly displaced from the columns that
      # correspond to the fragment, so the identity level is slightly
      # above 0. This small number of misplaced aminoacids look like
      # "skid marks" in the alignment view.

      # Condition B1: all 4 percents below 10
    } elsif ($type eq 'within_species_paralog' 
             && $perc_id1 < 10 
             && $perc_id2 < 10 
             && $perc_pos1 < 10 
             && $perc_pos2 < 10) {
      my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;

    # Condition B2: If non-overlapping and smaller than 500kb start and 500kb end distance
      if ($gene_member1->chr_name eq $gene_member2->chr_name 
          && (500000 > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
          && (500000 > abs($gene_member1->chr_end - $gene_member2->chr_end)) 
          && (($gene_member1->chr_start - $gene_member2->chr_start)*($gene_member1->chr_end - $gene_member2->chr_end)) > 1
          && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

    # Condition B3: they have to be the only 2 genes in the range:
        my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
        my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
        if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
        if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
        my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;

        my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};
        if (2 < scalar @genes_in_range) {
          foreach my $gene (@genes_in_range) {
            print STDERR "More than 2 genes in range...";
            print STDERR "Genes in range ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n";
          }
          next;
        }

    # Condition B4: discard if the smaller protein is 1/10 or less of the larger and all percents above 2
        my $len1 = length($protein1->sequence); my $len2 = length($protein2->sequence); my $temp;
        if ($len1 < $len2) { $temp = $len1; $len1 = $len2; $len2 = $temp; }
        if ($len1/$len2 > 10 && $perc_id1 > 2 && $perc_id2 > 2 && $perc_pos1 > 2 && $perc_pos2 > 2) {
          next;
        }
        $alignment_edits->add_connection($protein1->node_id, $protein2->node_id);
      }
    }
  }

  printf("%1.3f secs label gene splits\n", time()-$tmp_time) if($self->debug>1);

  if($self->debug) {
    printf("%d pairings\n", scalar(@sorted_genepairlinks));
  }

  return 1;
}


1;
