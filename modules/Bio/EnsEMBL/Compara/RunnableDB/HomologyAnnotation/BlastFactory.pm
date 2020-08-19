=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory 

=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported parameters:

    'species_set_id' => <number>

    'step'           => <number>
        How many sequences to write into the blast query file.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
    };
}


sub fetch_input {
    my $self = shift @_;

    my $species_set_id = $self->param_required('species_set_id');
    my $species_set    = $self->compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id);
    my $genome_dbs     = $species_set->genome_dbs;

    my @all_members;
    my @genome_db_ids;

    foreach my $genome_db (@$genome_dbs) {
        my $genome_db_id = $genome_db->dbID;
        push @genome_db_ids, $genome_db_id;
        my $some_members = $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_representative_for_blast_by_genome_db_id($genome_db_id);
        foreach my $member (@$some_members) {
            my $member_id = $member->dbID;
            push @all_members, $member_id;
        }
    }

    $self->param('query_members', \@all_members);
    $self->param('genome_db_ids', \@genome_db_ids);
}

sub write_output {
    my $self = shift @_;

    my $step              = $self->param('step');
    my @query_member_list = @{$self->param('query_members')};

    while (@query_member_list) {
        my @job_array = splice(@query_member_list, 0, $step);
        my $output_id = { 'member_id_list' => \@job_array };
        #my $output_id = { 'start_member_id' => $job_array[0], 'end_member_id' => $job_array[-1] };
        $self->dataflow_output_id($output_id, 2);
    }
    $self->dataflow_output_id( { 'genome_db_ids' => $self->param_required('genome_db_ids') }, 1 );
}

1;
