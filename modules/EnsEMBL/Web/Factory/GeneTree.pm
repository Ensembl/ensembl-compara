=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Factory::GeneTree;

### NAME: EnsEMBL::Web::Factory::GeneTree
### Simple factory to create a gene tree object from a stable ID 

### STATUS: Stable

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self     = shift;    
  
  my $gt = $self->param('gt');
     
  return $self->problem('fatal', 'Valid Gene Tree ID required', 'Please enter a valid gene tree ID in the URL.') unless $gt;

  my $cdb = ($gt =~ /^EGGT/) ? 'compara_pan_ensembl' : 'compara';
  my $database = $self->database($cdb);
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the compara database.') unless $database;
  
  my $tree = $database->get_GeneTreeAdaptor->fetch_by_stable_id($gt);
  #if ($self->param('super_tree') eq 'on') {
  #  my $parent = $database->get_GeneTreeAdaptor->fetch_parent_tree($tree);
  #  if ($parent->tree_type ne 'clusterset') {
  #    $parent->expand_subtrees();
  #    $parent->attach_alignment('super-align');
  #    $tree = $parent;
  #  }
  #}
 
  if ($tree) {
    $self->DataObjects($self->new_object('GeneTree', $tree->root, $self->__data));
  }
  else { 
    return $self->problem('fatal', "Could not find GeneTree $gt", "Either $gt does not exist in the current Ensembl database, or there was a problem retrieving it.");
  }
  
  $self->param('gt', $gt);
}

1;
  
