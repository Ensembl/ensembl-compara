=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Example::ParasiteProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. make sure that all default_options are set correctly

    #3. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::ParasiteProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #4. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

The PipeConfig example file for the Parasite genomics team's version of ProteinTrees pipeline

=head1 CONTACT

Please contact Compara or the Parasite genomics team with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::ParasiteProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
        #'mlss_id'               => 40077,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #'ensembl_release'       => 68,      # it defaults to Bio::EnsEMBL::ApiVersion::software_version(): you're unlikely to change the value
        'do_not_reuse_list'     => [ ],     # names of species we don't want to reuse this time

    # custom pipeline name, in case you don't like the default one
        'division'              => undef,       # Tag attached to every single tree (e.g. helminth, strongyloides, etc)

    # dependent parameters: updating 'work_dir' should be enough
        'work_dir'              => '/lustre/scratch108/parasites/'.$self->o('ENV', 'USER').'/Ensembl_builds/Compara/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),

    # blast parameters:

    # clustering parameters:
        #'outgroups'                     => {'amphimedon_queenslandica' => 2, 'trichoplax_adhaerens' => 2, 'nematostella_vectensis' => 2},      # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => {},

    # tree building parameters:
        # you can define your own species_tree for 'njtree_phyml' and 'ortho_tree'
        'species_tree_input_file'   => $self->o('ensembl_cvs_root_dir').'/ensembl-other/scripts/species_tree',
 
    # homology_dnds parameters:
        'taxlevels'                 => [],
        'filter_high_coverage'      => 0,

    # mapping parameters:

    # executable locations:

    # HMM specific parameters

    # hive_capacity values for some analyses:

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # the production database itself (will be created)
        'pipeline_db' => {
            -host   => 'mcs15',
            -port   => 3378,
            -user   => 'wormadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_homology_'.$self->o('ensembl_release'),
            -driver => 'mysql',
        },
 
        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://wormro@mcs15:3378/es9_compara_master',
        'ncbi_db' => 'mysql://wormro@mcs15:3378/es9_ncbi_taxonomy_74',

        # Ensembl-specific database, location of core databases
        'ensembl-core' => {
            -host   => 'ensembldb.ensembl.org',
            -port   => 5306,
            -user   => 'anonymous',
        },
        # Ensembl Genome core database, location of core EG-metazoan databases
        'EG-core' => {
            -host   => 'mysql.ebi.ac.uk',
            -port   => 4157,
            -user   => 'anonymous',
        },
        # 50HG core database, location of core helminth databases
        '50HG-core' => {
            -host   => 'mcs15',
            -port   => 3378,
            -user   => 'wormro',
        },

 
        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ $self->o('ensembl-core'), $self->o('EG-core'), $self->o('50HG-core') ],
        'curr_core_registry'        => undef,
        'curr_file_sources_locs'    => [ $self->o('ensembl_cvs_root_dir').'/ensembl-other/scripts/fasta_spp.json' ],    # It can be a list of JSON files defining an additionnal set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [],

        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 0,

    };
}

1;

