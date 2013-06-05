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
methods to use the FullIdCache from Core.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor;

use strict;

use Bio::EnsEMBL::DBSQL::Support::FullIdCache;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 ignore_cache_override

  Description: Overwritten from Bio::EnsEMBL::DBSQL::BaseAdaptor.
               Returns 1 to force caching even, if the NO_CACHE
               directive is given.
  Caller     : Bio::EnsEMBL::DBSQL::BaseAdaptor

=cut

sub ignore_cache_override {
    return 1;
}


=head2 _build_id_cache

  Description: Overwritten from Bio::EnsEMBL::DBSQL::BaseAdaptor.
               Returns a new instance of a FullIdCache.
  Caller     : Bio::EnsEMBL::DBSQL::BaseAdaptor

=cut

sub _build_id_cache {
    my $self = shift;
    my $cache = Bio::EnsEMBL::DBSQL::Support::FullIdCache->new($self);

    # If there are tags, load them all
    if ($self->isa('Bio::EnsEMBL::Compara::DBSQL::TagAdaptor')) {
        $self->_load_tagvalues_multiple(-ALL_OBJECTS => 1, values %{$cache->cache});
    }
    return $cache;
}


=head2 fetch_all

  Description: Returns all the objects stored in the cache
  Caller     : general

=cut

sub fetch_all {
    my ($self) = @_;

    return [ values %{ $self->_id_cache->cache } ];
}


=head2 _add_to_cache

  Description: Adds the entry to the cache
  Caller     : Any derived adaptor (usually, its store() method)

=cut

sub _add_to_cache {
    my ($self, $object) = @_;

    $self->_id_cache->cache->{$object->dbID()} = $object;
}


=head2 _remove_from_cache

  Description: Removes an entry from the cache
  Caller     : Any derived adaptor (usually, its delete() method)

=cut

sub _remove_from_cache {
    my ($self, $object) = @_;

    if (ref($object)) {
        delete $self->_id_cache->cache->{$object->dbID()};
    } else {
        delete $self->_id_cache->cache->{$object};
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

