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
    $cache->build_cache();
    return $cache;
}


=head2 _full_cache

  Description: Returns the previously-created instance of FullIdCache.
  Caller     : Any derived adaptor

=cut

sub _full_cache {
    my $self = shift;
    return $self->_id_cache->cache;
}

1;

