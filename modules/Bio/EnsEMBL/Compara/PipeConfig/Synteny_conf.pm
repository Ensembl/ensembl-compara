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

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

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
            
            'pipeline_name'         => 'SYNTENY_'.$self->o('synteny_mlss_id')."_".$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
            'dbname'               => $self->o('pipeline_name'), #pipeline database name

            'host'        => 'compara5',                        #host name
            'pipeline_db' => {                                  # connection parameters
                              -species => 'Multi',
                              -host   => $self->o('host'),
                              -port   => 3306,
                              -user   => 'ensadmin',
                              -pass   => $self->o('password'),
                              -dbname => $ENV{USER}.'_'.$self->o('dbname'),
                              -driver => 'mysql',
                             },
            'division'      => 'Multi', # Stats 
            'store_in_pipeline_db' => 1, # Stats
	    'master_db' => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
            'synteny_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/synteny/' . 'release_' . $self->o('rel_with_suffix') . '/' . $self->o('synteny_mlss_id') . '/',

            'compara_url' => undef, #pairwise database to calculate the syntenies from
            'ref_species' => undef, #reference species
            'method_link_type' => 'LASTZ_NET', #pairwise alignment type
            'ref_coord_system_name' => 'chromosome', #which seq_regions to run syntenies on
            'non_ref_coord_system_name' => 'chromosome', #which seq_regions to run syntenies on

            #DumpGFFAlignmentsForSynteny parameters
            'force' => 0, #over-ride check for has_karyotype in DumpGFFAlignmentsForSynteny
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

            #
            #Resource requirements
            #
            'memory_suffix' => "", #temporary fix to define the memory requirements in resource_classes
            'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara5, but will have to be set manually otherwise
            'synteny_capacity' => 1000,

           };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

        'mkdir -p '.$self->o('synteny_dir'), #Make dump_dir directory
    ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
	    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
           };
}

sub resource_classes {
    my ($self) = @_;
    
    my $host = $self->o('pipeline_db')->{host};
    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb' => { 'LSF' => '-C0 -M100' . $self->o('memory_suffix') .' -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'   => { 'LSF' => '-C0 -M1000' . $self->o('memory_suffix') .' -R"select[mem>1000] rusage[mem=1000]"' },
            '1.8Gb' => { 'LSF' => '-C0 -M1800' . $self->o('memory_suffix') .' -R"select[mem>1800 && '.$self->o('dbresource').'<'.$self->o('synteny_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=3]"' },
            '3.6Gb' => { 'LSF' => '-C0 -M3600' . $self->o('memory_suffix') .' -R"select[mem>3600 && '.$self->o('dbresource').'<'.$self->o('synteny_capacity').'] rusage[mem=3600,'.$self->o('dbresource').'=10:duration=3]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
            #dump chr names
            {   -logic_name => 'chr_name_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'db_conn'    => $self->o('compara_url'),
                                'inputquery' => 'SELECT DISTINCT(dnafrag.name) AS seq_region FROM dnafrag LEFT JOIN genome_db USING (genome_db_id) WHERE genome_db.name = "' . $self->o('ref_species') . '" AND coord_system_name= "'. $self->o('ref_coord_system_name') . '" AND is_reference = 1 ORDER BY seq_region',
                                'fan_branch_code'   => 2,
                               },
                -input_ids => [{}],
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
                              'compara_url' => $self->o('compara_url'),
                              'query_name' => $self->o('ref_species'),
                              'method_link_type' => $self->o('method_link_type'),
                              'pairwise_mlss_id'    => $self->o('pairwise_mlss_id'),
                              'level'      => $self->o('level'),
                              'force'      => $self->o('force'),
                              'output_dir' => $self->o('synteny_dir') . "/",
                              'ref_coord_system_name' => $self->o('ref_coord_system_name'),
                              'non_ref_coord_system_name' => $self->o('non_ref_coord_system_name'),
                              'cmd' => "#program# --dbname #compara_url# --qy #query_name# --ref_coord_system_name #ref_coord_system_name# --non_ref_coord_system_name #non_ref_coord_system_name# --method_link_species_set #pairwise_mlss_id# --seq_region #seq_region# --force #force# --output_dir #output_dir#",
                              },
                -flow_into => {
                               '1' => [ 'build_synteny' ],
                              },
              -hive_capacity => 3, #database intensive
              -rc_name => '1.8Gb',
            },
            #Build synteny regions
            { -logic_name => 'build_synteny',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny',
              -parameters => {
                              'program' => 'java -Xmx2000M -classpath ' . $self->o('BuildSynteny_exe') . ' BuildSynteny',
                              'output_dir' => $self->o('synteny_dir') . "/",
                              'gff_file' => '#output_dir##seq_region#.syten.gff', #to agree with output of DumpGFFAlignmentsForSynteny.pl
                              'maxDist1' => $self->o('maxDist1'),
                              'minSize1' => $self->o('minSize1'),
                              'maxDist2' => $self->o('maxDist2'),
                              'minSize2' => $self->o('minSize2'),
                              'orient' => $self->o('orient'),
                              'output_file' => '#output_dir##seq_region#.#maxDist1#.#minSize1#.BuildSynteny.out',
                              },
              -rc_name => '1.8Gb',
            },
            #Concatenate into single file
            { -logic_name => 'concat_files',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => { 
                              'output_dir' => $self->o('synteny_dir') . "/",
                              'maxDist' => $self->o('maxDist1'),
                              'minSize' => $self->o('minSize1'),
                              'output_file' => '#output_dir#all.#maxDist#.#minSize#.BuildSynteny',
                              'cmd' => 'cat #output_dir#*.BuildSynteny.out | grep cluster > #output_file#',
                             },
             -flow_into => { 
                              '1' => [ 'copy_tables_factory' ],
                           },
              
            },
            { -logic_name => 'copy_tables_factory',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
              -parameters => {
                             'db_conn' => $self->o('compara_url'),
                             'inputlist'    => [ 'genome_db', 'dnafrag', 'method_link', 'method_link_species_set', 'species_set'],
			     'column_names' => [ 'table' ],
                             },
              -flow_into => {
                             '2->A' => [ 'copy_tables_from_pairwise_db' ],
                             'A->1' => [ 'copy_mlssid_from_master' ],
                            },
            },              
            { -logic_name => 'copy_tables_from_pairwise_db',
              -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
              -parameters    => {
                                 'src_db_conn'   => $self->o('compara_url'),
                                 'dest_db_conn'  => $self->o('pipeline_db'),
                                 'mode'          => 'overwrite',
                                 'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                                },
            
            },
            { -logic_name => 'copy_mlssid_from_master',
              -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
              -parameters    => {
                                 'src_db_conn'   => $self->o('master_db'),
                                 'dest_db_conn'  => $self->o('pipeline_db'),
                                 'synteny_mlss_id' => $self->o('synteny_mlss_id'),
                                 'mode'          => 'replace',
                                 'table'         => 'method_link_species_set',
                                 'where'         => 'method_link_species_set_id = #synteny_mlss_id#',
                                },
              -flow_into => {
                              1 => [ 'load_dnafrag_regions' ],
                            },
            },
            { -logic_name => 'load_dnafrag_regions',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Synteny::LoadDnafragRegions',
              -parameters => { 
                              'input_file' => '#output_dir#all.#maxDist#.#minSize#.BuildSynteny',
                              'pairwise_mlss_id'    => $self->o('pairwise_mlss_id'), 
                              'synteny_mlss_id' => $self->o('synteny_mlss_id'),
                              'ref_species' => $self->o('ref_species'),
                              'master_db' => $self->o('master_db'),
                              'pipeline_db' => $self->o('pipeline_db'),
                              'compara_url' => $self->o('compara_url'),
                              'output_dir' => $self->o('synteny_dir'),
                              'maxDist' => $self->o('maxDist1'),
                              'minSize' => $self->o('minSize1'),
                              'output_file' => '#output_dir#all.#maxDist#.#minSize#.BuildSynteny',
                             },
              -flow_into => ['FetchMLSS'],
            },
            { -logic_name      => 'FetchMLSS',
              -module          => 'Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::FetchMLSS',
              -max_retry_count => 0,
              -parameters      => {
                                     division => $self->o('division'),
                                     store_in_pipeline_db => $self->o('store_in_pipeline_db'),
                                     pipeline_db => $self->o('pipeline_db'),
                                     mlss_id  => $self->o('synteny_mlss_id'),
                                  },
              -flow_into       => {
                                    1 => ['SyntenyStats'],
                                  },
            },
    
            {   
              -logic_name      => 'SyntenyStats',
              -module          => 'Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::SyntenyStats',
              -parameters      => {
                                   division => $self->o('division'),
                                   store_in_pipeline_db => $self->o('store_in_pipeline_db'),
                                   pipeline_db => $self->o('pipeline_db'),
                                   mlss_id  => $self->o('synteny_mlss_id'),
                                  },
              -max_retry_count => 0,
              -rc_name => '3.6Gb',
            },
   ];
}

1;
