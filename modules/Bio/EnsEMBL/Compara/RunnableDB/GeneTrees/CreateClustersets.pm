=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited. All rights reserved.

  This software is distributed under a modified Apache License.
  For license details, please see

    http://www.ensembl.org/info/about/code_license.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets

=head1 DESCRIPTION

This Analysis/Runnable is designed to store additional geneTree clustersets
That will be needed by the rest of the pipeline

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded by an underscore (_).

=cut 

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub run {
    my ($self) = @_;

    $self->create_additional_clustersets();
}

1;
