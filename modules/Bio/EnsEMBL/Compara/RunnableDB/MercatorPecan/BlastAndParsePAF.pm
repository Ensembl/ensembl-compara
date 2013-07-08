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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF

=head1 SYNOPSIS


=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run ncbi_blastp and parse the output into
PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara database
Supported keys:
    'genome_db_id' => <number>
        Species genome db id.
    'start_member_id' => <number>
        Member id of the first member to blast. Obligatory
    'end_member_id' => <number>
        Member id of the last member to blast. Obligatory


=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF');

use Bio::EnsEMBL::Utils::Exception qw(throw warning info);


sub param_defaults {
    my $self = shift;
    return {
            %{$self->SUPER::param_defaults},
            'no_cigars' => 1,
    };
}


#
# Fetch members and sequences from the database.
# Return a sorted list based on start_member_id and end_member_id
#
sub get_queries {
    my ($self) = @_;

    my $start_member_id = $self->param_required('start_member_id');
    my $end_member_id   = $self->param_required('end_member_id');

    my $idprefixed      = $self->param('idprefixed')  || 0;
    my $debug           = $self->debug() || $self->param('debug') || 0;
    my $genome_db_id    = $self->param('genome_db_id');

    #Get list of members and sequences
    return $self->compara_dba->get_MemberAdaptor->generic_fetch("genome_db_id=$genome_db_id AND member_id BETWEEN $start_member_id AND $end_member_id");
}


1;

