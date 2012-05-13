=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor

=head1 DESCRIPTION

Specialization of Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor for proteins.

Please refer to Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor for the documentation
on the methods. The trees fetched by the ProteinTreeAdaptor are restricted to
protein-coding genes, but the methods are the same as in the GeneTreeNodeAdaptor.

Similarly, you can use the NCTreeAdaptor to fetch trees for ncRNA genes or the
GeneTreeAdaptor to fetch trees for all types of genes.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor;

use strict;

use base ('Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor');


sub _default_where_clause {
    return "t.root_id = tr.root_id AND tr.member_type = 'protein'";
}

sub _default_member_type {
    return 'protein';
}


1;
