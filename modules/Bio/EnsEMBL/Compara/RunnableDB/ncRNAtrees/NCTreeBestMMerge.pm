#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $treebest_mmerge = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$treebest_mmerge->fetch_input(); #reads from DB
$treebest_mmerge->run();
$treebest_mmerge->output();
$treebest_mmerge->write_output(); #writes to DB

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


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCTreeBestMMerge;

use strict;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'clusterset_id'  => 1,
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
  my( $self) = @_;

      # Fetch sequences:
  $self->param('nc_tree', $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($self->param('nc_tree_id')) );

  $self->load_input_trees;

  my $treebest_exe = $self->param('treebest_exe')
          or die "'treebest_exe' is an obligatory parameter";
                  
  die "Cannot execute '$treebest_exe'" unless(-x $treebest_exe);
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

  if (defined($self->param('inputtrees_unrooted'))) {
    $self->reroot_inputtrees;
    $self->run_treebest_mmerge;
    $self->calculate_branch_lengths;
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
  my $self = shift;

  $self->store_nctree if (defined($self->param('inputtrees_unrooted')));
}

sub DESTROY {
  my $self = shift;

  if($self->param('nc_tree')) {
    printf("NctreeBestMMerge::DESTROY  releasing tree\n") if($self->debug);
    $self->param('nc_tree')->release_tree;
    $self->param('nc_tree', undef);
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################

sub get_species_tree_file {
    my $self = shift @_;

    unless( $self->param('species_tree_file') ) {

        unless( $self->param('species_tree_string') ) {

            my $tag_table_name = 'gene_tree_root_tag';

            my $sth = $self->dbc->prepare( "select value from $tag_table_name where tag='species_tree_string'" );
            $sth->execute;
            my ($species_tree_string) = $sth->fetchrow_array;
            $sth->finish;

            $self->param('species_tree_string', $species_tree_string)
                or die "Could not fetch 'species_tree_string' from $tag_table_name";
        }

        my $species_tree_string = $self->param('species_tree_string');
        eval {
            my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
            my @leaves = @{$eval_species_tree->get_all_leaves};
        };
        if($@) {
            die "Error parsing species tree from the string '$species_tree_string'";
        }

            # store the string in a local file:
        my $species_tree_file = $self->worker_temp_directory . "spec_tax.nh";
        open SPECIESTREE, ">$species_tree_file" or die "Could not open '$species_tree_file' for writing : $!";
        print SPECIESTREE $species_tree_string;
        close SPECIESTREE;
        $self->param('species_tree_file', $species_tree_file);
    }
    return $self->param('species_tree_file');
}

sub run_treebest_mmerge {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;
  my $species_tree_file = $self->get_species_tree_file();
  my $treebest_exe = $self->param('treebest_exe');
  my $temp_directory = $self->worker_temp_directory;

  my $mmergefilename = $temp_directory . $root_id . ".mmerge";
  my $mmerge_output_filename = $mmergefilename . ".output";
  open FILE,">$mmergefilename" or die $!;
  foreach my $method (keys %{$self->param('inputtrees_rooted')}) {
    my $inputtree = $self->param('inputtrees_rooted')->{$method};
    print FILE "$inputtree\n";
  }
  close FILE;

  my $cmd = "$treebest_exe mmerge -s $species_tree_file $mmergefilename > $mmerge_output_filename";
  print("$cmd\n") if($self->debug);
  $DB::single=1;1;#??
  unless(system("$cmd") == 0) {
    print("$cmd\n");
    $self->throw("error running treebest mmerge, $!\n");
  }

  $self->param('mmerge_output', $mmerge_output_filename);

  return 1;
}

sub calculate_branch_lengths {
  my $self = shift;

  $self->param('input_aln', $self->dumpTreeMultipleAlignmentToWorkdir($self->param('nc_tree')) );

  my $leafcount = scalar(@{$self->param('nc_tree')->get_all_leaves});
  if($leafcount<3) {
    printf(STDERR "tree cluster %d has <3 genes - can not build a tree\n", 
           $self->param('nc_tree')->node_id);
    $self->param('mmerge_blengths_output', $self->param('mmerge_output'));
    $self->parse_newick_into_nctree;
    return;
  }

  my $treebest_exe = $self->param('treebest_exe');
  my $constrained_tree = $self->param('mmerge_output');
  my $tree_with_blengths = $self->param('mmerge_output') . ".blengths.nh";
  my $input_aln = $self->param('input_aln');
  my $species_tree_file = $self->get_species_tree_file();
  my $cmd = $treebest_exe;
  $cmd .= " nj";
  if ($treebest_exe =~ /tracking/) {
      $cmd .= " -I";
  }
  $cmd .= " -c $constrained_tree";
  $cmd .= " -s $species_tree_file";
  $cmd .= " $input_aln";
  $cmd .= " > $tree_with_blengths";
#  my $cmd = "$treebest_exe nj -c $constrained_tree -s $species_tree_file $input_aln > $tree_with_blengths";
  print STDERR +("$cmd\n") if($self->debug);

  unless(system("$cmd") == 0) {
    print("$cmd\n");
    $self->throw("error running treebest nj, $!\n");
  }

  $self->param('mmerge_blengths_output', $tree_with_blengths);

  #parse the tree into the datastucture
  $self->parse_newick_into_nctree;
  return 1;
}

sub reroot_inputtrees {
  my $self = shift;

  my $root_id = $self->param('nc_tree')->node_id;
  my $species_tree_file = $self->get_species_tree_file;
  my $treebest_exe = $self->param('treebest_exe');

  my $temp_directory = $self->worker_temp_directory;
  my $template_cmd = "$treebest_exe sdi -rs $species_tree_file";

  foreach my $method (keys %{$self->param('inputtrees_unrooted')}) {
    my $cmd = $template_cmd;
    my $unrootedfilename = $temp_directory . $root_id . "." . $method . ".unrooted";
    my $rootedfilename = $temp_directory . $root_id . "." . $method . ".rooted";
    my $inputtree = $self->param('inputtrees_unrooted')->{$method};
    open FILE,">$unrootedfilename" or die $!;
    print FILE $inputtree;
    close FILE;

    $cmd .= " $unrootedfilename";
    $cmd .= " > $rootedfilename";

    print("$cmd\n") if($self->debug);
    $DB::single=1;1;
    unless(system("$cmd") == 0) {
      print("$cmd\n");
      $self->throw("error running treebest sdi, $!\n");
    }

    # Parse the rooted tree string
    my $rootedstring;
    open (FH, $rootedfilename) or $self->throw("Couldnt open rooted file [$rootedfilename]");
    while(<FH>) {
      chomp $_;
      $rootedstring .= $_;
    }
    close(FH);

      # manual vivification needed:
    unless($self->param('inputtrees_rooted')) {
        $self->param('inputtrees_rooted', {});
    }
    $self->param('inputtrees_rooted')->{$method} = $rootedstring;
  }

  return 1;
}

sub load_input_trees {
  my $self = shift;
  my $tree = $self->param('nc_tree')->tree;

  foreach my $tag ($tree->get_all_tags) {
    next unless $tag =~ m/_it_/;
    my $inputtree_string = $tree->get_value_for_tag($tag);

    my $eval_inputtree;
    eval {
      $eval_inputtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($inputtree_string);
      my @leaves = @{$eval_inputtree->get_all_leaves};
    };
    unless ($@) {
        # manual vivification needed:
      unless($self->param('inputtrees_unrooted')) {
          $self->param('inputtrees_unrooted', {});
      }

      $self->param('inputtrees_unrooted')->{$tag} = $inputtree_string;
    }
  }

  return 1;
}


########################################################
#
# GeneTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $nc_tree = shift;

  $self->param('file_root', $self->worker_temp_directory. "nctree_". $nc_tree->node_id);

  my $aln_file = $self->param('file_root') . ".aln";
  return $aln_file if(-e $aln_file);
  my $leafcount = scalar(@{$nc_tree->get_all_leaves});
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = $self->param('use_genomedb_id') ? ('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  my $sa = $nc_tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     %sa_params,
    );
  $sa->set_displayname_flat(1);

  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  $self->param('input_aln', $aln_file);

  return $aln_file;
}

sub store_nctree
{
    my $self = shift;

    my $tree = $self->param('nc_tree') or return;
    my $tree_adaptor = $self->compara_dba->get_NCTreeAdaptor;

    printf("NCTreeBestMMerge::store_nctree\n") if($self->debug);

    $tree->build_leftright_indexing(1);
    $tree_adaptor->store($tree);
    $tree_adaptor->delete_nodes_not_in_tree($tree);

    if($self->debug >1) {
        print("done storing - now print\n");
        $tree->print_tree;
    }

    $self->store_tags($tree);

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

sub parse_newick_into_nctree
{
  my $self = shift;
  my $newick_file = $self->param('mmerge_blengths_output');

  my $tree = $self->param('nc_tree');
  
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $tree->flatten_tree;
  $tree->print_tree(20) if($self->debug);
  foreach my $node (@{$tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);

  my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, "Bio::EnsEMBL::Compara::GeneTreeNode");
  $newtree->print_tree(20) if($self->debug > 1);

  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_id = $1;
    $leaf->add_tag('name', $member_id);
  }
  $newtree->print_tree(20) if($self->debug > 1);

  # Leaves of newick tree are named with member_id of members from
  # input tree move members (leaves) of input tree into newick tree to
  # mirror the 'member_id' nodes
  foreach my $member (@{$tree->get_all_leaves}) {
    my $tmpnode = $newtree->find_node_by_name($member->member_id);
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

  $newtree->node_id($tree->node_id);
  $newtree->adaptor($tree->adaptor);
  $newtree->tree($tree->tree);
  $self->param('nc_tree', $newtree);
  # to keep the link to the super-tree
  if ($tree->has_parent) {
      $tree->parent->add_child($newtree);
   }

  # Newick tree is now empty so release it
  $tree->release_tree;

  $newtree->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMembers as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
      $self->throw("TreeBestMMerge tree does not have all leaves as GeneTreeMembers\n");
    }
  }
}

sub _store_tree_tags {
    my $self = shift;
    my $tree = $self->param('nc_tree');
    my $pta = $self->compara_dba->get_NCTreeAdaptor;

    print "Storing Tree tags...\n";

    my @leaves = @{$tree->get_all_leaves};
    my @nodes = @{$tree->get_all_nodes};

    # Tree number of leaves.
    my $tree_num_leaves = scalar(@leaves);
    $tree->tree->store_tag("tree_num_leaves",$tree_num_leaves);

    # Tree number of human peptides contained.
    my $num_hum_peps = 0;
    foreach my $leaf (@leaves) {
	$num_hum_peps++ if ($leaf->taxon_id == 9606);
    }
    $tree->tree->store_tag("tree_num_human_genes",$num_hum_peps);

    # Tree max root-to-tip distance.
    my $tree_max_length = $tree->max_distance;
    $tree->tree->store_tag("tree_max_length",$tree_max_length);

    # Tree max single branch length.
    my $tree_max_branch = 0;
    foreach my $node (@nodes) {
        my $dist = $node->distance_to_parent;
        $tree_max_branch = $dist if ($dist > $tree_max_branch);
    }
    $tree->tree->store_tag("tree_max_branch",$tree_max_branch);

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
    $tree->tree->store_tag("tree_num_dup_nodes",$num_dups);
    $tree->tree->store_tag("tree_num_spec_nodes",$num_specs);

    print "Done storing stuff!\n" if ($self->debug);
}

1;
