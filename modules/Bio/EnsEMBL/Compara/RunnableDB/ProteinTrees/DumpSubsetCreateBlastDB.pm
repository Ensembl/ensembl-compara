=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::DumpSubsetCreateBlastDB

=head1 DESCRIPTION

This is a Compara-specific module that dumps the sequences of a genome_db_id
into a file in Fasta format and creates a Blastp database from this file.
It is used by GeneTrees pipeline.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::DumpSubsetCreateBlastDB;

use strict;

use Bio::EnsEMBL::Compara::MemberSet;

use Bio::EnsEMBL::Analysis::Tools::BlastDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id') or die "'genome_db_id' is an obligatory parameter";

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "cannot fetch GenomeDB with id '$genome_db_id'";

    my $members   = $self->compara_dba->get_MemberAdaptor->fetch_all_canonical_by_source_genome_db_id('ENSEMBLPEP', $genome_db_id);

    my $fasta_file = $self->param('fasta_dir') . '/' . $genome_db->name() . '_' . $genome_db->assembly() . '.fasta';
    $fasta_file =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fasta_file =~ s/\/\//\//g;  # converts any // in path to /
    $self->param('fasta_file', $fasta_file);

    Bio::EnsEMBL::Compara::MemberSet->new(-members => $members)->print_sequences_to_fasta($fasta_file, 1);
}


sub run {
    my $self = shift @_;

    my $fasta_file = $self->param('fasta_file');

        # configure the fasta file for use as a blast database file:
    my $blastdb        = Bio::EnsEMBL::Analysis::Tools::BlastDB->new(
        -sequence_file => $fasta_file,
        -mol_type => 'PROTEIN'
    );
    $blastdb->create_blastdb;
}

1;

