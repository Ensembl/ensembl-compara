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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory 

=head1 SYNOPSIS


=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported keys:

   'genome_db_id' => <number>
       Genome_db id. Obligatory

   'step' => <number>
       How many sequences to write into the blast query file. Default 100

   'species_set_id' => <number> (optionnal)
       The species set on which we want to run blast for that genome_db_id
       Default: uses all the GenomeDBs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'step'  => 100,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $species_set_id = $self->param('species_set_id');
    my $target_genome_dbs = $species_set_id ? $self->compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs : $self->compara_dba->get_GenomeDBAdaptor->fetch_all;
    $self->param('target_genome_dbs', $target_genome_dbs);

    my $all_canonical = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_source_genome_db_id('ENSEMBLPEP', $genome_db_id);
    $self->param('query_members', $all_canonical);
}


sub write_output {
    my $self = shift @_;

    my $step = $self->param('step');
    my @member_id_list = map {$_->dbID} @{$self->param('query_members')};
    my @target_genome_db_ids = sort {$a <=> $b} (map {$_->dbID} @{$self->param('target_genome_dbs')});

    while (@member_id_list) {
        my @job_array = splice(@member_id_list, 0, $step);
        foreach my $target_genome_db_id (@target_genome_db_ids) {
            my $output_id = {'genome_db_id' => $self->param('genome_db_id'), 'start_member_id' => $job_array[0], 'end_member_id' => $job_array[-1], 'target_genome_db_id' => $target_genome_db_id};
            $self->dataflow_output_id($output_id, 2);
        }
    }
}

1;
