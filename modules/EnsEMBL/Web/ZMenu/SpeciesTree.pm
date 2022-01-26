=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::SpeciesTree;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {  
  my $self     = shift;
  my $cdb      = shift || 'compara';

  my $hub      = $self->hub;
  my $c_db     = $hub->database('compara');
  my $object   = $self->object;
  my $tree     = $object->isa('EnsEMBL::Web::Object::GeneTree') ? $object->tree : $object->get_SpeciesTree($cdb);
  die 'No tree for gene' unless $tree;
  my $node_id  = $hub->param('node')                   || die 'No node value in params';  
  my $node     = $tree->root->find_node_by_node_id($node_id) || die "No node_id $node_id in ProteinTree";
  my $taxon    = $node->taxon;
  
  my $leaf_count      = scalar @{$node->get_all_leaves};
  my $is_leaf         = $node->is_leaf;
  my $is_root         = ($node->root eq $node);
  my $parent_distance = $node->distance_to_parent || 0;  
  my $taxon_id        = $node->taxon_id;     
  my $scientific_name = $taxon->scientific_name();
  my $taxon_mya       = $node->get_divergence_time();
  my $taxon_alias     = $node->get_common_name();
 

  my $caption   = "Taxon: ";
  if (defined $taxon_alias) {
    $caption .= $taxon_alias;
    $caption .= (sprintf " ~%d MYA", $taxon_mya) if defined $taxon_mya;
    $caption .= " ($scientific_name)" if defined $scientific_name;
  } elsif (defined $scientific_name) {
    $caption .= $scientific_name;
    $caption .= (sprintf " ~%d MYA", $taxon_mya) if defined $taxon_mya;
  } else {
    $caption .= 'unknown';
  }
  
  $self->caption($caption);
  
#use Data::Dumper;warn Dumper($node) if($node_id eq '3201');
  $self->add_entry({
    type => 'Node ID',
    label => $node_id,  
  });
  
  $self->add_entry({
    type => 'n_members',
    label => $node->{_n_members},  
  });

  $self->add_entry({
    type => 'P value',
    label => $node->{_pvalue},  
  });

  $self->add_entry({
    type => 'Lambda',
    label => $node->lambdas,  
  }); 
      
  $self->add_entry({
    type => 'Taxon ID',
    label => $node->{_taxon_id},  
  });
  
  $self->add_entry({
    type => 'Scientific Name',
    label => $scientific_name,  
  });
  
}

1;