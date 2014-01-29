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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeEMSAtrees

=cut

=head1 SYNOPSIS

=cut



package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeEMSAtrees;

use strict;
use Bio::EnsEMBL::Utils::Exception ('throw');
use Data::Dumper;
use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_; 
 my $species_tree_adapt = $self->compara_dba->get_SpeciesTreeAdaptor;

# # get the full compara tree and store it in the db
# my $tree_path = $self->param('species_tree_bl');
# my $full_species_tree = `cat $tree_path`;
# chomp $full_species_tree;
# my $full_tree = $species_tree_adapt->new_from_newick($full_species_tree, "compara_species_tree", 'name');
#
# eval {
#  $species_tree_adapt->store($full_tree, $self->param('dummy_mlss_value'));
# };
# throw $@ if $@;
# 
#  # get the big tree from the db
# my $full_species_tree_obj = $species_tree_adapt->fetch_by_method_link_species_set_id_label(
#  $self->param('dummy_mlss_value'), "compara_species_tree");
# my $full_tree_root =  $full_species_tree_obj->root;

my %branch_lengths;

 my @mlssid_list = eval $self->param('msa_mlssid_csv_string');
 foreach my $mlss_id( @mlssid_list ){
  my $pfit_species_trees = $species_tree_adapt->fetch_all_by_method_link_species_set_id_label_pattern($mlss_id, "phylo_exe:"); 
  my %Phylo_tree_branch_lengths;
  foreach my $phylo_tree(@{ $pfit_species_trees }){
   my $root = $phylo_tree->root;
   my $all_leaves = $root->get_all_leaves;
   for(my$i=0;$i<@$all_leaves - 1;$i++){
    my $leaf_i = $all_leaves->[$i];
    for(my$j=$i+1;$j<@$all_leaves;$j++){
     my $leaf_j = $all_leaves->[$j];
     my $leaves_ij = join(":",$leaf_i->name, $leaf_j->name);
     
     $branch_lengths{ $leaves_ij }
    }
   }
  }
 }
}

1;
