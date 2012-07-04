# $Id$

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
  my $node     = $tree->find_node_by_node_id($node_id) || die "No node_id $node_id in ProteinTree";    
  my $ta       = $c_db->get_NCBITaxonAdaptor();
  
  my $taxon      = $ta->fetch_node_by_taxon_id($node->{_taxon_id});
  my $taxon_name = $taxon->ensembl_alias_name();


   
  my $caption   = "Taxon Node: ";
#use Data::Dumper;warn Dumper($node) if($node_id eq '3201');  
  $self->caption($caption);
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
    label => $node->{_p_value},  
  });
  
  $self->add_entry({
    type => 'Taxon ID',
    label => $node->{_taxon_id},  
  });
  
  $self->add_entry({
    type => 'Taxon Name',
    label => $taxon_name,  
  });          
}

1;