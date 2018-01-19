=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
use warnings;

use feature qw(switch);

use IO::File;
use File::Basename;
use List::Util qw(max);
use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Graph::Node;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
            %{ $self->SUPER::param_defaults() },
            'tree_scale'            => 1,
            'store_homologies'      => 1,
            'no_between'            => 0.25, # dont store all possible_orthologs
            '_readonly'             => 0,
            'tag_split_genes'       => 0,
            'input_clusterset_id'   => undef,
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
    if ($self->param('input_clusterset_id') and $self->param('input_clusterset_id') ne 'default') {
        $gene_tree = $gene_tree->alternative_trees->{$self->param('input_clusterset_id')};
        die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id')) unless $gene_tree;
    }

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $gene_tree);
    $self->param('gene_tree', $gene_tree->root);

    if($self->debug) {
        $gene_tree->print_tree($self->param('tree_scale'));
        printf("%d genes in tree\n", scalar(@{$gene_tree->root->get_all_leaves}));
    }

    $self->param('homology_consistency', {});
    $self->param('has_match', {});
    $self->param('orthotree_homology_counts', {});
    $self->param('n_stored_homologies', 0);
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

    $self->prepare_analysis();
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
    # Here is how to use server-side prepared statements. They have not
    # proven to be faster, so this is not enabled by default
    #$self->param('homologyDBA')->mysql_server_prepare(1);
    $self->run_analysis;
    #$self->param('homologyDBA')->mysql_server_prepare(0);
    $self->print_summary;
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

sub prepare_analysis {
    my $self = shift;

    my $gene_tree = $self->param('gene_tree');

    # precalculate the ancestor species_hash
    printf("Calculating ancestor species hash\n") if ($self->debug);
    $self->get_ancestor_species_hash($gene_tree);
}


sub run_analysis {
  my $self = shift;

  my $gene_tree = $self->param('gene_tree');

  #compare every gene in the tree with every other each gene/gene
  #pairing is a potential ortholog/paralog and thus we need to analyze
  #every possibility
  printf("%d genes in tree\n", scalar(@{$gene_tree->get_all_leaves})) if $self->debug;

  foreach my $ancestor (reverse @{$gene_tree->get_all_nodes}) {
    next unless scalar(@{$ancestor->children});
    my ($child1, $child2) = @{$ancestor->children};
    my $leaves1 = $child1->get_all_leaves;
    my $leaves2 = $child2->get_all_leaves;
    my @pair_group;
    foreach my $gene1 (@$leaves1) {
     foreach my $gene2 (@$leaves2) {
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2);
      $genepairlink->add_tag("ancestor", $ancestor);
      $genepairlink->add_tag("subtree1", $child1);
      $genepairlink->add_tag("subtree2", $child2);

      my $node_type = $ancestor->get_value_for_tag('node_type');
      if ($node_type eq 'speciation') {
          $self->tag_genepairlink($genepairlink, $self->tag_orthologues($genepairlink), 1);
      } elsif ($node_type eq 'dubious') {
          $self->tag_genepairlink($genepairlink, $self->tag_orthologues($genepairlink), 0);
      } elsif ($node_type eq 'gene_split') {
          $self->tag_genepairlink($genepairlink, 'gene_split', 1);
      } elsif ($node_type eq 'duplication') {
          push @pair_group, $genepairlink;
      } else {
          die sprintf("Unknown node type '%s' for node_id %d\n", $ancestor->get_value_for_tag('node_type'), $ancestor->node_id);
      }

     }
    }

      my @good_ones = ();
      foreach my $genepairlink (@pair_group) {
          my ($pep1, $pep2) = $genepairlink->get_nodes;
          if ($pep1->genome_db_id == $pep2->genome_db_id) {
              push @good_ones, [$genepairlink, 'within_species_paralog', 1];
          } elsif (($genepairlink->get_value_for_tag('ancestor')->duplication_confidence_score < $self->param('no_between')) and $self->is_closest_homologue($genepairlink)) {
              push @good_ones, [$genepairlink, $self->tag_orthologues($genepairlink), 0];
          }
      }
      foreach my $par (@good_ones) {
          $self->tag_genepairlink(@$par);
      }
  }


}

sub print_summary {
  my $self = shift;

  #display summary stats of analysis 
  if($self->debug) {
    printf("orthotree homologies\n");
    foreach my $type (keys(%{$self->param('orthotree_homology_counts')})) {
      printf ( "  %13s : %d\n", $type, $self->param('orthotree_homology_counts')->{$type} );
    }
  }

  $self->check_homology_consistency;

  my $counts_str = stringify($self->param('orthotree_homology_counts'));
  $self->param('gene_tree')->tree->store_tag('OrthoTree_types_hashstr', $counts_str) unless ($self->param('_readonly'));
}


sub display_link_analysis
{
  my $self = shift;
  my $genepairlink = shift;

  #display raw feature analysis
  my ($gene1, $gene2) = $genepairlink->get_nodes;
  my $ancestor = $genepairlink->get_value_for_tag('ancestor');
  printf("%21s(%7d) - %21s(%7d) : %10.3f dist : ",
    $gene1->gene_member->stable_id, $gene1->gene_member_id,
    $gene2->gene_member->stable_id, $gene2->gene_member_id,
    $genepairlink->distance_between);

  printf("%5s ", "");
  printf("%5s ", "");

  print("ancestor:(");
  my $node_type = $ancestor->get_value_for_tag('node_type', '');
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
  if ($ancestor->has_tag('duplication_confidence_score')) {
    printf(" %.4f ", $ancestor->get_value_for_tag('duplication_confidence_score'));
  } else {
    print " N/A    ";
  }

  printf(" %s %d %s\n",
         $genepairlink->get_value_for_tag('orthotree_type'),
         $genepairlink->get_value_for_tag('is_tree_compliant'),
         $ancestor->taxonomy_level(),
        );
}


sub get_ancestor_species_hash
{
    my $self = shift;
    my $node = shift;

    my $species_hash = $node->get_value_for_tag('species_hash');
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
        $has_match->{$pep1->seq_member_id}->{$pep2->genome_db_id} = $genepairlink;
        $has_match->{$pep2->seq_member_id}->{$pep1->genome_db_id} = $genepairlink;
    }

    $self->param('orthotree_homology_counts')->{$orthotree_type}++;
    my $n = $self->param('n_stored_homologies') + 1;
    $self->param('n_stored_homologies', $n);
    print STDERR "$n homologies\n" unless $n % 1000;

    $self->display_link_analysis($genepairlink) if($self->debug>2);
    $self->store_gene_link_as_homology($genepairlink) if $self->param('store_homologies');

}


sub tag_orthologues
{
    my $self = shift;
    my $genepairlink = shift;

    my ($pep1, $pep2) = $genepairlink->get_nodes;
    my $ancestor = $genepairlink->get_value_for_tag('ancestor');
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




sub is_closest_homologue
{
    my $self = shift;
    my $genepairlink = shift;

    my $has_match = $self->param('has_match');
    my ($pep1, $pep2) = $genepairlink->get_nodes;
    my $s1 = $self->get_ancestor_species_hash($genepairlink->get_value_for_tag('subtree1'));
    my $s2 = $self->get_ancestor_species_hash($genepairlink->get_value_for_tag('subtree2'));

    return 0 if $has_match->{$pep1->seq_member_id}->{$pep2->genome_db_id} or $has_match->{$pep2->seq_member_id}->{$pep1->genome_db_id};
    return 0 if exists $s1->{$pep2->genome_db_id};
    return 0 if exists $s2->{$pep1->genome_db_id};
    return 1;
}



########################################################
#
# Tree input/output section
#
########################################################

sub store_gene_link_as_homology {
  my $self = shift;
  my $genepairlink  = shift;

  my $type = $genepairlink->get_value_for_tag('orthotree_type');
  return unless($type);
  my $is_tree_compliant = $genepairlink->get_value_for_tag('is_tree_compliant');
  my $ancestor = $genepairlink->get_value_for_tag('ancestor');

  my ($gene1, $gene2) = $genepairlink->get_nodes;

  # get the mlss from the database
  my $mlss_type;
  my $gdbs;
  my $gdb1 = $gene1->genome_db;
  $gdb1 = $gdb1->principal_genome_db if $gdb1->genome_component;
  # Here, we need to be smart about choosing the mlss and the homology type
  if ($type =~ /^ortholog/) {
      my $gdb2 = $gene2->genome_db;
      $gdb2 = $gdb2->principal_genome_db if $gdb2->genome_component;
      if ($gdb1->is_polyploid and $gdb2->is_polyploid and ($gdb1->dbID == $gdb2->dbID)) {
          $mlss_type = 'ENSEMBL_HOMOEOLOGUES';
          $type      =~ s/ortholog/homoeolog/;
          $gdbs      = [$gdb1];
          #### temp fix triticum_aestivum
          if ( (($gdb1->name eq 'triticum_aestivum') and ($gene1->genome_db->genome_component eq 'U')) or
               (($gdb2->name eq 'triticum_aestivum') and ($gene2->genome_db->genome_component eq 'U')) ) {
              $mlss_type = 'ENSEMBL_PARALOGUES';
              $type      = 'within_species_paralog';
          }
          ####
      } else {
          $mlss_type = 'ENSEMBL_ORTHOLOGUES';
          $gdbs      = [$gdb1, $gdb2];
      }

  } elsif ($type eq 'alt_allele') {
      $mlss_type = 'ENSEMBL_PROJECTIONS';
      $gdbs      = [$gdb1];
  } else {
      $mlss_type = 'ENSEMBL_PARALOGUES';
      $gdbs      = [$gdb1];
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

        my ($mlss, $seq_member_id) = split("_", $mlss_member_id);
        next if $count > 1 and grep {$_->is_polyploid} @{$self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss)->species_set->genome_dbs};

        $bad_key = "mlss seq_member_id : $mlss $seq_member_id";
        print "$bad_key\n" if ($self->debug);
    }
    $self->throw("Inconsistent homologies: $bad_key") if defined $bad_key;
}


1;
