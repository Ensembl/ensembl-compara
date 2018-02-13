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

Bio::EnsEMBL::Compara::DBSQL::GeneTreeObjectStoreAdaptor

=head1 DESCRIPTION

Until we have a proper ObjectStore database available in Ensembl, we're going to use a simple one in MySQL.
The underlying table associates arbitrary data structures (any Perl scalar) to a GeneTree, and is given a
label to split the the overall data-load into meaningful smaller chunks (e.g. tracks, layers).

This adaptor provides a method to store data, and a method to fetch data. There is no Perl object associated
to this adaptor.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::DBSQL::GeneTreeObjectStoreAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::Utils::Compress;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 fetch_by_GeneTree_and_label

  Arg [1]       : (GeneTree) $gene_tree or its root_id
  Arg [2]       : (string) $label the data label
  Example       : $exon_boundaries = $geneTreeObjectStoreAdaptor->fetch_by_GeneTree_and_label($tree, 'exon_boundaries');
  Description   : Returns the data associated to this tree and this label.  The method
                  doesn't care about what the data represent and doesn't even try to
                  parse them.
  ReturnType    : scalar
  Exceptions    : If the arguments are not wrong
  Caller        : General

=cut

sub fetch_by_GeneTree_and_label {
    my ($self, $gene_tree, $label) = @_;

    assert_ref_or_dbID($gene_tree, 'Bio::EnsEMBL::Compara::GeneTree', 'gene_tree');
    throw('A label must be given') unless $label;       # Must be defined and non-empty

    my $constraint = 'go.root_id = ? AND go.data_label = ?';
    $self->bind_param_generic_fetch(ref($gene_tree) ? $gene_tree->root_id() : $gene_tree, SQL_INTEGER);
    $self->bind_param_generic_fetch($label, SQL_VARCHAR);
    return $self->generic_fetch_one($constraint);
}

###############################
#
# Subclass override methods
#
###############################

sub _tables {
    return (['gene_tree_object_store', 'go']);
}

sub _columns {
    return qw(go.compressed_data);
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my $compressed_data;
    $sth->bind_columns(\$compressed_data);

    my $data_list = [];
    while ($sth->fetch()) {
        my $uncompressed_data = Bio::EnsEMBL::Compara::Utils::Compress::uncompress_from_mysql($compressed_data);
        push @$data_list, $uncompressed_data;
    }
    return $data_list;
}


=head2 store

  Arg [1]       : (GeneTree) $gene_tree or its root_id
  Arg [2]       : (string) $label the data label
  Example       : $geneTreeObjectStoreAdaptor->store($tree, 'exon_boundaries', $stringified_exon_boundaries_data);
  Description   : A standard store method. Data is compressed right here to (1) take less space
                  on the server and (2) be quicker to transfer.
                  The compressed string is structured as MySQL's COMPRESS() would do it, which
                  enables UNCOMPRESS().
  ReturnType    : The number of rows affected
  Exceptions    : If the arguments are not wrong
  Caller        : General

=cut

sub store {
    my ($self, $gene_tree, $label, $data) = @_;

    assert_ref_or_dbID($gene_tree, 'Bio::EnsEMBL::Compara::GeneTree', 'gene_tree');
    throw('A label must be given') unless $label;       # Must be defined and non-empty
    throw('Data must be given') unless defined $data;   # Must be defined but can be empty

    my $compressed_data = Bio::EnsEMBL::Compara::Utils::Compress::compress_to_mysql($data);

    my $sql = 'REPLACE INTO gene_tree_object_store VALUES (?,?,?)';
    my $sth = $self->prepare($sql);
    my $rv = $sth->execute(ref($gene_tree) ? $gene_tree->root_id() : $gene_tree, $label, $compressed_data);
    $sth->finish();

    return $rv;
}


1;
