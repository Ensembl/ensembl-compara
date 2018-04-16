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

Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf -host compara1 -member_type ncrna -clusterset_id murinae

    By default the pipeline dumps the database named "compara_curr" in the registry, but a different database can be given:
    -production_registry /path/to/reg_conf.pl -rel_db compara_db_name

=head1 DESCRIPTION

    This pipeline dumps all the gene-trees and homologies under #base_dir#

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

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

        # Can be "ensembl", "plants", etc
        'division'    => 'ensembl',

        # Standard registry file
        'pipeline_name'       => 'dump_trees_'.$self->o('member_type').'_'.$self->o('clusterset_id').'_'.$self->o('rel_with_suffix'),
        'production_registry' => "--reg_conf ".$self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl",
        'rel_db'        => 'compara_curr',

        'capacity'    => 100,                                                       # how many trees can be dumped in parallel
        'batch_size'  => 25,                                                        # how may trees' dumping jobs can be batched together

        'dump_per_species_tsv'  => 0,
        'max_files_per_tar'     => 500,

        'xmllint_exe' => $self->check_exe_in_linuxbrew_opt('libxml2/bin/xmllint'),

        'dump_script' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl',           # script to dump 1 tree
        'readme_dir'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/docs/ftp',                                  # where the template README files are

        'base_dir'    => '/hps/nobackup2/production/ensembl/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),     # where the final dumps will be stored
        'work_dir'    => '#base_dir#/dump_hash/#basename#',                                                             # where directory hash is created and maintained
        'target_dir'  => '#base_dir#/#division#',                                                                       # where the dumps are put (all within subdirectories)
        'xml_dir'     => '#target_dir#/xml/ensembl-compara/homologies/',                                                # where the XML dumps are put
        'emf_dir'     => '#target_dir#/emf/ensembl-compara/homologies/',                                                # where the EMF dumps are put
        'tsv_dir'     => '#target_dir#/tsv/ensembl-compara/homologies/',                                                # where the TSV dumps are put
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         'default'      => {'LSF' => [ '', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ]  },
         '1Gb_job'      => {'LSF' => [ '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ] },
         '2Gb_job'      => {'LSF' => [ '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ] },
         '4Gb_job'      => {'LSF' => [ '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ] },
         '10Gb_job'      => {'LSF' => [ '-C0 -M10000  -R"select[mem>10000]  rusage[mem=10000]"', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ] },
    };
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'base_dir'      => $self->o('base_dir'),
        'target_dir'    => $self->o('target_dir'),
        'work_dir'      => $self->o('work_dir'),
        'xml_dir'       => $self->o('xml_dir'),
        'emf_dir'       => $self->o('emf_dir'),
        'tsv_dir'       => $self->o('tsv_dir'),
        'division'      => $self->o('division'),

        'basename'      => '#member_type#_#clusterset_id#',
        'name_root'     => 'Compara.'.$self->o('rel_with_suffix').'.#basename#',

        'dump_per_species_tsv'  => $self->o('dump_per_species_tsv'),

        'rel_db'        => $self->o('rel_db'),
    };
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
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
    $pa->[0]->{'-input_ids'} = [{}];  
    $pa->[1]->{'-parameters'} = {
        'column_names'      => [ 'clusterset_id', 'member_type' ],
        'inputlist'         => [ [$self->o('clusterset_id'), $self->o('member_type')] ],
    };
    return $pa;
}

1;

