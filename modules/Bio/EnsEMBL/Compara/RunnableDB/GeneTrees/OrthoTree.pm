=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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
$otree->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

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

use Bio::EnsEMBL::Compara::Homology;
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
            'homoeologous_genome_dbs'  => [],
            '_readonly'             => 0,
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

    $self->param('homologyDBA', $self->compara_dba->get_HomologyAdaptor);

    my $tree_id = $self->param_required('gene_tree_id');
    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($tree_id) or die "Could not fetch gene_tree with tree_id='$tree_id'";
    $gene_tree->preload();
    $self->param('gene_tree', $gene_tree->root);

    if($self->debug) {
        $self->param('gene_tree')->print_tree($self->param('tree_scale'));
    }
    unless($self->param('gene_tree')) {
        $self->throw("undefined GeneTree as input\n");
    }

    my %homoeologous_groups = ();
    foreach my $i (1..(scalar(@{$self->param('homoeologous_genome_dbs')}))) {
        my $group = $self->param('homoeologous_genome_dbs')->[$i-1];
        foreach my $gdb (@{$group}) {
            if (looks_like_number($gdb)) {
                $homoeologous_groups{$gdb} = $i;
            } elsif (ref $gdb) {
                $homoeologous_groups{$gdb->dbID} = $i;
            } else {
                $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($gdb);
                $homoeologous_groups{$gdb->dbID} = $i;
            }
        }
    }
    $self->param('homoeologous_groups', \%homoeologous_groups);
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

    $self->delete_old_homologies unless $self->param('_readonly');
    $self->store_homologies;
}


sub post_cleanup {
  my $self = shift;

  if($self->param('gene_tree')) {
    printf("OrthoTree::post_cleanup  releasing gene_tree\n") if($self->debug);
    $self->param('gene_tree')->release_tree;
    $self->param('gene_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub run_analysis {
  my $self = shift;

  my $gene_tree = $self->param('gene_tree');

  print "Getting all leaves\n";
  my @all_gene_leaves = @{$gene_tree->get_all_leaves};

  #precalculate the ancestor species_hash (caches into the metadata of
  #nodes) also augments the Duplication tagging
  printf("Calculating ancestor species hash\n") if ($self->debug);
  $self->get_ancestor_species_hash($gene_tree);

  if($self->debug) {
    $gene_tree->print_tree($self->param('tree_scale'));
    printf("%d genes in tree\n", scalar(@all_gene_leaves));
  }

  # duplication confidence scores
  foreach my $node (@{$gene_tree->get_all_nodes}) {
      next unless scalar(@{$node->children});
      if ($node->get_tagvalue('node_type') ne 'speciation') {
          $self->duplication_confidence_score($node);
      } else {
          $node->delete_tag('duplication_confidence_score');
      }
  }

  #compare every gene in the tree with every other each gene/gene
  #pairing is a potential ortholog/paralog and thus we need to analyze
  #every possibility
  #Accomplish by creating a fully connected graph between all the
  #genes under the tree (hybrid graph structure) and then analyze each
  #gene/gene link
  printf("%d genes in tree\n", scalar(@{$gene_tree->get_all_leaves})) if $self->debug;
  printf("build fully linked graph\n") if($self->debug);
  my %genepairlinks;
  my $graphcount = 0;
  my $has_match = $self->param('has_match', {});

  foreach my $ancestor (reverse @{$gene_tree->get_all_nodes}) {
    next unless scalar(@{$ancestor->children});
    my ($child1, $child2) = @{$ancestor->children};
    my $leaves1 = $child1->get_all_leaves;
    my $leaves2 = $child2->get_all_leaves;
    foreach my $gene1 (@$leaves1) {
     foreach my $gene2 (@$leaves2) {
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2);
      $genepairlink->add_tag("ancestor", $ancestor);
      push @{$genepairlinks{$ancestor->get_tagvalue('node_type')}}, $genepairlink;
      print STDERR "build graph $graphcount\n" if ($graphcount++ % 1000 == 0);
     }
    }
  }
  printf("%d pairings\n", $graphcount) if $self->debug;

  $gene_tree->print_tree($self->param('tree_scale')) if($self->debug);
  $self->param('homology_links', []);
  $self->param('orthotree_homology_counts', {});

  foreach my $genepairlink (@{$genepairlinks{speciation}}) {
    $self->tag_genepairlink($genepairlink, $self->tag_orthologues($genepairlink), 1);
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  foreach my $genepairlink (@{$genepairlinks{dubious}}) {
    $self->tag_genepairlink($genepairlink, $self->tag_orthologues($genepairlink), 0);
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  foreach my $genepairlink (@{$genepairlinks{gene_split}}) {
    $self->tag_genepairlink($genepairlink, 'gene_split', 1);
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  my @todo4 = ();

  my @duplication_nodes = ();
  my $last_node_id = undef;
  foreach my $genepairlink (@{$genepairlinks{duplication}}) {
      my $this_node_id = $genepairlink->get_value_for_tag('ancestor')->node_id;
      if ((not $last_node_id) or ($last_node_id != $this_node_id)) {
          push @duplication_nodes, [];
      }
      $last_node_id = $this_node_id;
      push @{$duplication_nodes[-1]}, $genepairlink;
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  foreach my $pair_group (@duplication_nodes) {
      my @good_ones = ();
      foreach my $genepairlink (@$pair_group) {
          my ($pep1, $pep2) = $genepairlink->get_nodes;
          if ($pep1->genome_db_id == $pep2->genome_db_id) {
              push @good_ones, [$genepairlink, 'within_species_paralog', 1];
          } elsif ($self->is_level3_orthologues($genepairlink)) {
              push @good_ones, [$genepairlink, $self->tag_orthologues($genepairlink), 0];
          } else {
              push @todo4, $genepairlink;
          }
      }
      foreach my $par (@good_ones) {
          $self->tag_genepairlink(@$par);
      }
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  foreach my $genepairlink (@todo4) {
      my $other = $self->is_level4_orthologues($genepairlink);
      if (defined $other) {
          my $type = $self->tag_orthologues($genepairlink);
          if ($other->get_tagvalue('orthotree_type') eq $type) {
              $self->tag_genepairlink($genepairlink, $type, 0);
          }
      }
  }
  printf("%d homologies found so far\n", scalar(@{$self->param('homology_links')}));

  #display summary stats of analysis 
  if($self->debug) {
    printf("orthotree homologies\n");
    foreach my $type (keys(%{$self->param('orthotree_homology_counts')})) {
      printf ( "  %13s : %d\n", $type, $self->param('orthotree_homology_counts')->{$type} );
    }
  }
}


sub display_link_analysis
{
  my $self = shift;
  my $genepairlink = shift;

  #display raw feature analysis
  my ($gene1, $gene2) = $genepairlink->get_nodes;
  my $ancestor = $genepairlink->get_tagvalue('ancestor');
  printf("%21s(%7d) - %21s(%7d) : %10.3f dist : ",
    $gene1->gene_member->stable_id, $gene1->gene_member->member_id,
    $gene2->gene_member->stable_id, $gene2->gene_member->member_id,
    $genepairlink->distance_between);

  printf("%5s ", "");
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

  printf(" %s %d %s\n",
         $genepairlink->get_tagvalue('orthotree_type'), 
         $genepairlink->get_tagvalue('is_tree_compliant'),
         $ancestor->get_tagvalue('taxon_name'),
        );

  return undef;
}


sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_tagvalue('species_hash');
    return $species_hash if($species_hash);

    $species_hash = {};

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
                $species_hash->{$genome_db_id} += $t_species_hash->{$genome_db_id};
            }
        }
    }

    $node->add_tag("species_hash", $species_hash);
    return $species_hash;
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


sub delete_old_homologies {
    my $self = shift;

    my $tree_node_id = $self->param('gene_tree_id');

    # New method all in one go -- requires key on tree_node_id
    print "deleting old homologies\n" if ($self->debug);

    # Delete first the members
    my $sql1 = 'DELETE homology_member FROM homology JOIN homology_member USING (homology_id) WHERE gene_tree_root_id = ?';
    my $sth1 = $self->compara_dba->dbc->prepare($sql1);
    $sth1->execute($tree_node_id);
    $sth1->finish;

    # And then the homologies
    my $sql2 = 'DELETE FROM homology WHERE gene_tree_root_id = ?';
    my $sth2 = $self->compara_dba->dbc->prepare($sql2);
    $sth2->execute($tree_node_id);
    $sth2->finish;
}



########################################################
#
# Classification analysis
#
########################################################


sub tag_genepairlink
{
    my $self = shift;
    my $genepairlink = shift;
    my $orthotree_type = shift;
    my $is_tree_compliant = shift;

    $genepairlink->add_tag('orthotree_type', $orthotree_type);
    $genepairlink->add_tag('is_tree_compliant', $is_tree_compliant);

    if ($orthotree_type =~ /ortholog/) {
        my ($pep1, $pep2) = $genepairlink->get_nodes;
        my $has_match = $self->param('has_match');
        $has_match->{$pep1->member_id}->{$pep2->genome_db_id} = $genepairlink;
        $has_match->{$pep2->member_id}->{$pep1->genome_db_id} = $genepairlink;
    }

    $self->param('orthotree_homology_counts')->{$orthotree_type}++;
    push @{$self->param('homology_links')}, $genepairlink;

}


sub tag_orthologues
{
    my $self = shift;
    my $genepairlink = shift;

    my ($pep1, $pep2) = $genepairlink->get_nodes;
    my $ancestor = $genepairlink->get_tagvalue('ancestor');
    my $species_hash = $self->get_ancestor_species_hash($ancestor);
    my $count1 = $species_hash->{$pep1->genome_db_id};
    my $count2 = $species_hash->{$pep2->genome_db_id};

    if ($count1 == 1 and $count2 == 1) {
        return 'ortholog_one2one';
    } elsif ($count1 == 1 or $count2 == 1) {
        return 'ortholog_one2many';
    } else {
        return 'ortholog_many2many';
    }
}




sub is_level3_orthologues
{
    my $self = shift;
    my $genepairlink = shift;

    my $has_match = $self->param('has_match');
    my ($pep1, $pep2) = $genepairlink->get_nodes;

    return (not $has_match->{$pep1->member_id}->{$pep2->genome_db_id} and not $has_match->{$pep2->member_id}->{$pep1->genome_db_id});
}

sub is_level4_orthologues
{
    my $self = shift;
    my $genepairlink = shift;

    my $has_match = $self->param('has_match');
    my ($pep1, $pep2) = $genepairlink->get_nodes;

    return undef if $has_match->{$pep1->member_id}->{$pep2->genome_db_id} and $has_match->{$pep2->member_id}->{$pep1->genome_db_id};
    
    my $dcs = $genepairlink->get_tagvalue('ancestor')->get_tagvalue('duplication_confidence_score');
    return undef unless $dcs < $self->param('no_between');
    return $has_match->{$pep1->member_id}->{$pep2->genome_db_id} || $has_match->{$pep2->member_id}->{$pep1->genome_db_id};
}


sub complain
{
    my $self = shift;
    my $genepairlink = shift;

    my ($pep1, $pep2) = $genepairlink->get_nodes;
    printf ( "OOPS!!!! %s - %s\n", $pep1->gene_member->stable_id, $pep2->gene_member->stable_id);
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
  my $is_tree_compliant = $genepairlink->get_tagvalue('is_tree_compliant');
  my $ancestor = $genepairlink->get_tagvalue('ancestor');

  my ($gene1, $gene2) = $genepairlink->get_nodes;

  # get the mlss from the database
  my $mlss_type;
  if ($type =~ /^ortholog/) {
      my $gdb1 = $gene1->genome_db_id;
      my $gdb2 = $gene2->genome_db_id;
      if (($self->param('homoeologous_groups')->{$gdb1} || -1) == ($self->param('homoeologous_groups')->{$gdb2} || -2)) {
          $mlss_type = 'ENSEMBL_HOMOEOLOGUES';
      } else {
          $mlss_type = 'ENSEMBL_ORTHOLOGUES';
      }

  } elsif ($type eq 'alt_allele') {
      $mlss_type = 'ENSEMBL_PROJECTIONS';
  } else {
      $mlss_type = 'ENSEMBL_PARALOGUES';
  }

  my $gdbs;
  if ($gene1->genome_db->dbID == $gene2->genome_db->dbID) {
      $gdbs = [$gene1->genome_db];
  } else {
      $gdbs = [$gene1->genome_db, $gene2->genome_db];
  }
  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($mlss_type, $gdbs);

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  $homology->description($type);
  $homology->is_tree_compliant($is_tree_compliant);
  $homology->gene_tree_node($ancestor) if $ancestor;
  $homology->method_link_species_set($mlss);
  $homology->_species_tree_node_id($ancestor->get_value_for_tag('species_tree_node_id')) if $ancestor;
  
  $homology->add_Member($gene1->Bio::EnsEMBL::Compara::AlignedMember::copy);
  $homology->add_Member($gene2->Bio::EnsEMBL::Compara::AlignedMember::copy);
  $homology->update_alignment_stats;

  my $key = $mlss->dbID . "_" . $gene1->dbID;
  $self->param('homology_consistency')->{$key}{$type} = 1;

  # at this stage, gene_split have been retrieved from the node types
  if ($self->param('tag_split_genes')) {
    # Potential split genes: within_species_paralog that do not overlap at all
    if (($type eq 'within_species_paralog') and ($homology->get_all_Members->[0]->perc_cov == 0) and ($homology->get_all_Members->[1]->perc_cov == 0)) {
        $self->param('orthotree_homology_counts')->{'within_species_paralog'}--;
        $homology->description('gene_split');
        $homology->is_tree_compliant(0);
        $self->param('orthotree_homology_counts')->{'gene_split'}++;
    }
  }
  
  $self->param('homologyDBA')->store($homology) unless $self->param('_readonly');

  return $homology;
}


sub check_homology_consistency {
    my $self = shift;

    print "checking homology consistency\n" if ($self->debug);
    my $bad_key = undef;

    foreach my $mlss_member_id ( keys %{$self->param('homology_consistency')} ) {
        my $count = scalar(keys %{$self->param('homology_consistency')->{$mlss_member_id}});

        next if $count == 1;
        next if $count == 2 and exists $self->param('homology_consistency')->{$mlss_member_id}->{gene_split} and exists $self->param('homology_consistency')->{$mlss_member_id}->{within_species_paralog};

        my ($mlss, $member_id) = split("_", $mlss_member_id);
        $bad_key = "mlss member_id : $mlss $member_id";
        print "$bad_key\n" if ($self->debug);
    }
    $self->throw("Inconsistent homologies: $bad_key") if defined $bad_key;
}


1;
