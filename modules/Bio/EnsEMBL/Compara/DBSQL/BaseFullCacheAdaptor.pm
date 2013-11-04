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

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


# We want to force the cache
sub ignore_cache_override {
    return 1;
}


=head2 fetch_all

  Description: Returns all the objects from this adaptor
  Returntype : arrayref of objects
  Caller     : general

=cut

sub fetch_all {
    my ($self) = @_;

    return [$self->_id_cache->cached_values()];
}



1;

