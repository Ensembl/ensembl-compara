=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -member_type ncrna -clusterset_id murinae

=head1 DESCRIPTION

Pipeline to dump all the gene-trees and homologies under #base_dir#.

By default, the pipeline dumps the database named "compara_curr" in the
registry, but a different database can be selected with --rel_db.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');   # we don't need Compara tables in this particular case

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.

=cut

sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        ## Commented out to make sure people define it on the command line
        # either 'protein' or 'ncrna'
        #'member_type'       => 'protein',
        # either 'default' or 'murinae'
        #'clusterset_id'     => 'default',

        'pipeline_name'       => $self->o('member_type').'_'.$self->o('clusterset_id').'_'.$self->o('division').'_'.$self->default_pipeline_name().'_'.$self->o('rel_with_suffix'),
        'rel_db'        => 'compara_curr',

        'dump_trees_capacity' => 100,   # how many trees can be dumped in parallel
        'dump_hom_capacity'   => 10,    # how many homologies can be dumped in parallel
        'dump_per_genome_cap' => 50,
        'batch_size'          => 25,    # how may trees' dumping jobs can be batched together

        'max_files_per_tar'     => 500,

        'readme_dir'  => $self->check_dir_in_ensembl('ensembl-compara/docs/ftp'),                                      # where the template README files are

        'base_dir'    => $self->o('pipeline_dir'),                                                                      # where the final dumps will be stored
        'tree_hash_dir' => '#base_dir#/dump_hash/#division#_#basename#/trees',                                          # where directory hash is created and maintained
        'mlss_hash_dir' => '#base_dir#/dump_hash/#division#_#basename#/mlsses',
        'target_dir'  => '#base_dir#/#division#',                                                                       # where the dumps are put (all within subdirectories)
        'xml_dir'     => '#target_dir#/xml/ensembl-compara/homologies/',                                                # where the XML dumps are put
        'emf_dir'     => '#target_dir#/emf/ensembl-compara/homologies/',                                                # where the EMF dumps are put
        'tsv_dir'     => '#target_dir#/tsv/ensembl-compara/homologies/',                                                # where the TSV dumps are put

        'uniprot_file' => 'GeneTree_content.#clusterset_id#.e#curr_release#.txt',
    };
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'base_dir'      => $self->o('base_dir'),
        'target_dir'    => $self->o('target_dir'),
        'tree_hash_dir' => $self->o('tree_hash_dir'),
        'mlss_hash_dir' => $self->o('mlss_hash_dir'),
        'xml_dir'       => $self->o('xml_dir'),
        'emf_dir'       => $self->o('emf_dir'),
        'tsv_dir'       => $self->o('tsv_dir'),
        'division'      => $self->o('division'),

        'basename'      => '#member_type#_#clusterset_id#',
        'name_root'     => 'Compara.'.$self->o('rel_with_suffix').'.#basename#',

        'rel_db'        => $self->o('rel_db'),

        'reg_conf'      => $self->o('reg_conf'),
        'dump_trees_capacity' => $self->o('dump_trees_capacity'),
        'dump_hom_capacity'   => $self->o('dump_hom_capacity'  ),
        'dump_per_genome_cap' => $self->o('dump_per_genome_cap'),
        'uniprot_file'        => $self->o('uniprot_file'),
    };
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},
    };
}


=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines seven analyses:

                    * 'create_dump_jobs'   generates a list of tree_ids to be dumped

                    * 'dump_a_tree'         dumps one tree in multiple formats

                    * 'generate_collations' generates five jobs that will be merging the hashed single trees

                    * 'collate_dumps'       actually merge/collate single trees into long dumps

                    * 'archive_long_files'  zip the long dumps

                    * 'md5sum_tree'         compute md5sum for compressed files


=cut

sub pipeline_analyses {
    my ($self) = @_;

    my $pa = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees::pipeline_analyses_dump_trees($self);

    # dump_trees_pipeline_start
    $pa->[0]->{'-input_ids'} = [{}];

    # collection_factory
    $pa->[2]->{'-parameters'} = {
        'column_names'      => [ 'clusterset_id', 'member_type' ],
        'inputlist'         => [ [$self->o('clusterset_id'), $self->o('member_type')] ],
    };

    return $pa;
}

1;
