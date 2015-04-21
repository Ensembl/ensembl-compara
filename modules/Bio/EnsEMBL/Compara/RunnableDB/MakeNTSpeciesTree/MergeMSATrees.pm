=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeMSATrees

=cut

=head1 SYNOPSIS

=cut



package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeMSATrees;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;
use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_; 
 my $species_tree_adapt = $self->compara_dba->get_SpeciesTreeAdaptor;

 # get the full compara tree and store it in the db
 my $tree_path = $self->param('species_tree_bl');
 my $full_species_tree = `cat $tree_path`;
 chomp $full_species_tree;
 my $full_tree = $species_tree_adapt->new_from_newick($full_species_tree, "compara_species_tree", 'name');

 eval {
  $species_tree_adapt->store($full_tree, $self->param('dummy_mlss_value'));
 };
 throw $@ if $@;
 
  # get the big tree from the db
 my $full_species_tree_obj = $species_tree_adapt->fetch_by_method_link_species_set_id_label(
  $self->param('dummy_mlss_value'), "compara_species_tree");
 my $full_tree_root =  $full_species_tree_obj->root;

 # start to process the small trees
 my @tree_mlss_ids = split ",", $self->param('msa_mlssid_csv_string');

 foreach my $mlss_id(@tree_mlss_ids){
  my @orig_species_trees = $species_tree_adapt->fetch_by_method_link_species_set_id_label($mlss_id, 'default');
  my $orig_species_tree = $orig_species_trees[0];
  my $orig_tree = $orig_species_tree->species_tree;
  $orig_tree=~s/:0;/;/;

  my $orig_species = lc join ":", $orig_tree=~m/([[:alpha:]_]+)/g;
  my $pfit_species_trees = $species_tree_adapt->fetch_all_by_method_link_species_set_id_label_pattern($mlss_id, ".pf");

  my(@tree_branch_lengths, @species_branch_lengths, @median_bls, $median_newick);
  # get the branch lengths from the phylofit trees
  foreach my $pfit_tree(@$pfit_species_trees){ 
   my $pfit_species = lc join ":", $pfit_tree->species_tree=~m/([[:alpha:]_]+)/g;
   if($pfit_species eq $orig_species){
    push @tree_branch_lengths, [ $pfit_tree->species_tree=~m/([\d\.]+)/g ];
   }  
  }

  # put all the phylofit branch lengths into an array
  foreach my $tree_bl(@tree_branch_lengths){
   for(my$i=0;$i<@$tree_bl;$i++){
    push @{$species_branch_lengths[$i]}, $tree_bl->[$i];
   }
  }

  # find the median phylofit branch lengths
  for(my$i=0;$i<@species_branch_lengths;$i++){
   my @temp = sort {$a <=> $b} @{ $species_branch_lengths[$i] };
   my $med_value = int (@temp / 2);
   $median_bls[$i] = $temp[ $med_value ];
  }

  # substitute the original branch lengths for thr median branch lengths
  my@ots = $orig_tree=~/([^\d\.]+)/g;
  for(my$i=0;$i<@ots;$i++){
   $median_newick .= $ots[$i];
   if($median_bls[$i]){
    $median_newick .= $median_bls[$i];
   }
  }
  # store the median branch length trees
  my $median_tree = $species_tree_adapt->new_from_newick($median_newick, "median_species_tree", 'name');
  $median_tree=~s/:0;/;/;

  eval {
   $species_tree_adapt->store($median_tree, $mlss_id);
  };
  throw $@ if $@;
  
  my $med_species_tree_obj = $species_tree_adapt->fetch_by_method_link_species_set_id_label(
   $mlss_id, "median_species_tree");
  my $med_tree_root =  $med_species_tree_obj->root;
  my $all_med_tree_leaves = $med_tree_root->get_all_leaves;
  for(my$i=0;$i<@$all_med_tree_leaves - 1;$i++){
   my $med3leaf_i = $all_med_tree_leaves->[$i];
   my $full3leaf_i = $full_tree_root->find_node_by_name($med3leaf_i->node_name);
   # set the full-tree leaf node branch lengths to the median values
   $full3leaf_i->distance_to_parent($med3leaf_i->distance_to_parent); 
   for(my$j=$i+1;$j<@$all_med_tree_leaves;$j++){
    my $med3leaf_j = $all_med_tree_leaves->[$j];
    my $full3leaf_j = $full_tree_root->find_node_by_name($med3leaf_j->node_name);
    $full3leaf_j->distance_to_parent($med3leaf_j->distance_to_parent);
    my $full3ancestor_ij = $full3leaf_j->find_first_shared_ancestor($full3leaf_i);
    my $med3ancestor_ij = $med3leaf_j->find_first_shared_ancestor($med3leaf_i);
    next unless $med3ancestor_ij->has_parent;
    # set the full-tree internal node branch lengths to the median values
    $full3ancestor_ij->distance_to_parent($med3ancestor_ij->distance_to_parent);
   }
  }
 }
 my $merged_newick = $full_tree_root->newick_format("simple");
 $merged_newick=~s/:0;/;/;
 my $merged_tree = $species_tree_adapt->new_from_newick($merged_newick, "merged_branch_lengths", 'name');
 $species_tree_adapt->store($merged_tree, $self->param('dummy_mlss_value')); 
}

1;
