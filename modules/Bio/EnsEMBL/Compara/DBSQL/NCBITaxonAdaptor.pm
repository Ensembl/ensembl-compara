=head1 NAME

NestedSetAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Compara::NCBITaxon;

use Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;
our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor);


sub fetch_node_by_taxon_id {
  my ($self, $taxon_id) = @_;
  my $constraint = "WHERE t.taxon_id = $taxon_id";
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}


sub fetch_parent_for_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $constraint = "WHERE t.taxon_id = " . $node->_parent_id;
  my ($parent) = @{$self->_generic_fetch($constraint)};
  return $parent;
}



##################################
#
# subclass override methods
#
##################################

sub tables {
  my $self = shift;
  return [['ncbi_taxa_nodes', 't'],
          ['ncbi_taxa_names', 'n']
         ];
}


sub columns {
  my $self = shift;
  return ['t.taxon_id as nestedset_id',
          't.parent_id',
          't.left_index',
          't.right_index',
          't.rank',
          'n.name'
          ];
}


sub default_where_clause {
  my $self = shift;
  return "t.taxon_id = n.taxon_id and n.name_class='scientific name'";
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;
  
  my $node = $self->cache_fetch_by_id($rowhash->{'nestedset_id'});
  return $node if($node);
  
  $node = new Bio::EnsEMBL::Compara::NCBITaxon;
  $self->init_instance_from_rowhash($node, $rowhash);
  
  $self->cache_add_object($node);

  return $node;
}


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;
  
  $self->SUPER::init_instance_from_rowhash($node, $rowhash);

  $node->name($rowhash->{'name'});
  $node->rank($rowhash->{'rank'});  
  # print("  create node : ", $node, " : "); $node->print_node;
  
  return $node;
}



1;
