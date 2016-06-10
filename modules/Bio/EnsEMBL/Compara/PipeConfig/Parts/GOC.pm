=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC

=head1 DESCRIPTION

This file contains the main parts needed to run GOC in a pipeline.
It is used to form the main GOC pipeline, but is also embedded in
the ProteinTrees and NcRNATrees pipelines

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::GOC;


use strict;
use warnings;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  

sub pipeline_analyses_goc {
    my ($self) = @_;
    return [
        {   -logic_name => 'get_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory',
#            -input_ids => [ { } ],
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
            -flow_into => {
                '2->A' => [ 'create_ordered_chr_based_job_arrays' ],
                'A->1' => [ 'get_max_orth_percent' ],       
            },
            -rc_name => '2Gb_job',
            -hive_capacity  =>  200,
        },

#        {  -logic_name => 'prepare_orthologs',
#            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM_new::Prepare_Orthologs',
#            -flow_into  =>  {
#                2   =>  [ 'create_ordered_chr_based_job_arrays' ],
#            },
#            -rc_name => '2Gb_job',
#        },

        {   -logic_name =>  'create_ordered_chr_based_job_arrays',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs',
            -flow_into  =>  {
                2   =>  ['check_ortholog_neighbors'],
            },
            -rc_name => '2Gb_job',
            -hive_capacity  =>  200,
        },

        {
            -logic_name =>  'check_ortholog_neighbors',
            -module =>  'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs',
#            -input_ids => [ {'species1' => $self->o('species1')} ],
#            -parameters     => {'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82'},
            -flow_into  => {
#                2 => [ $self->o('compara_db').'/ortholog_goc_metric' ],
               2 => [ ':////ortholog_goc_metric' ],
            },
            -hive_capacity  =>  200,

 #           -rc_name => '2Gb_job',
        },

        {
            -logic_name => 'get_max_orth_percent',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score',
            -flow_into => {
                1 => { 'get_genetic_distance' => INPUT_PLUS },
            },
            -rc_name => '16Gb_job',
        },

        {
            -logic_name => 'get_genetic_distance',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance',
            -flow_into => {
                1 =>    ['threshold_calculator'],
                },
        },

        {
            -logic_name => 'threshold_calculator',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold',
            -flow_into => {
                1 =>    ['get_perc_above_threshold'],
                },
        },

        {
            -logic_name => 'get_perc_above_threshold',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold',
            -flow_into => {
                1 =>    ['store_goc_dist_asTags'],
                },
        },

        {
            -logic_name => 'store_goc_dist_asTags',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags',
#            -parameters => {'compara_db' => $self->o('compara_db') },
        },

        
    ];
}

1;