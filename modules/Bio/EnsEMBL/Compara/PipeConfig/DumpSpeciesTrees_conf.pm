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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf -compara_url <url_of_the_compara_db>

=head1 DESCRIPTION  

Dumps all the species-trees from the database

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        #'compara_url'      => 'mysql://ensro@compara4:3306/mp14_epo_17mammals_80',

        #Connection parameters for production database (the rest is defined in the base class)
        'host'              => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        'port'              => 4485,

        #Locations to write output files
        'dump_dir'          => '/hps/nobackup/production/ensembl/'. $ENV{USER} . '/' . $self->o('pipeline_name'),

        # Script to dump a tree
        'dump_species_tree_exe'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/examples/species_getSpeciesTree.pl',
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'dump_dir'      => $self->o('dump_dir'),
        'compara_url'   => $self->o('compara_url'),
        'dump_species_tree_exe' => $self->o('dump_species_tree_exe'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'mk_dump_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'           => ['mkdir', '-p', '#dump_dir#'],
            },
            -input_ids  => [{ }],
            -flow_into  => 'dump_factory',
        },

        {   -logic_name => 'dump_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'       => '#compara_url#',
                'inputquery'    => 'SELECT method_link_species_set_id, label, method_link_id, replace(name, " ", "_") as name FROM species_tree_root JOIN method_link_species_set USING (method_link_species_set_id)',
            },
            -flow_into => {
                2 => WHEN( '((#method_link_id# eq "401") || (#method_link_id# eq "402")) && (#label# ne "cafe")' => {'dump_one_tree_without_distances' => INPUT_PLUS() },
                           ELSE { 'dump_one_tree_with_distances' => INPUT_PLUS() },
                ),
            },
        },

        {   -logic_name => 'dump_one_tree_with_distances',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'           => '#dump_species_tree_exe# -url #compara_url# -mlss_id #method_link_species_set_id# -label "#label#" -with_distances > "#dump_dir#/#name#_#label#.nh"',
            },
            -flow_into  => [ 'sanitize_file' ],
        },

        {   -logic_name => 'dump_one_tree_without_distances',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'           => '#dump_species_tree_exe# -url #compara_url# -mlss_id #method_link_species_set_id# -label "#label#" > "#dump_dir#/#name#_#label#.nh"',
            },
            -flow_into  => [ 'sanitize_file' ],
        },

        {   -logic_name => 'sanitize_file',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'           => 'cd "#dump_dir#"; sed -i "s/:0;/;/" "#name#_#label#.nh"; sed -i "s/  */_/g" "#name#_#label#.nh"',
            },
        },
    ];
}
1;
