=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE

=head1 DESCRIPTION

This file contains the main parts needed to run CAFE in a pipeline.
It is used to form the main CAFE pipeline, but is also embedded in
the ProteinTrees and NcRNATrees pipelines

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::CAFE;

use strict;
use warnings;

sub pipeline_analyses_cafe_with_full_species_tree {
    my ($self) = @_;
    return [
            {
             -logic_name => 'make_full_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
             -parameters => {
                             'label'    => $self->o('full_species_tree_label'),
                            },
             -flow_into  => {
                             2 => [ 'hc_full_species_tree' ],
                            },
            },

        {   -logic_name         => 'hc_full_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 0,
                n_missing_species_in_tree   => 0,
            },
            -flow_into          => [ 'CAFE_species_tree' ],
        },
        @{pipeline_analyses_cafe($self)},
    ]
}


sub pipeline_analyses_cafe {
    my ($self) = @_;
    return [
            {
             -logic_name => 'CAFE_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree',
             -parameters => {
                             'cafe_species' => $self->o('cafe_species'),
                             'label'        => $self->o('full_species_tree_label')
                            },
             -rc_name => '16Gb_job',
             -flow_into     => {
                 2 => [ 'hc_cafe_species_tree' ],
             }
            },

        {   -logic_name         => 'hc_cafe_species_tree',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'species_tree',
                binary          => 1,
            },
            -flow_into          => [ 'CAFE_table' ],
        },

#            {
#             -logic_name => 'BadiRate',
#             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::BadiRate',
#             -parameters => {
#                             'species_tree_meta_key' => $self->o('species_tree_meta_key'),
#                             'badiRate_exe'          => $self->o('badiRate_exe'),
#                            }
#            },

            {
             -logic_name => 'CAFE_table',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable',
             -parameters => {
                             'perFamTable'  => $self->o('per_family_table'),
                             'cafe_shell'   => $self->o('cafe_shell'),
                            },
             -rc_name => '4Gb_job',
             -meadow_type => 'LSF',
             -flow_into => {
                 '2->A' => [ 'CAFE_analysis' ],
                 'A->1' => [ 'hc_cafe_results' ],
             },
            },

            {
             -logic_name => 'CAFE_analysis',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis',
             -parameters => {
#                             'cafe_lambdas'         => $self->o('cafe_lambdas'),
#                             'cafe_struct_taxons'  => $self->o('cafe_'),
                             'cafe_struct_tree_str' => $self->o('cafe_struct_tree_str'),
                             'cafe_shell'           => $self->o('cafe_shell'),
                            },
             -rc_name => '1Gb_job',
             -hive_capacity => $self->o('cafe_capacity'),
             -meadow_type => 'LSF',
             -flow_into => {
                 2 => 'CAFE_json',
             },
            },

        {   -logic_name    => 'CAFE_json',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeCAFE',
            -hive_capacity => $self->o('cafe_capacity'),
            -batch_size    => 20,
            -rc_name       => '1Gb_job',
        },

        {   -logic_name         => 'hc_cafe_results',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'cafe',
                cafe_tree_label => 'cafe',
            },
        },

           ]
}

1;
