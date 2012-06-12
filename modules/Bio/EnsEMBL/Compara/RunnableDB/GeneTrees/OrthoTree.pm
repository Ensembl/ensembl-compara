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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take GeneTree as input

This must already have a rooted tree with duplication/sepeciation tags
on the nodes.

It analyzes that tree structure to pick Orthologues and Paralogs for
each genepair.

input_id/parameters format eg: "{'tree_id'=>1234}"
    tree_id : use 'id' to fetch a cluster from the GeneTree

=head1 SYNOPSIS

my $db    = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otree = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$otree->fetch_input(); #reads from DB
$otree->run();
$otree->output();
$otree->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree;

use strict;

use IO::File;
use File::Basename;
use List::Util qw(max);
use Scalar::Util qw(looks_like_number);
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Graph::Node;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'tree_scale'            => 1,
            'store_homologies'      => 1,
            'no_between'            => 0.25, # dont store all possible_orthologs
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

    $self->param('treeDBA', $self->compara_dba->get_GeneTreeNodeAdaptor);
    $self->param('homologyDBA', $self->compara_dba->get_HomologyAdaptor);

    my $starttime = time();
    $self->param('tree_id_str') or die "tree_id_str is an obligatory parameter";
    my $tree_id = $self->param($self->param('tree_id_str')) or die "'*_tree_id' is an obligatory parameter";
    my $gene_tree = $self->param('treeDBA')->fetch_tree_by_root_id($tree_id) or die "Could not fetch gene_tree with tree_id='$tree_id'";
    $self->param('gene_tree', $gene_tree);

    if($self->debug) {
        $self->param('gene_tree')->print_tree($self->param('tree_scale'));
        printf("time to fetch tree : %1.3f secs\n" , time()-$starttime);
    }
    unless($self->param('gene_tree')) {
        $self->throw("undefined GeneTree as input\n");
    }
    $self->delete_old_homologies;
    $self->delete_old_orthotree_tags;
    $self->param('taxon_tree', $self->load_species_tree_from_string( $self->get_species_tree_string ) );
    my %mlss_hash;
    $self->param('mlss_hash', \%mlss_hash);
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs OrthoTree
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;

    $self->run_analysis;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output

    Function: parse clustalw output and update homology and
              homology_member tables
    Returns : none 
    Args    : none 

=cut

sub write_output {
    my $self = shift @_;

    $self->store_homologies;
}


sub DESTROY {
  my $self = shift;

  if($self->param('gene_tree')) {
    printf("OrthoTree::DESTROY  releasing gene_tree\n") if($self->debug);
    $self->param('gene_tree')->release_tree;
    $self->param('gene_tree', undef);
  }
  if($self->param('taxon_tree')) {
    printf("OrthoTree::DESTROY  releasing taxon_tree\n") if($self->debug);
    $self->param('taxon_tree')->release_tree;
    $self->param('taxon_tree', undef);
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################


sub run_analysis {
  my $self = shift;

  my $starttime = time()*1000;
  my $tmp_time = time();
  my $gene_tree = $self->param('gene_tree');
  my $tree_node_id = $gene_tree->node_id;

  print "Getting all leaves\n";
  my @all_gene_leaves = @{$gene_tree->get_all_leaves};
  printf("%1.3f secs to fetch all leaves\n", time()-$tmp_time) if ($self->debug);

  #precalculate the ancestor species_hash (caches into the metadata of
  #nodes) also augments the Duplication tagging
  printf("Calculating ancestor species hash\n") if ($self->debug);
  $self->get_ancestor_species_hash($gene_tree);

  if($self->debug) {
    $gene_tree->print_tree($self->param('tree_scale'));
    printf("%d genes in tree\n", scalar(@all_gene_leaves));
  }

  #compare every gene in the tree with every other each gene/gene
  #pairing is a potential ortholog/paralog and thus we need to analyze
  #every possibility
  #Accomplish by creating a fully connected graph between all the
  #genes under the tree (hybrid graph structure) and then analyze each
  #gene/gene link
  $tmp_time = time();
  printf("build fully linked graph\n") if($self->debug);
  my @genepairlinks;
  my $graphcount = 0;
  while (my $gene1 = shift @all_gene_leaves) {
    foreach my $gene2 (@all_gene_leaves) {
      my $ancestor = $gene1->find_first_shared_ancestor($gene2);
      # Line below will only become faster than above if we find a way to calculate long parent->parent journeys.
      # This is probably doable by looking at the right1/left1 right2/left2 distances between the 2 genes
      # my $ancestor = $self->param('treeDBA')->fetch_first_shared_ancestor_indexed($gene1,$gene2);
      my $taxon_level = $self->get_ancestor_taxon_level($ancestor);
      my $distance = $gene1->distance_to_ancestor($ancestor) +
                     $gene2->distance_to_ancestor($ancestor);
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2, $distance);
      $genepairlink->add_tag("hops", 0);
      $genepairlink->add_tag("ancestor", $ancestor);
      $genepairlink->add_tag("taxon_name", $taxon_level->name);
      $genepairlink->add_tag("tree_node_id", $tree_node_id);
      push @genepairlinks, $genepairlink;
      print STDERR "build graph $graphcount\n" if ($graphcount++ % 10 == 0);
    }
  }
  printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);

  $gene_tree->print_tree($self->param('tree_scale')) if($self->debug);

  #sort the gene/gene links by distance
  #   makes debug display easier to read, not required by algorithm
  $tmp_time = time();
  printf("sort links\n") if($self->debug);
  my @sorted_genepairlinks = 
    sort {$a->distance_between <=> $b->distance_between} @genepairlinks;
  printf("%1.3f secs to sort links\n", time()-$tmp_time) if($self->debug > 1);

  #analyze every gene pair (genepairlink) to get its classification
  printf("analyze links\n") if($self->debug);
  printf("%d links\n", scalar(@genepairlinks)) if ($self->debug);
  $tmp_time = time();
  $self->param('orthotree_homology_counts', {});
  foreach my $genepairlink (@sorted_genepairlinks) {
    $self->analyze_genepairlink($genepairlink);
  }
  printf("%1.3f secs to analyze genepair links\n", time()-$tmp_time) if($self->debug > 1);
  
  #display summary stats of analysis 
  my $runtime = time()*1000-$starttime;  
  $gene_tree->tree->store_tag('OrthoTree_runtime_msec', $runtime) unless ($self->param('_readonly'));

  if($self->debug) {
    printf("%d genes in tree\n", scalar(@{$gene_tree->get_all_leaves}));
    printf("%d pairings\n", scalar(@genepairlinks));
    printf("orthotree homologies\n");
    foreach my $type (keys(%{$self->param('orthotree_homology_counts')})) {
      printf ( "  %13s : %d\n", $type, $self->param('orthotree_homology_counts')->{$type} );
    }
  }
  $self->param('homology_links', \@sorted_genepairlinks);
}


sub analyze_genepairlink {
  my $self = shift;
  my $genepairlink = shift;

  my ($gene1, $gene2) = $genepairlink->get_nodes;

  #run feature detectors: precalcs and caches into metadata
  $self->genepairlink_check_dups($genepairlink);

  #do classification analysis : as filter stack
  if($self->inspecies_paralog_test($genepairlink)) { }
  elsif($self->direct_ortholog_test($genepairlink)) { } 
  elsif($self->ancient_residual_test($genepairlink)) { } 
  elsif($self->one2many_ortholog_test($genepairlink)) { } 
  elsif($self->outspecies_test($genepairlink)) { }
  else {
    printf ( "OOPS!!!! %s - %s\n", $gene1->gene_member->stable_id, $gene2->gene_member->stable_id);
  }

  my $type = $genepairlink->get_tagvalue('orthotree_type');
  if($type) {
    if(!defined($self->param('orthotree_homology_counts')->{$type})) {
      $self->param('orthotree_homology_counts')->{$type} = 1;
    } else {
      $self->param('orthotree_homology_counts')->{$type}++;
    }
  }

  #display results
  $self->display_link_analysis($genepairlink) if($self->debug >1);

  return undef;
}


sub display_link_analysis
{
  my $self = shift;
  my $genepairlink = shift;

  #display raw feature analysis
  my ($gene1, $gene2) = $genepairlink->get_nodes;
  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  printf("%21s(%7d) - %21s(%7d) : %10.3f dist : %3d hops : ", 
    $gene1->gene_member->stable_id, $gene1->gene_member->member_id,
    $gene2->gene_member->stable_id, $gene2->gene_member->member_id,
    $genepairlink->distance_between, $genepairlink->get_tagvalue('hops'));

  if($genepairlink->get_tagvalue('has_dups')) { printf("%5s ", 'DUP');
  } else { printf("%5s ", ""); }

  printf("%5s ", "");

  print("ancestor:(");
  my $node_type = $ancestor->get_tagvalue('node_type', '');
  if ($node_type eq 'duplication') {
    print "DUP ";
  } elsif ($node_type eq 'dubious') {
    print "DD  ";
  } elsif ($node_type eq 'gene_split') {
    print "SPL ";
  } else {
    print "    ";
  }
  printf("%9s)", $ancestor->node_id);
  printf(" %.4f ", $ancestor->get_tagvalue('duplication_confidence_score'));

  my $taxon_level = $ancestor->get_tagvalue('taxon_level');
  printf(" %s %s %s\n", 
         $genepairlink->get_tagvalue('orthotree_type'), 
         $genepairlink->get_tagvalue('orthotree_subtype'),
         $taxon_level->name
        );

  return undef;
}

sub load_species_tree_from_string {
  my ($self, $species_tree_string) = @_;

  my $taxonDBA  = $self->compara_dba->get_NCBITaxonAdaptor();
  my $genomeDBA = $self->compara_dba->get_GenomeDBAdaptor();
  
  my $taxon_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
  
  my %used_ids;
  
  foreach my $node (@{$taxon_tree->all_nodes_in_graph()}) {
    
    #Split based on - to remove comments & sub * for internal nodes.
    #The ID assigned by NewickParser is not the real ID therefore we need to subsitute this in
    my ($id) = split('-',$node->name);
    $id =~ s/\*//;
    
    #If it looks like a number then assume we are working with an ID (Taxon or GenomeDB)
    if (looks_like_number($id)) {
      $node->node_id($id);
      
      if($self->param('use_genomedb_id')) {
          my $gdb = $genomeDBA->fetch_by_dbID($id);
          $self->throw("Cannot find a GenomeDB for the ID ${id}. Ensure your tree is correct and you are using use_genomedb_id correctly") if !defined $gdb;
          $node->name($gdb->name());
          $used_ids{$id} = 1;
          $node->add_tag('_found_genomedb', 1);
      }
      else {
          my $ncbi_node = $taxonDBA->fetch_node_by_taxon_id($id);
          $node->name($ncbi_node->name) if (defined $ncbi_node);
      }
    } else { # doesn't look like number
      $node->name($id);
    }
    $node->add_tag('taxon_id', $id);
  }

  # if genome_db hasn't been found (it means that id doesn't looks_like_number)
  if($self->param('use_genomedb_id')) {
      print "Searching for overlapping identifiers\n" if $self->debug();
      my $max_id = max(keys(%used_ids));
      foreach my $node (@{$taxon_tree->all_nodes_in_graph()}) {
          if($used_ids{$node->node_id()} && ! $node->get_tagvalue('_found_genomedb')) {
              $max_id++;
              $node->node_id($max_id);
          }
      }
  }
  
  return $taxon_tree;
}

sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_tagvalue('species_hash');
    return $species_hash if($species_hash);

    $species_hash = {};
    my $is_dup = 0;

    if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
        my $node_genome_db_id = $node->genome_db_id;
        $species_hash->{$node_genome_db_id} = 1;
        $node->add_tag('species_hash', $species_hash);
        return $species_hash;
    }

    foreach my $child (@{$node->children}) {
        my $t_species_hash = $self->get_ancestor_species_hash($child);
        foreach my $genome_db_id (keys(%$t_species_hash)) {
            unless(defined($species_hash->{$genome_db_id})) {
                $species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id};
            } else {
                $is_dup = 1;
                $species_hash->{$genome_db_id} += $t_species_hash->{$genome_db_id};
            }
        }
    }

    if ($is_dup) {
        my $original_node_type = $node->get_tagvalue('node_type');
        if ((not defined $original_node_type) or ($original_node_type eq 'speciation')) {
            print "fixing node_type of ", $node->node_id, "\n";
            $node->store_tag('node_type', 'duplication') unless ($self->param('_readonly'));
        }
    }

    $node->add_tag("species_hash", $species_hash);
    return $species_hash;
}


sub get_ancestor_taxon_level {
  my ($self, $ancestor) = @_;

  my $taxon_level = $ancestor->get_tagvalue('taxon_level');
  return $taxon_level if($taxon_level);

  printf("\ncalculate ancestor taxon level for node_id=%d\n", $ancestor->node_id) if $self->debug;
  my $taxon_tree = $self->param('taxon_tree');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);

  foreach my $gdbID (keys(%$species_hash)) {
      my $taxon;

      if($self->param('use_genomedb_id')) {
            $taxon = $taxon_tree->find_node_by_node_id($gdbID);
            $self->throw("Missing node in species (taxon) tree for $gdbID") unless $taxon;
      }
      else {
          my $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($gdbID);
          $taxon = $taxon_tree->find_node_by_node_id($gdb->taxon_id);
          $self->throw("oops missing taxon " . $gdb->taxon_id ."\n") unless $taxon;
      }

    if($taxon_level) {
      $taxon_level = $taxon_level->find_first_shared_ancestor($taxon);
    } else {
      $taxon_level = $taxon;
    }
  }
  my $taxon_id = $taxon_level->get_tagvalue("taxon_id");
  $ancestor->add_tag("taxon_level", $taxon_level);
  $ancestor->store_tag("taxon_id", $taxon_id) unless ($self->param('_readonly'));
  $ancestor->store_tag("taxon_name", $taxon_level->name) unless ($self->param('_readonly'));

  #$ancestor->print_tree($self->param('tree_scale'));
  #$taxon_level->print_tree(10);

  return $taxon_level;
}


sub duplication_confidence_score {
  my $self = shift;
  my $ancestor = shift;

  # This assumes bifurcation!!! No multifurcations allowed
  my ($child_a, $child_b, $dummy) = @{$ancestor->children};
  $self->throw("tree is multifurcated in duplication_confidence_score\n") if (defined($dummy));
  my @child_a_gdbs = keys %{$self->get_ancestor_species_hash($child_a)};
  my @child_b_gdbs = keys %{$self->get_ancestor_species_hash($child_b)};
  my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @child_a_gdbs;
     %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @child_b_gdbs;
  my @isect = my @diff = my @union = (); my %count;
  foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ }
  foreach my $e (keys %count) {
    push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e; 
  }

  my $duplication_confidence_score = 0;
  my $scalar_isect = scalar(@isect);
  my $scalar_union = scalar(@union);
  $duplication_confidence_score = (($scalar_isect)/$scalar_union) unless (0 == $scalar_isect);

  $ancestor->store_tag("duplication_confidence_score", $duplication_confidence_score) unless ($self->param('_readonly'));

  my $rounded_duplication_confidence_score = (int((100.0 * $scalar_isect / $scalar_union + 0.5)));
  my $species_intersection_score = $ancestor->get_tagvalue("species_intersection_score");
  unless (defined($species_intersection_score)) {
    my $ancestor_node_id = $ancestor->node_id;
    warn("Difference in the GeneTree: duplication_confidence_score [$duplication_confidence_score] whereas species_intersection_score [$species_intersection_score] is undefined in njtree - ancestor $ancestor_node_id\n");
    return;
  }
  if ($species_intersection_score ne $rounded_duplication_confidence_score && !defined($self->param('_readonly'))) {
    my $ancestor_node_id = $ancestor->node_id;
    $self->throw("Inconsistency in the GeneTree: duplication_confidence_score [$duplication_confidence_score] != species_intersection_score [$species_intersection_score] -  $ancestor_node_id\n");
  } else {
    $ancestor->delete_tag('species_intersection_score');
  }
}


sub delete_old_orthotree_tags
{
    my $self = shift;

    #return undef unless ($self->input_job->retry_count > 0);

    my $tree_node_id = $self->param('gene_tree')->node_id;

    print "deleting old orthotree tags\n" if ($self->debug);
    my $delete_time = time();

    my $sql1 = 'UPDATE gene_tree_node JOIN gene_tree_node_attr USING (node_id) SET taxon_id = NULL, taxon_name = NULL, duplication_confidence_score = NULL WHERE root_id = ?';
    my $sth1 = $self->compara_dba->dbc->prepare($sql1);
    $sth1->execute($tree_node_id);
    $sth1->finish;

    my $sql2 = 'DELETE FROM gene_tree_root_tag WHERE tag LIKE "OrthoTree_%" AND root_id = ?';
    my $sth2 = $self->compara_dba->dbc->prepare($sql2);
    $sth2->execute($tree_node_id);
    $sth2->finish;

    printf("%1.3f secs to delete old orthotree tags\n", time()-$delete_time) if ($self->debug);
}

sub delete_old_homologies {
    my $self = shift;

    #return undef unless ($self->input_job->retry_count > 0);

    my $tree_node_id = $self->param('gene_tree')->node_id;

    # New method all in one go -- requires key on tree_node_id
    print "deleting old homologies\n" if ($self->debug);
    my $delete_time = time();

    # Delete first the members
    my $sql1 = 'DELETE homology_member FROM homology JOIN homology_member USING (homology_id) WHERE tree_node_id=?';
    my $sth1 = $self->compara_dba->dbc->prepare($sql1);
    $sth1->execute($tree_node_id);
    $sth1->finish;

    # And then the homologies
    my $sql2 = 'DELETE FROM homology WHERE tree_node_id=?';
    my $sth2 = $self->compara_dba->dbc->prepare($sql2);
    $sth2->execute($tree_node_id);
    $sth2->finish;
    
    printf("%1.3f secs to delete old homologies\n", time()-$delete_time) if ($self->debug);
}

sub genepairlink_check_dups
{
    my $self = shift;
    my $genepairlink = shift;

    my ($pep1, $pep2) = $genepairlink->get_nodes;

    my $ancestor = $genepairlink->get_tagvalue('ancestor');
    my $has_dup = 0;
    my $hops = 0;
    my $tnode = $pep1;
    do {
        $tnode = $tnode->parent;
        $has_dup = 1 if ($tnode->get_tagvalue('node_type', '') eq 'duplication');
        $hops ++;
    } while(!($tnode->equals($ancestor)));

    $tnode = $pep2;
    do {
        $tnode = $tnode->parent;
        $has_dup = 1 if ($tnode->get_tagvalue('node_type', '') eq 'duplication');
        $hops ++;
    } while(!($tnode->equals($ancestor)));

    $genepairlink->add_tag("hops", $hops - 1);
    $genepairlink->add_tag("has_dups", $has_dup);
}


########################################################
#
# Classification analysis
#
########################################################


sub direct_ortholog_test
{
  my $self = shift;
  my $genepairlink = shift;

  #strictest ortholog test: 
  #  - genes are from different species
  #  - no ancestral duplication events
  #  - these genes are only copies of the ancestor for their species

  return undef if($genepairlink->get_tagvalue('has_dups'));

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);

  #RAP seems to miss some duplication events so check the species 
  #counts for these two species to make sure they are the only
  #representatives of these species under the ancestor
  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};

  return undef if($count1>1);
  return undef if($count2>1);

  #passed all the tests -> it's a simple ortholog
  $genepairlink->add_tag("orthotree_type", 'ortholog_one2one');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);
  $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  return 1;
}


sub inspecies_paralog_test
{
  my $self = shift;
  my $genepairlink = shift;

  #simplest paralog test: 
  #  - both genes are from the same species
  #  - and just label with taxonomic level

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef unless($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);

  #my $species_hash = $self->get_ancestor_species_hash($ancestor);
  #foreach my $gdbID (keys(%$species_hash)) {
  #  return undef unless($gdbID == $pep1->genome_db_id);
  #}

  #passed all the tests -> it's an inspecies_paralog
#  $genepairlink->add_tag("orthotree_type", 'inspecies_paralog');
  $genepairlink->add_tag("orthotree_type", 'within_species_paralog');
  $genepairlink->add_tag("orthotree_type", 'contiguous_gene_split') if $ancestor->get_tagvalue('node_type') eq 'gene_split';
  $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  # Duplication_confidence_score
  if (not $ancestor->has_tag("duplication_confidence_score")) {
    $self->duplication_confidence_score($ancestor);
    $genepairlink->{duplication_confidence_score} = $ancestor->get_tagvalue("duplication_confidence_score");
  }
  return 1;
}


sub ancient_residual_test
{
  my $self = shift;
  my $genepairlink = shift;

  #test 3: getting a bit more complex:
  #  - genes are from different species
  #  - there is evidence for duplication events elsewhere in the history
  #  - but these two genes are the only remaining representative of
  #    the ancestor

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);

  #check these are the only representatives of the ancestor
  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};

  return undef if($count1>1);
  return undef if($count2>1);

  #passed all the tests -> it's a simple ortholog
  # print $ancestor->node_id, " ", $ancestor->name,"\n";

#  my $sis_value = $ancestor->get_tagvalue("species_intersection_score");
  if ($ancestor->get_tagvalue('node_type', '') eq 'duplication') {
    $genepairlink->add_tag("orthotree_type", 'apparent_ortholog_one2one');
    my $taxon = $self->get_ancestor_taxon_level($ancestor);
    $genepairlink->add_tag("orthotree_subtype", $taxon->name);
    # Duplication_confidence_score
    if (not $ancestor->has_tag("duplication_confidence_score")) {
      $self->duplication_confidence_score($ancestor);
      $genepairlink->{duplication_confidence_score} = $ancestor->get_tagvalue("duplication_confidence_score");
    }
  } else {
    $genepairlink->add_tag("orthotree_type", 'ortholog_one2one');
    my $taxon = $self->get_ancestor_taxon_level($ancestor);
    $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  }
  return 1;
}


sub one2many_ortholog_test
{
  my $self = shift;
  my $genepairlink = shift;

  #test 4: getting a bit more complex yet again:
  #  - genes are from different species
  #  - but there is evidence for duplication events in the history
  #  - one of the genes is the only remaining representative of the
  #  ancestor in its species
  #  - but the other gene has multiple copies in it's species 
  #  (first level of orthogroup analysis)

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $species_hash = $self->get_ancestor_species_hash($ancestor);

  my $count1 = $species_hash->{$pep1->genome_db_id};
  my $count2 = $species_hash->{$pep2->genome_db_id};

  #one of the genes must be the only copy of the gene
  #and the other must appear more than once in the ancestry
  return undef unless 
    (
     ($count1==1 and $count2>1) or ($count1>1 and $count2==1)
    );

  if ($ancestor->get_tagvalue('node_type', '') eq 'duplication') {
    return undef;
  }

  #passed all the tests -> it's a one2many ortholog
  $genepairlink->add_tag("orthotree_type", 'ortholog_one2many');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);
  $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  return 1;
}


sub outspecies_test
{
  my $self = shift;
  my $genepairlink = shift;

  #last test: left over pairs:
  #  - genes are from different species
  #  - if ancestor is 'DUP' -> paralog else 'ortholog'

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef if($pep1->genome_db_id == $pep2->genome_db_id);

  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  my $taxon = $self->get_ancestor_taxon_level($ancestor);

  #ultra simple ortho/paralog classification
  if ($ancestor->get_tagvalue('node_type', '') eq 'duplication') {
    $genepairlink->add_tag("orthotree_type", 'possible_ortholog');
    $genepairlink->add_tag("orthotree_subtype", $taxon->name);
    # duplication_confidence_score
    if (not $ancestor->has_tag("duplication_confidence_score")) {
      $self->duplication_confidence_score($ancestor);
     $genepairlink->{duplication_confidence_score} = $ancestor->get_tagvalue("duplication_confidence_score");
    }
  } else {
      $genepairlink->add_tag("orthotree_type", 'ortholog_many2many');
      $genepairlink->add_tag("orthotree_subtype", $taxon->name);
  }
  return 1;
}


########################################################
#
# Tree input/output section
#
########################################################

sub store_homologies {
  my $self = shift;

  $self->param('homology_consistency', {});

  my $hlinkscount = 0;
  foreach my $genepairlink (@{$self->param('homology_links')}) {
    $self->display_link_analysis($genepairlink) if($self->debug>2);
    my $type = $genepairlink->get_tagvalue("orthotree_type");
    my $dcs = $genepairlink->get_tagvalue('ancestor')->get_tagvalue('duplication_confidence_score');
    next if ($type eq 'possible_ortholog' and $dcs > $self->param('no_between'));

    $self->store_gene_link_as_homology($genepairlink) if $self->param('store_homologies');
    print STDERR "homology links $hlinkscount\n" if ($hlinkscount++ % 500 == 0);
  }

  my $counts_str = stringify($self->param('orthotree_homology_counts'));
  print "Homology counts: $counts_str\n";

  $self->check_homology_consistency;

  $self->param('gene_tree')->tree->store_tag('OrthoTree_types_hashstr', $counts_str) unless ($self->param('_readonly'));
}

sub store_gene_link_as_homology {
  my $self = shift;
  my $genepairlink  = shift;

  my $type = $genepairlink->get_tagvalue('orthotree_type');
  return unless($type);
  my $subtype = $genepairlink->get_tagvalue('taxon_name');
  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  warn "Tag tree_node_id undefined\n" unless $genepairlink->has_tag('tree_node_id');
  my $tree_node_id = $genepairlink->get_tagvalue('tree_node_id');

  my ($gene1, $gene2) = $genepairlink->get_nodes;

  # get or create method_link_species_set
  my $mlss;
  {
      my $mlss_type;
      if (($type eq 'possible_ortholog') or ($type eq 'within_species_paralog') or ($type eq 'other_paralog')) {
          $mlss_type = "ENSEMBL_PARALOGUES";
      } else {
          $mlss_type = "ENSEMBL_ORTHOLOGUES";
      }
    # This should be unique to a pair of genome_db_ids, and equal if we switch the two genome_dbs
    # WARNING: This trick is valid for genome_db_id up to 10000
      my $mlss_key = sprintf("%s_%d", $mlss_type, $gene1->genome_db->dbID * $gene2->genome_db->dbID + 100000000*($gene1->genome_db->dbID+$gene2->genome_db->dbID));

      if (exists $self->param('mlss_hash')->{$mlss_key}) {
          $mlss = $self->param('mlss_hash')->{$mlss_key};
      } else {
          my $gdbs;
          if ($gene1->genome_db->dbID == $gene2->genome_db->dbID) {
              $gdbs = [$gene1->genome_db];
          } else {
              $gdbs = [$gene1->genome_db, $gene2->genome_db];
          }
          $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                  -method => ($self->compara_dba->get_MethodAdaptor->fetch_by_type($mlss_type) || new Bio::EnsEMBL::Compara::Method(-type => $mlss_type, -class => 'Homology.homology')),
                  -species_set_obj => ($self->compara_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($gdbs) || new Bio::EnsEMBL::Compara::SpeciesSet(-genomedbs => $gdbs)),
                  );
          $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss) unless ($self->param('_readonly'));
          $self->param('mlss_hash')->{$mlss_key} = $mlss;
      }
  }
  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  $homology->description($type);
  $homology->subtype($subtype);
  $homology->ancestor_node_id($ancestor->node_id);
  $homology->tree_node_id($tree_node_id);
  $homology->method_link_species_set_id($mlss->dbID);
  
  $homology->add_Member($gene1);
  $homology->add_Member($gene2);
  $homology->update_alignment_stats;

  my $key = $mlss->dbID . "_" . $gene1->dbID;
  $self->param('homology_consistency')->{$key}{$type} = 1;

  # at this stage, contiguous_gene_split have been retrieved from the node types
  if ($self->param('tag_split_genes')) {
    # Potential split genes: within_species_paralog that do not overlap at all
    if ($type eq 'within_species_paralog' && 0 == $gene1->perc_id && 0 == $gene2->perc_id && 0 == $gene1->perc_pos && 0 == $gene2->perc_pos) {
        $self->param('orthotree_homology_counts')->{'within_species_paralog'}--;
        $homology->description('putative_gene_split');
        $self->param('orthotree_homology_counts')->{'putative_gene_split'}++;
    }
  }
  
  $self->param('homologyDBA')->store($homology);

  return $homology;
}


sub check_homology_consistency {
    my $self = shift;

    print "checking homology consistency\n" if ($self->debug);
    my $bad_key = undef;

    foreach my $mlss_member_id ( keys %{$self->param('homology_consistency')} ) {
        my $count = scalar(keys %{$self->param('homology_consistency')->{$mlss_member_id}});
        if ($count > 1) {
            my ($mlss, $member_id) = split("_", $mlss_member_id);
            $bad_key = "mlss member_id : $mlss $member_id";
            print "$bad_key\n" if ($self->debug);
        }
    }
    $self->throw("Inconsistent homologies: $bad_key") if defined $bad_key;
}


1;
