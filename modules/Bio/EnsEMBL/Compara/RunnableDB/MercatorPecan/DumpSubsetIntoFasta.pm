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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpSubetIntoFasta 

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a Compara-specific module that dumps the sequences related to
a given genome_db_id into a file in Fasta format.

Supported keys:
    'genome_db_id' => <number>
        The id of the genome. Obligatory

     'fasta_dir' => <directory_path>
        Location to write fasta file

     'reuse_this' => <0|1>
        Whether to reuse this genome_db. Needed to flow into blast_factory

=cut


package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpSubsetIntoFasta;

use strict;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id') or die "'genome_db_id' is an obligatory parameter";

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "cannot fetch GenomeDB with id '$genome_db_id'";

    my $fasta_file = $self->param('fasta_dir') . '/' . $genome_db->name() . '_' . $genome_db->assembly() . '.fasta';
    $fasta_file =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fasta_file =~ s/\/\//\//g;  # converts any // in path to /
    $self->param('fasta_file', $fasta_file);
    $self->param('genome_db_id', $genome_db_id);

    # write fasta file:
    my $members   = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_source_genome_db_id('ENSEMBLPEP', $genome_db_id);
    Bio::EnsEMBL::Compara::MemberSet->new(-members => $members)->print_sequences_to_fasta($fasta_file, 1);
}


sub write_output {  
    my $self = shift @_;

    #Flow into make_blastdb
    $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file'), 'genome_db_id' => $self->param('genome_db_id') } , 2);

    #Flow into blast_factory
    $self->dataflow_output_id( { 'fasta_name' => $self->param('fasta_file'), 'genome_db_id' => $self->param('genome_db_id'), 'reuse_this' => $self->param('reuse_this') } , 1);

}

1;

