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
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


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

  if (! defined $taxon_id) {
    throw ("taxon_id is not defined");
  }

  my $constraint = 't.taxon_id = ?';
  $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
  my $node = $self->generic_fetch_one($constraint);

  unless ($node) {
    my $join = [[['ncbi_taxa_name', 'n2'], 'n2.name_class = "merged_taxon_id" AND t.taxon_id = n2.taxon_id']];
    $constraint = 'n2.name = ?';
    $node = $self->generic_fetch_one($constraint, $join);
    if ($node) {
      warning("The given taxon_id=$taxon_id is now deprecated and has been merged with taxon_id=".$node->taxon_id."\n");
    }
  }
  return $node;
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

  if (! defined $name) {
    throw ("name is undefined");
  }

  my $constraint = 'n.name = ?';
  $self->bind_param_generic_fetch($name, SQL_VARCHAR);
  return $self->generic_fetch_one($constraint);
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

  if (! defined $gdbID) {
    throw "gdbID is undefined";
  }

  my $join = [[['genome_db', 'gdb'], 't.taxon_id = gdb.taxon_id']];
  my $constraint = 'gdb.genome_db_id = ?';

  $self->bind_param_generic_fetch($gdbID, SQL_INTEGER);
  return $self->generic_fetch_one($constraint, $join);
}


#
# Methods reimplemented because of the SQL column taxon_id (instead of node_id)
################################################################################


=head2 fetch_all

  Arg[1]     : -none-
  Example    : $ncbi_roots = $ncbitaxon_adaptor->fetch_all();
  Description: Fetches from the database all the root nodes
  Returntype : arrayref of Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my ($self) = @_;

  my $table = ($self->_tables)[0]->[1];
  my $constraint = "$table.taxon_id = $table.root_id";
  return $self->generic_fetch($constraint);
}


=head2 fetch_node_by_node_id
  Description: Alias for fetch_node_by_taxon_id. Please use the later instead
=cut

sub fetch_node_by_node_id {
    my $self = shift;
    return $self->fetch_node_by_taxon_id(@_);
}


##################################
#
# subclass override methods
#
##################################

sub _tables {
  return (['ncbi_taxa_node', 't'],
          ['ncbi_taxa_name', 'n']
         );
}


sub _columns {
  return ('t.taxon_id as node_id',
          't.parent_id',
          't.left_index',
          't.right_index',
          't.root_id',
          't.rank',
          't.genbank_hidden_flag',
          'n.name'
          );
}


sub _default_where_clause {
    return "t.taxon_id = n.taxon_id AND n.name_class='scientific name'";
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;
  
  my $node = $self->cache_fetch_by_id($rowhash->{'node_id'});
  return $node if($node);
  
  $node = new Bio::EnsEMBL::Compara::NCBITaxon;
  $self->init_instance_from_rowhash($node, $rowhash);
  
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

  my $table= ($self->_tables)[0]->[0];
  my $sth = $self->dbc->prepare("UPDATE $table SET parent_id = ?, root_id = ?, left_index = ?, right_index = ? WHERE taxon_id = ?");

  $sth->execute($node->parent ? $node->parent->node_id : undef, $node->root->node_id, $node->left_index, $node->right_index, $node->node_id);
}


1;
