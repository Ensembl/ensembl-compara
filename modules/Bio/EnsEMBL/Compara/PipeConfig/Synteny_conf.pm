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

Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf

=head1 DESCRIPTION

This pipeline is using eHive's parameter-stack mechanism, i.e. the jobs
inherit the parameters of their parents.
The pipeline should be configured exclusively from the command line, with the
--alignment_db/ptree_db and possibly -pairwise_mlss_id/ortholog_mlss_id parameters. If the latter is
skipped, the pipeline will use all the pairwise alignments/orthologs found on the server.
The pipeline automatically finds the alignments/orthologs that are missing syntenies and
compute these (incl. the stats)
The analysis "compute_synteny_start" can be seeded multiple times.
Extra parameters like "level", "orient", "minSize1", etc, should also be given
at the command-line level, and not in this file.

Example: init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf  -pipeline_name <> -ptree_db/alignment_db <> -registry <>

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
            %{$self->SUPER::default_options},   # inherit the generic ones
            
            # run in top-up mode by default
            'recompute_existing_syntenies' => 0,

            # Connection to the alignment database must be given
            #'alignment_db' => undef,    # alignment database to calculate the syntenies from
            'ptree_db'     => undef,     # protein database to calculate the syntenies from
            'ortholog_method_link_types'  => ['ENSEMBL_ORTHOLOGUES'],
            #'registry' => undef,        # needed to find the core databases (and also if "alignment_db" is a registry name (a division name, for instance))

            # Used to restrict the pipeline to 1 mlss_id
            'pairwise_mlss_id'  => undef,   # if undef, will use all the pairwise alignments found in the alignment db
            'ortholog_mlss_id' => undef,  # if undef, will use all the orthologs found in the ptree db
            #DumpGFFAlignmentsForSynteny parameters
            'dumpgff_capacity'  => 3,
            'include_non_karyotype' => 0, #over-ride check for has_karyotype in ListChromosomes and DumpGFFAlignmentsForSynteny
            'level' => 1, #which GenomicAlignBlock level_id to use. Level=>1 will only use level 1 blocks, level=>2 will use level 1 and level 2 blocks. For human vs chimp, we would use level=>2

            #BuildSynteny parameters
            'maxDist1' => 100000,  #maximum gap allowed between alignments within a syntenic block
            'minSize1' => 100000,  #minimum length a syntenic block must have, shorter blocks are discarded
            'maxDist2' => undef,
            'minSize2' => undef,

            'orient' => 'false', # "false" is only needed for human/mouse, human/rat and mouse/rat NOT for elegans/briggsae (it can be ommitted). 

            #Final filtering on the genome coverage (to remove too sparse syntenies)
            'min_genome_coverage' => 0.05,  # minimum coverage. This parameter must be between 0 and 1

            #executable locations
            'DumpGFFAlignmentsForSynteny_exe' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl",
            'DumpGFFHomologuesForSynteny_exe' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/synteny/DumpGFFHomologuesForSynteny.pl",
            'BuildSynteny_exe' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/synteny/BuildSynteny.jar",

            'java_exe'      => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),

           };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
          'if [ -d '.$self->o('work_dir').' ]; then rm -r '.$self->o('work_dir'). '; fi', #remove old copy of dump dir
          'mkdir -p '.$self->o('work_dir'), #Make dump_dir directory
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'master_db'     => $self->o('master_db'),
        'alignment_db'    =>  $self->o('alignment_db'),
        'ptree_db'    =>  $self->o('ptree_db'),
            # 'synteny_mlss_id' will be evaluated in the runnables, not here
        'synteny_dir'   => $self->o('work_dir').'/#synteny_mlss_id#/',
        'ortholog_method_link_types' => $self->o('ortholog_method_link_types'),
        'maxDist1' => $self->o('maxDist1'),
        'minSize1' => $self->o('minSize1'),
        'maxDist2' => $self->o('maxDist2'),
        'minSize2' => $self->o('minSize2'),
        'orient'   => $self->o('orient'),
        'registry' => $self->o('registry'),
        'level'     => $self->o('level'),
        'include_non_karyotype' => $self->o('include_non_karyotype'),

        'min_genome_coverage'   => $self->o('min_genome_coverage'),
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub resource_classes {
    my ($self) = @_;
    
    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            '1.8Gb' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
            '3.6Gb' => { 'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

        {
          -logic_name => 'syntheny_pipeline_entry_pt',
          -module     =>  'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
          -input_ids   => [{'ortholog_mlss_id'    => $self->o('ortholog_mlss_id'),}],
          -flow_into  => {
            1   => WHEN('defined (#ptree_db#)' => ['compute_synteny_start_using_orthologs'] ,
                    ELSE ['compute_synteny_start_using_alignments']),
          },
        },

        {   -logic_name => 'compute_synteny_start_using_alignments',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::FetchSyntenyParametersAlignments',
            -parameters  => 
                {
                    'pairwise_mlss_id'    => $self->o('pairwise_mlss_id'),
                    'registry'          => $self->o('registry'),
                    'recompute_existing_syntenies' => $self->o('recompute_existing_syntenies'),
                },
            
            -wait_for   => [ 'copy_table', 'copy_table_factory' ],
            -flow_into  => {
                2 => 'create_work_dir',
            },
        },

        {   -logic_name => 'compute_synteny_start_using_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::FetchSyntenyParametersOrthologs',
            -wait_for   => [ 'copy_table', 'copy_table_factory' ],
            -flow_into  => {
                2 => 'create_work_dir',
            },
        },


        {   -logic_name => 'create_work_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'mkdir -p #synteny_dir#',
            },
            -flow_into  => [ 'copy_dnafrags_from_master' ],
        },


            { -logic_name => 'copy_dnafrags_from_master',
              -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
              -parameters    => {
                                 'src_db_conn'   => '#master_db#',
                                 'mode'          => 'insertignore',
                                 'table'         => 'dnafrag',
                                 'where'         => 'is_reference = 1 AND genome_db_id IN (#genome_db_ids#)'
                                },
              -flow_into => WHEN('defined (#ptree_db#)' => ['dump_gff_homologs'] ,
                    ELSE ['chr_name_factory']),
              -analysis_capacity => 50,
            },
            #dump chr names
            {   -logic_name => 'chr_name_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::ListChromosomes',
                -parameters => {
                                'species_name'          => '#ref_species#',
#                                'registry'              => $self->o('registry'),
                               },
                -flow_into => {
                               '2->A' =>  WHEN('defined(#ptree_db#)' => ['build_synteny'] ,
                                      ELSE ['dump_gff_alignments']),
                               'A->1' => [ 'concat_files' ],
                              },
              
            },

            #Dump gff homologs
            { -logic_name => 'dump_gff_homologs',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => {
                              'program'    => $self->o('DumpGFFHomologuesForSynteny_exe'),
                              'reg_conf_optional'   => '#expr( #registry# ? " --reg_conf ".#registry# : "" )expr#',
                              'cmd' => "#program# --dbname #ptree_db# --qy #ref_species# --tg #pseudo_non_ref_species# --include_non_karyotype 0 --output_dir #synteny_dir# #reg_conf_optional#",
                              },
                -flow_into => {
                               '1' => [ 'chr_name_factory' ],                               
                              },
              -analysis_capacity => $self->o('dumpgff_capacity'), #database intensive
              -rc_name => '1.8Gb',
            },


            #Dump gff alignments
            { -logic_name => 'dump_gff_alignments',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => {
                              'program'    => $self->o('DumpGFFAlignmentsForSynteny_exe'),
                              'reg_conf_optional'   => '#expr( #registry# ? " --reg_conf ".#registry# : "" )expr#',
                              'cmd' => "#program# --dbname #alignment_db# --qy #ref_species# --method_link_species_set #pairwise_mlss_id# --seq_region #seq_region_name# --force #include_non_karyotype# --level #level# --output_dir #synteny_dir# #reg_conf_optional#",
                              },
                -flow_into => {
                               '1' => [ 'build_synteny' ],
                              },
              -analysis_capacity => $self->o('dumpgff_capacity'), #database intensive
              -rc_name => '1.8Gb',
            },
            #Build synteny regions
            { -logic_name => 'build_synteny',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny',
              -parameters => {
                              'program' => $self->o('java_exe').' -Xmx1700M -classpath ' . $self->o('BuildSynteny_exe') . ' BuildSynteny',
                              'gff_file' => '#synteny_dir#/#seq_region_name#.syten.gff', #to agree with output of DumpGFFAlignmentsForSynteny.pl
                              'output_file' => '#synteny_dir#/#seq_region_name#.#maxDist1#.#minSize1#.BuildSynteny.out',
                              },
              -rc_name => '1.8Gb',
              -meadow_type  => 'LSF',   # The head nodes cannot run Java programs
              -flow_into => {
                  -1 => 'build_synteny_himem',
              },
            },
            { -logic_name => 'build_synteny_himem',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny',
              -parameters => {
                              'program' => $self->o('java_exe').' -Xmx3500M -Xss16M -classpath ' . $self->o('BuildSynteny_exe') . ' BuildSynteny',
                              'gff_file' => '#synteny_dir#/#seq_region_name#.syten.gff', #to agree with output of DumpGFFAlignmentsForSynteny.pl
                              'output_file' => '#synteny_dir#/#seq_region_name#.#maxDist1#.#minSize1#.BuildSynteny.out',
                              },
              -rc_name => '3.6Gb',
              -meadow_type  => 'LSF',   # The head nodes cannot run Java programs
            },
            #Concatenate into single file
            { -logic_name => 'concat_files',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => { 
                              'output_file' => '#synteny_dir#/all.#maxDist1#.#minSize1#.BuildSynteny',
                              'cmd' => 'cat #synteny_dir#/*.BuildSynteny.out | grep cluster > #output_file#',
                              'return_codes_2_branches'   => { 1 => 2 },
                             },
             -flow_into => { 
                              '1' => [ 'load_dnafrag_regions' ],
                              '2' => { 'delete_synteny' => {'mlss_id' => '#ortholog_mlss_id#'} },
                           },
              
            },
            @{$self->init_basic_tables_analyses('#master_db#', undef, 1, 0, 0, [{}])},

            { -logic_name => 'load_dnafrag_regions',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::LoadDnafragRegions',
              -parameters => { 
                              'input_file' => '#synteny_dir#/all.#maxDist1#.#minSize1#.BuildSynteny',
                             },
              -flow_into => ['SyntenyStats'],
            },
    
            {   
              -logic_name      => 'SyntenyStats',
              -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::SyntenyStats',
              -parameters      => {
                                   mlss_id  => '#synteny_mlss_id#',
                                  },
              -flow_into => {
                              2 => WHEN( '(#avg_genomic_coverage# < #min_genome_coverage#) and (defined(#ptree_db#) )' => {'delete_synteny' =>{'mlss_id' => '#ortholog_mlss_id#'} },
                                         '(#avg_genomic_coverage# < #min_genome_coverage#) and (!defined(#ptree_db#) )' => {'delete_synteny' =>{'mlss_id' => '#pairwise_mlss_id#'} },
                                         '(#avg_genomic_coverage# > #min_genome_coverage#) and (defined(#ptree_db#) )' => {'update_mlss_tag_table' =>{'mlss_id' => '#ortholog_mlss_id#', 'is_pw_mlss' => 0} },
                                         '(#avg_genomic_coverage# > #min_genome_coverage#) and (!defined(#ptree_db#) )' => {'update_mlss_tag_table' =>{'mlss_id' => '#pairwise_mlss_id#', 'is_pw_mlss' => 1} },
                                        ),
                            },
              -max_retry_count => 0,
              -analysis_capacity => 5,
              -rc_name => '3.6Gb',
            },

        {   -logic_name => 'delete_synteny',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::DeleteSynteny',
        },

        {   -logic_name => 'update_mlss_tag_table',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::UpdateMlssTag',
            -parameters      => {
                                   synteny_mlss_id  => '#synteny_mlss_id#',
                                  },
        },

   ];
}

1;
