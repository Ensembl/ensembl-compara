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
Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies
=head1 AUTHORSHIP
Ensembl Team. Individual contributions can be found in the GIT log.
=cut

package Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::AddPseudogenesNodes;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

## Defines the default parameters for the Job
sub param_defaults 
{
    return 
	{
        
    };
}

## This subroutine is called before run in order to check that all the parameters are correct
sub fetch_input {
    my $self = shift @_;

   ## die "Tree stable ID must be defined" unless defined($self->param('tree_stable_id'));

    # Adaptors in the current Compara DB
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
    $self->param('tree_node_adaptor', $self->compara_dba->get_GeneTreeNodeAdaptor);
}        

sub run 
{
  my $self = shift @_;

  my $gene_member_adaptor = $self->param('gene_member_adaptor');
  my $gene_tree_adaptor = $self->param('gene_tree_adaptor');
  my $treenode_adaptor = $self->param('tree_node_adaptor');

  ## Fetching the root of the tree in the Master db
  my $root_id = $self->param('gene_tree_id');
  my $tree = $gene_tree_adaptor->fetch_by_root_id($root_id);
  
  die "Could not find tree with root id ".$root_id unless(defined($tree));
  my $root = $tree->root;

  ## For each member line of the parametrer file

  my $tag = "";

  my @genes = split(',', $self->param('pseudogenes'));
  foreach my $this_gene(@genes)
  {
    next unless $this_gene;
	  my $gene = $gene_member_adaptor->fetch_by_stable_id($this_gene);
    unless($gene)
    {
      print("Could not find gene with stable id ".$this_gene) if ($self->debug > 3);
      next;
    }
	  #if($gene->has_GeneTree)
	  #{
		#	print ($gene->stable_id."is already placed in a tree");
		#	next;
	  #}            
	  ## my $seq = $gene->canonical_seq_member ## Replace with the pseudogene sequence
	  my $seq;
	  foreach my $this_seq(@{$gene->get_all_SeqMembers})
	  {
			print($this_seq->stable_id." : ".$this_seq->get_Transcript->biotype."\n") if($self->debug > 7);
			if($this_seq->get_Transcript->biotype =~ /pseudogene/)
			{
				$seq = $this_seq;
			}
	  }
		if(!defined($seq))
		{
			print("Could not find a pseudogene transcript for gene ", $gene->stable_id, ". Will use canonical seqMember instead.\n") if ($self->debug > 3);
			$seq = $gene->get_canonical_SeqMember;
		}   	      
		print("Inserting sequence ".$seq->stable_id, "\n") if ($self->debug > 3);
	  $tag .= $seq->stable_id.',';
	  if(!defined($tree->find_leaf_by_name($seq->stable_id)))
		{	
			my $node_to_insert = new Bio::EnsEMBL::Compara::GeneTreeMember;
			$node_to_insert->seq_member_id($seq->dbID);
			$root->add_child($node_to_insert); # Will connect the objects together, which will tell the adaptor the parent_id
			$node_to_insert->tree($tree); # Will connect the objects together, which will tell the adaptor the root_id
			$treenode_adaptor->store_node($node_to_insert);
		}
		else
		{
			print("The tree already cointains the sequence you want to add\n") if ($self->debug > 3);
		}
	}
    $tree->store_tag('added_genes_list', $tag);
    $self->dataflow_output_id({'gene_tree_id' => $root_id}, 1);
}

1;
