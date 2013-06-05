=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor

=head1 DESCRIPTION

This adaptor extends the Compara BaseAdaptor and adds convenient
methods to build a full cache of the data

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor;

use strict;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 _id_cache

  Description: Overwritten from Bio::EnsEMBL::DBSQL::BaseAdaptor.
               [Meaning changed]: Now returns the hash by itself,
               instead of an instance of BaseCache
  Caller     : Bio::EnsEMBL::DBSQL::BaseAdaptor

=cut

sub _id_cache {
    my $self = shift;

    $self->_build_id_cache unless exists $self->{_id_cache};
    return $self->{_id_cache};
}


=head2 _build_id_cache

  Description: Overwritten from Bio::EnsEMBL::DBSQL::BaseAdaptor.
               Returns a new instance of a FullIdCache.
  Caller     : Bio::EnsEMBL::DBSQL::BaseAdaptor

=cut

sub _build_id_cache {
    my $self = shift;

    my %cache;
    my $objs = $self->generic_fetch();
    foreach my $obj (@{$objs}) {
        $cache{$obj->dbID()} = $obj;
    }
    $self->{_id_cache} = \%cache;

    # If there are tags, load them all
    if ($self->isa('Bio::EnsEMBL::Compara::DBSQL::TagAdaptor')) {
        $self->_load_tagvalues_multiple(-ALL_OBJECTS => 1, @{$objs});
    }

    return \%cache;
}


=head2 fetch_by_dbID

  Description: Returns the object identified by its dbID
  Caller     : general

=cut

sub fetch_by_dbID {
    my $self = shift;
    my $id = shift;
    return $self->_id_cache->{$id};
}


sub fetch_all_by_dbID_list {
    my $self = shift;
    my $id_list = shift;
    my $_id_cache = $self->_id_cache;
    return [map {$_id_cache->{$_}} @{$id_list}];
}

=head2 fetch_all

  Description: Returns all the objects stored in the cache
  Caller     : general

=cut

sub fetch_all {
    my ($self) = @_;

    return [ values %{ $self->_id_cache() } ];
}


=head2 _add_to_cache

  Description: Adds the entry to the cache
  Caller     : Any derived adaptor (usually, its store() method)

=cut

sub _add_to_cache {
    my ($self, $object) = @_;

    $self->_id_cache->{$object->dbID()} = $object;
}


=head2 _remove_from_cache

  Description: Removes an entry from the cache
  Caller     : Any derived adaptor (usually, its delete() method)

=cut

sub _remove_from_cache {
    my ($self, $object) = @_;

    if (ref($object)) {
        delete $self->_id_cache->{$object->dbID()};
    } else {
        delete $self->_id_cache->{$object};
    }
}


=head2 _fetch_cached_by_sql

  Description: Executes a query that is supposed to return dbIDs,
               and get the corresponding objects from the cache
  Caller:    : Any derived adaptor

=cut

sub _fetch_cached_by_sql {
    my ($self, $sql, @args) = @_;

    my $sth = $self->execute($sql);
    $sth->execute(@args);
    my @dbid_list = map {$_->[0]} @{$sth->fetchall_arrayref};
    $sth->finish;
    return $self->fetch_all_by_dbID_list(\@dbid_list);
}


1;

