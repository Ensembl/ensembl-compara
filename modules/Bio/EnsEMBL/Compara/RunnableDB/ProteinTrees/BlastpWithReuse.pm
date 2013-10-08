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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse

=head1 SYNOPSIS


=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run ncbi_blastp and parse the output into
PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara database
Supported keys:

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF');


sub get_queries {
    my $self = shift @_;

    my $start_member_id = $self->param_required('start_member_id');
    my $end_member_id   = $self->param_required('end_member_id');
    my $genome_db_id    = $self->param_required('genome_db_id');

    #Get list of members and sequences
    return $self->compara_dba->get_MemberAdaptor->generic_fetch("mg.genome_db_id=$genome_db_id AND m.member_id BETWEEN $start_member_id AND $end_member_id", [[['member', 'mg'], 'mg.canonical_member_id = m.member_id']]);
}


1;
