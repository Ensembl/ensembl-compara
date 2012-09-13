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
  my $taxon    = $ta->fetch_node_by_taxon_id($node->{_taxon_id});
  
  my $leaf_count      = scalar @{$node->get_all_leaves};
  my $is_leaf         = $node->is_leaf;
  my $is_root         = ($node->root eq $node);
  my $parent_distance = $node->distance_to_parent || 0;  
  my $taxon_id        = $node->taxon_id;     
  my $scientific_name = $taxon->scientific_name();
  my $taxon_mya       = $taxon->get_tagvalue('ensembl timetree mya');
  my $taxon_alias     = $taxon->ensembl_alias_name(); 
 

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
    type => 'Taxon ID',
    label => $node->{_taxon_id},  
  });
  
  $self->add_entry({
    type => 'Scientific Name',
    label => $scientific_name,  
  });
}

1;