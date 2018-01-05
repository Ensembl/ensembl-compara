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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeEMSAtrees

=cut

=head1 SYNOPSIS

=cut



package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeEMSAtrees;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_; 
 my $all_phylofit_trees = $self->param_required('phylofit_trees');

 my %branch_lengths;

 my @mlssid_list = split ",", $self->param('msa_mlssid_csv_string');
 foreach my $mlss_id( @mlssid_list ){
  my $pfit_species_trees = $all_phylofit_trees->{$mlss_id};
  my %Phylo_tree_branch_lengths;
  foreach my $phylo_tree(@{ $pfit_species_trees }){
   my $root = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($phylo_tree);
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
