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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::NCBITaxon;

use Bio::EnsEMBL::DBSQL::Support::LruIdCache;

use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


#
# Virtual / overriden methods from Bio::EnsEMBL::DBSQL::BaseAdaptor
######################################################################

sub ignore_cache_override {
    return 1;
}

sub _build_id_cache {
    my $self = shift;
    my $cache = Bio::EnsEMBL::DBSQL::Support::LruIdCache->new($self, 3000);
    $cache->build_cache();
    return $cache;
}


#
# FETCH methods
#####################




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
  # In theory we should be checking $self->_no_id_cache() but we've set ignore_cache_override to 1 (see above)
  return $self->_id_cache()->get($taxon_id);
}


sub _uncached_fetch_by_dbID {
  my ($self, $taxon_id) = @_;
  assert_integer($taxon_id, 'taxon_id');

  my $constraint = 't.taxon_id = ?';
  $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
  my $node = $self->generic_fetch_one($constraint);

  unless ($node) {
    my $join = [[['ncbi_taxa_name', 'n'], 'n.name_class = "merged_taxon_id" AND t.taxon_id = n.taxon_id']];
    $constraint = 'n.name = ?';
    $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
    $node = $self->generic_fetch_one($constraint, $join);
    if ($node) {
      warning("The given taxon_id=$taxon_id is now deprecated and has been merged with taxon_id=".$node->taxon_id."\n");
    }
  }
  return $node;
}


=head2 fetch_by_dbID

  Arg [1]    : int $taxon->dbID
               the database id for a ncbi taxon
  Example    : $taxon = $nbcitaxonDBA->fetch_by_dbID($taxon_id);
  Description: Returns an NCBITaxon object for the given NCBI Taxon id.
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : thrown if $taxon_id is not defined
  Caller     : general

=cut

sub fetch_by_dbID {
    my $self = shift;
    return $self->fetch_node_by_taxon_id(@_);
}


=head2 fetch_all_by_dbID_list

  Arg [1]    : Arrayref of taxon_ids (database IDs for NCBI taxa)
  Example    : $taxa = $nbcitaxonDBA->fetch_all_by_dbID_list([$taxon_id1, $taxon_id2]);
  Description: Returns all the NCBITaxon objects for the given NCBI Taxon ids.
  Returntype : Arrayref of Bio::EnsEMBL::Compara::NCBITaxon
  Caller     : general

=cut

sub fetch_all_by_dbID_list {
    my ($self, $taxon_ids) = @_;
    # In theory we should be checking $self->_no_id_cache() but we've set ignore_cache_override to 1 (see above)
    return $self->_id_cache()->get_by_list($taxon_ids);
}

sub _uncached_fetch_all_by_id_list {
    my ($self, $taxon_ids) = @_;

    my $nodes = $self->SUPER::_uncached_fetch_all_by_id_list($taxon_ids, undef, 'taxon_id', 1);
    my %seen_taxon_ids = map {$_->taxon_id => $_} @$nodes;

    my @missing_taxon_ids = grep {!$seen_taxon_ids{$_}} @$taxon_ids;

    if (@missing_taxon_ids) {
        my $join = [[['ncbi_taxa_name', 'n'], 'n.name_class = "merged_taxon_id" AND t.taxon_id = n.taxon_id']];
        my $more_nodes = $self->generic_fetch_concatenate(\@missing_taxon_ids, 'n.name', SQL_VARCHAR, $join);
        foreach my $n (@$more_nodes) {
            $seen_taxon_ids{$n->taxon_id} = $n unless $seen_taxon_ids{$n->taxon_id};
        }
        return [values %seen_taxon_ids];
    }
    return $nodes;
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

  my $join = [[['ncbi_taxa_name', 'n'], 't.taxon_id = n.taxon_id']];
  my $constraint = 'n.name = ?';
  $self->bind_param_generic_fetch($name, SQL_VARCHAR);
  return $self->generic_fetch_one($constraint, $join);
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

  assert_integer($gdbID, 'genome_db_id');

  my $join = [[['genome_db', 'gdb'], 't.taxon_id = gdb.taxon_id']];
  my $constraint = 'gdb.genome_db_id = ?';

  $self->bind_param_generic_fetch($gdbID, SQL_INTEGER);
  return $self->generic_fetch_one($constraint, $join);
}


=head2 fetch_all_nodes_by_name

  Arg [1]    : $name: the name to search in the database. It can be
                a MySQL pattern (e.g. with '%' or '_')
  Arg [2]    : $name_class: a name class to restrict the search to
                (such as 'synonym', 'common name', etc)
  Example    : $dogs = $nbcitaxonDBA->fetch_all_nodes_by_name('Canis%');
  Description: Returns the list of NCBITaxon objects that match $name
                (and $name_class if given)
  Returntype : arrayref of Bio::EnsEMBL::Compara::NCBITaxon
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_nodes_by_name {
    my ($self, $name, $name_class) = @_;

    if ($name_class) {
        my $join = [[['ncbi_taxa_name', 'n'], 'n.name_class = ? AND t.taxon_id = n.taxon_id']];
        $self->bind_param_generic_fetch($name, SQL_VARCHAR);
        $self->bind_param_generic_fetch($name_class, SQL_VARCHAR);
        return $self->generic_fetch('n.name LIKE ?', $join);
    } else{
        my $join = [[['ncbi_taxa_name', 'n'], 't.taxon_id = n.taxon_id']];
        $self->bind_param_generic_fetch($name, SQL_VARCHAR);
        return $self->generic_fetch('n.name LIKE ?', $join);
    }
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


sub _tag_capabilities {
    return ('ncbi_taxa_name', undef, 'taxon_id', 'taxon_id', 'name_class', 'name');
}


sub _tables {
  return (['ncbi_taxa_node', 't'],
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
          );
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node = $self->_id_cache->cache->{$rowhash->{'node_id'}};
  return $node if($node);
  
  $node = new Bio::EnsEMBL::Compara::NCBITaxon;
  $self->init_instance_from_rowhash($node, $rowhash);
  
  # The genebuilders has troubles with load_taxonomy.pl when the
  # following line was commented out
  $self->_id_cache->put($rowhash->{'node_id'}, $node);

  return $node;
}


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;

  $self->SUPER::init_instance_from_rowhash($node, $rowhash);

  $node->rank($rowhash->{'rank'});
  $node->genbank_hidden_flag($rowhash->{'genbank_hidden_flag'});
  $node->distance_to_parent(0.1);  
  # print("  create node : ", $node, " : "); $node->print_node;
  
  return $node;
}


sub update {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::NestedSet', 'node');

  my $table= ($self->_tables)[0]->[0];
  my $sth = $self->dbc->prepare("UPDATE $table SET parent_id = ?, root_id = ?, left_index = ?, right_index = ? WHERE taxon_id = ?");

  $sth->execute($node->parent ? $node->parent->node_id : undef, $node->root->node_id, $node->left_index, $node->right_index, $node->node_id);
}


1;
