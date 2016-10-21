#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Getopt::Long;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

$| = 1;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'scale'} = 10;

my ($help, $url);

GetOptions('help'           => \$help,
           'url=s'          => \$url,
           'taxa_list=s'    => \$self->{'taxa_list'},
           'taxa_compara'   => \$self->{'taxa_compara'},
           'scale=f'        => \$self->{'scale'},
           'index'          => \$self->{'build_leftright_index'},
           'genetree_dist'  => \$self->{'genetree_dist'},
          );

if($self->{'taxa_list'}) { 
  $self->{'taxa_list'} = [ split(",",$self->{'taxa_list'}) ];
}

if ($help) { usage(); }

$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url ) if $url;
unless(defined($self->{'comparaDBA'})) {
  print("no url\n\n");
  usage();
}

Bio::EnsEMBL::Registry->no_version_check(1);

if ($self->{'taxa_list'}) {
    fetch_by_ncbi_taxa_list($self);
} elsif ($self->{'build_leftright_index'}) {
    update_leftright_index($self);
} elsif ($self->{'taxa_compara'}) {
    fetch_compara_ncbi_taxa($self);
} elsif ($self->{'genetree_dist'}) {
    get_distances_from_genetrees($self);
} else {
    usage();
}

#cleanup memory
if($self->{'root'}) {
#  print("ABOUT TO MANUALLY release tree\n");
  $self->{'root'}->release_tree;
  $self->{'root'} = undef;
#  print("DONE\n");
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "testTaxonTree.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <string>          : connect to compara at url e.g. mysql://ensro\@ecs2:3365/ncbi_taxonomy\n";
  print "  -taxa_list <string>    : print tree by taxa list e.g. \"9606,10090\"\n";
  print "  -taxa_compara          : print tree of the taxa in compara\n";
  print "  -scale <int>           : scale factor for printing tree (def: 10)\n";
  print "  -genetree_dist         : get the species-tree used to reconcile the protein-trees and compute the median branch-lengths\n";
  print " -index                  : build left and right node index to speed up subtree queries.\n";
  print "                           to be used only by the person who sets up a taxonomy database.\n";
  print "taxonTreeTool.pl v1.1\n";

  exit(1);
}


sub fetch_by_ncbi_taxa_list {
  my $self = shift;
  
  my $root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
    -COMPARA_DBA    => $self->{'comparaDBA'},
    -SPECIES_SET    => undef,
    -NO_PREVIOUS    => 1,
    -RETURN_NCBI_TREE       => 1,
    -EXTRATAXON_SEQUENCED   => $self->{'taxa_list'},
  );

  $root->print_tree($self->{'scale'});
  $root->flatten_tree->print_tree($self->{'scale'});
  $self->{'root'} = $root;
}


sub get_distances_from_genetrees {
    my $self = shift;

    my $protein_tree_mlss = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('PROTEIN_TREES')->[0];
    my $root = $protein_tree_mlss->species_tree->root;

    # Used to get the average branch lengths from the trees
    my $sql_dist_1 = 'SELECT distance_to_parent FROM gene_tree_root JOIN gene_tree_node gtn USING (root_id) JOIN gene_tree_node_attr gtna USING (node_id) JOIN gene_tree_node_attr gtnap ON gtnap.node_id = parent_id WHERE clusterset_id = "default" AND gtna.node_type = "speciation" AND gtnap.node_type = "speciation" AND gtnap.species_tree_node_id = ? AND gtna.species_tree_node_id = ?';
    my $sql_dist_2 = 'SELECT gtn.distance_to_parent FROM gene_tree_root JOIN gene_tree_node gtn USING (root_id) JOIN seq_member USING (seq_member_id) JOIN species_tree_node stn USING (genome_db_id) JOIN gene_tree_node_attr gtnap ON gtnap.node_id = gtn.parent_id WHERE clusterset_id = "default" AND gtnap.node_type = "speciation" AND gtnap.species_tree_node_id = ? AND stn.node_id = ? AND stn.root_id = ?';
    my $sth_dist_1 = $self->{'comparaDBA'}->dbc->prepare($sql_dist_1);
    my $sth_dist_2 = $self->{'comparaDBA'}->dbc->prepare($sql_dist_2);

    foreach my $node ($root->get_all_subnodes) {
        my $sth = $node->is_leaf ? $sth_dist_2 : $sth_dist_1;
        $sth->execute($node->parent->node_id, $node->node_id, $node->is_leaf ? ($root->node_id) : ());
        my @allval = sort {$a <=> $b} map {$_->[0]} @{$sth->fetchall_arrayref};
        $sth->finish;
        my $n = scalar(@allval);
        if ($n) {
            my $i = int($n/2);
            my $val = $allval[$i];
            print $node->parent->node_id, "/", $node->parent->name, " ", $node->node_id, "/", $node->name, " $val ($n/$i)\n";
            $node->distance_to_parent($val);
        }
    }
    $root->print_tree($self->{'scale'});
    $self->{'root'} = $root;

    my $newick = $root->newick_format;
    print("\n$newick\n");
}

sub fetch_compara_ncbi_taxa {
  my $self = shift;
  
  printf("fetch_compara_ncbi_taxa\n");
  
  my $root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
    -COMPARA_DBA    => $self->{'comparaDBA'},
    -RETURN_NCBI_TREE       => 1,
  );

  $root->print_tree($self->{'scale'});
  
  my $newick = $root->newick_format;
  print("$newick\n");

  print $root->newick_format('ncbi_taxon'), "\n";

  $self->{'root'} = $root;
}

sub update_leftright_index {
  my $self = shift;

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $root = $taxonDBA->fetch_node_by_name('root');
  $root = $root->root;
  print STDERR "Starting indexing...\n";
  build_store_leftright_indexing($self, $root);
  $self->{'root'} = $root;
}

sub build_store_leftright_indexing {
  my $self = shift;
  my $node = shift;
  my $counter =shift;

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;

  $counter = 1 unless ($counter);
  
  $node->left_index($counter++);
  foreach my $child_node (@{$node->sorted_children}) {
    $counter = build_store_leftright_indexing($self, $child_node, $counter);
  }
  $node->right_index($counter++);
  $taxonDBA->update($node);
  $node->release_children;
  print STDERR "node_id = ", $node->node_id, " indexed and stored, li = ",$node->left_index," ri = ",$node->right_index,"\n";
  return $counter;
}


