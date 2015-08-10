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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf

=head1 DESCRIPTION

This pipeline is using eHive's parameter-stack mechanism, i.e. the jobs
inherit the parameters of their parents.
The pipeline should be configured exclusively from the command line, with the
-pairwise_db_url and possibly -pairwise_mlss_id parameters. If the latter is
skipped, the pipeline will use all the pairwise alignments found on the server.
The pipeline automatically finds the alignments that are missing syntenies and
compute these (incl. the stats)
The analysis "compute_synteny_start" can be seeded multiple times.
Extra parameters like "level", "orient", "minSize1", etc, should also be given
at the command-line level, and not in this file.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
            %{$self->SUPER::default_options},   # inherit the generic ones
            
            'host'          => 'compara5',      # Where to host the pipeline database

	    'master_db' => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
            'work_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/synteny/release_' . $self->o('rel_with_suffix'),

            # Connections to the pairwise database must be given
            #'pairwise_db_url' => undef, #pairwise database to calculate the syntenies from
            'pairwise_mlss_id'  => undef,   # if undef, will use all the pairwise alignments found in it

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

            #executable locations
            'DumpGFFAlignmentsForSynteny_exe' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl",
            'BuildSynteny_exe' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/synteny/BuildSynteny.jar",

           };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

        'mkdir -p '.$self->o('work_dir'), #Make dump_dir directory
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'master_db'     => $self->o('master_db'),

            # 'synteny_mlss_id' will be evaluated in the runnables, not here
        'synteny_dir'   => $self->o('work_dir').'/#synteny_mlss_id#/',

        'maxDist1' => $self->o('maxDist1'),
        'minSize1' => $self->o('minSize1'),
        'maxDist2' => $self->o('maxDist2'),
        'minSize2' => $self->o('minSize2'),
        'orient'   => $self->o('orient'),

        'level'     => $self->o('level'),
        'include_non_karyotype' => $self->o('include_non_karyotype'),
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

        {   -logic_name => 'compute_synteny_start',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::FetchSyntenyParameters',
            -input_ids  => [
                {
                    pairwise_db_url     => $self->o('pairwise_db_url'),
                    pairwise_mlss_id    => $self->o('pairwise_mlss_id'),
                },
            ],
            -wait_for   => [ 'copy_tables_from_master_db' ],
            -flow_into  => {
                2 => 'register_mlss',
            },
        },

        {   -logic_name => 'register_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS',
            -parameters => {
                mlss_id     => '#synteny_mlss_id#',
            },
            -flow_into  => [ 'create_work_dir'],
        },

        {   -logic_name => 'create_work_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'mkdir -p #synteny_dir#',
            },
            -flow_into  => [ 'chr_name_factory' ],
        },
            #dump chr names
            {   -logic_name => 'chr_name_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::ListChromosomes',
                -parameters => {
                                'compara_db'            => '#pairwise_db_url#',
                                'species_name'          => '#ref_species#',
                               },
                -flow_into => {
                               '2->A' => [ 'dump_gff_alignments' ],
                               'A->1' => [ 'concat_files' ],
                              },
              
            },
            #Dump gff alignments
            { -logic_name => 'dump_gff_alignments',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => {
                              'program'    => $self->o('DumpGFFAlignmentsForSynteny_exe'),
                              'cmd' => "#program# --dbname #pairwise_db_url# --qy #ref_species# --method_link_species_set #pairwise_mlss_id# --seq_region #seq_region_name# --force #include_non_karyotype# --level #level# --output_dir #synteny_dir#",
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
                              'program' => 'java -Xmx1700M -classpath ' . $self->o('BuildSynteny_exe') . ' BuildSynteny',
                              'gff_file' => '#synteny_dir#/#seq_region_name#.syten.gff', #to agree with output of DumpGFFAlignmentsForSynteny.pl
                              'output_file' => '#synteny_dir#/#seq_region_name#.#maxDist1#.#minSize1#.BuildSynteny.out',
                              },
              -rc_name => '1.8Gb',
              -meadow_type  => 'LSF',   # The head nodes cannot run Java programs
            },
            #Concatenate into single file
            { -logic_name => 'concat_files',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => { 
                              'output_file' => '#synteny_dir#/all.#maxDist1#.#minSize1#.BuildSynteny',
                              'cmd' => 'cat #synteny_dir#/*.BuildSynteny.out | grep cluster > #output_file#',
                             },
             -flow_into => { 
                              '1' => [ 'copy_dnafrags_from_master' ],
                           },
              
            },
            @{$self->init_basic_tables_analyses('#master_db#', undef, 1, 0, 0, [{}])},

            { -logic_name => 'copy_dnafrags_from_master',
              -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
              -parameters    => {
                                 'src_db_conn'   => '#master_db#',
                                 'mode'          => 'insertignore',
                                 'table'         => 'dnafrag',
                                 'where'         => 'is_reference = 1 AND genome_db_id IN (#genome_db_ids#)'
                                },
              -flow_into => {
                              1 => [ 'load_dnafrag_regions' ],
                            },
            },
            { -logic_name => 'load_dnafrag_regions',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::LoadDnafragRegions',
              -parameters => { 
                              'input_file' => '#synteny_dir#/all.#maxDist1#.#minSize1#.BuildSynteny',
                             },
              -flow_into => ['SyntenyStats'],
            },
    
            {   
              -logic_name      => 'SyntenyStats',
              -module          => 'Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats',
              -parameters      => {
                                   mlss_id  => '#synteny_mlss_id#',
                                  },
              -max_retry_count => 0,
              -rc_name => '3.6Gb',
            },
   ];
}

1;
