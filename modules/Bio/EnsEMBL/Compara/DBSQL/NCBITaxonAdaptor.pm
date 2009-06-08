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


=head2 fetch_node_by_taxon_id

  Arg [1]    : int $taxon->dbID
               the database id for a ncbi taxon
  Example    : $taxon = $nbcitaxonDBA->fetch_node_by_taxon_id($taxon_id);
  Description: Returns an NCBITaxon object for the given NCBI Taxon id.
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : thrown if $taxon_id is not defined
  Caller     : general

=cut

sub fetch_node_by_taxon_id {
  my ($self, $taxon_id) = @_;
  my $constraint = "WHERE t.taxon_id = $taxon_id";
  my ($node) = @{$self->_generic_fetch($constraint)};
  unless ($node) {
    my $new_taxon_id = $self->fetch_node_id_by_merged_taxon_id($taxon_id);
    if (defined $new_taxon_id) {
      $constraint = "WHERE t.taxon_id = $new_taxon_id";
      ($node) = @{$self->_generic_fetch($constraint)};
    }
    if ($node) {
      warning("The given taxon_id=$taxon_id is now deprecated and has been merged with taxon_id=".$node->taxon_id,"\n");
    }
  }
  return $node;
}

sub fetch_node_id_by_merged_taxon_id {
  my ($self, $taxon_id) = @_; 

  my $sql = "SELECT t.taxon_id FROM ncbi_taxa_node t, ncbi_taxa_name n WHERE n.name = ? and n.name_class = 'merged_taxon_id' AND t.taxon_id = n.taxon_id";

  my $sth = $self->dbc->prepare($sql);
  $sth->execute($taxon_id);
  my ($merged_taxon_id) = $sth->fetchrow_array();
  $sth->finish;

  return $merged_taxon_id;
}


=head2 fetch_node_by_name

  Arg [1]    : a taxonomy name
               the database name for a ncbi taxon
  Example    : $taxon = $nbcitaxonDBA->fetch_node_by_name($name);
  Description: Returns an NCBITaxon object for the given NCBI Taxon name.
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : thrown if $name is not defined
  Caller     : general

=cut


sub fetch_node_by_name {
  my ($self, $name) = @_;
  my $constraint = "WHERE n.name = '$name'";
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}


=head2 fetch_node_by_genome_db_id

  Arg [1]    : a genome_db_id
  Example    : $taxon = $nbcitaxonDBA->fetch_node_by_genome_db_id($gdbID);
  Description: Returns an NCBITaxon object for the given genome_db_id.
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : thrown if $gdbID is not defined
  Caller     : general

=cut


sub fetch_node_by_genome_db_id {
  my ($self, $gdbID) = @_;
  my $constraint = "JOIN genome_db gdb ON ( t.taxon_id = gdb.taxon_id) 
                    WHERE gdb.genome_db_id=$gdbID";
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}


=head2 fetch_parent_for_node

  Overview   : returns the parent NCBITaxon object for this node
  Example    : my $my_parent = $object->parent();
  Returntype : undef or Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : none
  Caller     : general

=cut


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
sub _objs_from_sth {
  my ($self, $sth) = @_;

  my $node_list = [];
  while(my $rowhash = $sth->fetchrow_hashref) {
    my $node = $self->create_instance_from_rowhash($rowhash);        
    push @$node_list, $node;
  }

  return $node_list;
}

sub tables {
  my $self = shift;
  return [['ncbi_taxa_node', 't'],
          ['ncbi_taxa_name', 'n']
         ];
}


sub columns {
  my $self = shift;
  return ['t.taxon_id as node_id',
          't.parent_id',
          't.left_index',
          't.right_index',
          't.rank',
          't.genbank_hidden_flag',
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
  
  my $node = $self->cache_fetch_by_id($rowhash->{'node_id'});
  return $node if($node);
  
  $node = new Bio::EnsEMBL::Compara::NCBITaxon;
  $self->init_instance_from_rowhash($node, $rowhash);
  $self->_load_tagvalues($node);
  
  # The genebuilders has troubles with load_taxonomy.pl when the
  # following line was commented out
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
  $node->genbank_hidden_flag($rowhash->{'genbank_hidden_flag'});
  $node->distance_to_parent(0.1);  
  # print("  create node : ", $node, " : "); $node->print_node;
  
  return $node;
}

sub _load_tagvalues {
  my $self = shift;
  my $node = shift;
  
  unless($node->isa('Bio::EnsEMBL::Compara::NCBITaxon')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NCBITaxon] not a $node");
  }

  my $sth = $self->prepare("SELECT name_class, name from ncbi_taxa_name where taxon_id=?");
  $sth->execute($node->node_id);  
  while (my ($tag, $value) = $sth->fetchrow_array()) {
    $node->add_tag($tag,$value,1);
  }
  $sth->finish;
}

sub update {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $parent_id = 0;
  if($node->parent) {
    $parent_id = $node->parent->node_id ;
  }
  my $root_id = $node->root->node_id;

  my $table= $self->tables->[0]->[0];
  my $sql = "UPDATE $table SET ".
               "parent_id=$parent_id".
               ",root_id=$root_id".
               ",left_index=" . $node->left_index .
               ",right_index=" . $node->right_index .
             " WHERE $table.taxon_id=". $node->node_id;

  $self->dbc->do($sql);
}


1;
