=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('PeptideMemberGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory();
$rdb->fetch_input;
$rdb->run;

=cut

=head1 DESCRIPTION

Given a list of genomedb_ids dataflows a fan of jobs with ENSEMBLPEP member_ids.
One job will contain 20 or less member_ids belonging to the same genome_db_id.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'group_size'        => 20,
        'species_set'       => [],
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id');
    my $species_set = ($genome_db_id ? [ $genome_db_id ] : $self->param('species_set'))
        or die "Either 'species_set' list or 'genome_db_id' parameter has to be defined";

    my $seq_member_adaptor   = $self->compara_dba->get_SeqMemberAdaptor;

    my @member_ids = ();
    foreach my $gdb_id (@$species_set) {
        foreach my $member (@{$seq_member_adaptor->fetch_all_by_source_genome_db_id('ENSEMBLPEP', $gdb_id)}) {
            push @member_ids, $member->member_id;
        }
    }

    $self->param('inputlist', \@member_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');
    my $group_size = $self->param('group_size');

    while (@$inputlist) {
        my @job_array = splice(@$inputlist, 0, $group_size);
        $self->dataflow_output_id( { 'ids' => [@job_array] }, 2);
    }
}


1;
