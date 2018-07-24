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

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

sub pipeline_analyses_dump_trees {
    my ($self) = @_;
    return [

        {   -logic_name => 'dump_trees_pipeline_start',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'readme_dir'    => $self->o('readme_dir'),
                'cmd'           => join('; ',
                                    'mkdir -p #xml_dir# #emf_dir# #tsv_dir#',
                                    'cp -af #readme_dir#/README.gene_trees.emf_dumps.txt #emf_dir#',
                                    'cp -af #readme_dir#/README.gene_trees.xml_dumps.txt #xml_dir#',
                                    'cp -af #readme_dir#/README.gene_trees.tsv_dumps.txt #tsv_dir#',
                                   ),
            },
            # -input_ids  => [ {} ],
            -flow_into  => [ 'collection_factory' ],
        },

        {   -logic_name => 'collection_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -flow_into => {
                '2->A' => [ 'mk_work_dir' ],
                'A->1' => [ 'md5sum_tree_factory' ],
            },
            -rc_name => 'default_with_registry',
        },

        {   -logic_name => 'mk_work_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => 'mkdir -p #work_dir#',
            },
            -flow_into  => [
                    WHEN('#member_type# eq "protein"' => 'dump_for_uniprot'),
                    {
                        'create_dump_jobs' => undef,
                        'factory_homology_range_dumps' => undef,
                        'dump_all_trees_orthoxml' => { 'file' => '#xml_dir#/#name_root#.alltrees.orthoxml.xml', },
                    }
                ],
        },

          { -logic_name => 'dump_for_uniprot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'db_conn'       => '#rel_db#',
                'output_file'   => sprintf('#base_dir#/#division#.GeneTree_content.#clusterset_id#.e%s.txt', $self->o('ensembl_release')),
                'append'        => [qw(-N -q)],
                'input_query'   => sprintf q|
                    SELECT 
                        gtr.stable_id AS GeneTreeStableID, 
                        pm.stable_id AS EnsPeptideStableID,
                        gm.stable_id AS EnsGeneStableID,
                        IF(m.seq_member_id = pm.seq_member_id, 'Y', 'N') as Canonical
                    FROM
                        gene_tree_root gtr
                        JOIN gene_tree_node gtn ON (gtn.root_id = gtr.root_id)
                        JOIN seq_member m on (gtn.seq_member_id = m.seq_member_id)
                        JOIN gene_member gm on (m.gene_member_id = gm.gene_member_id)
                        JOIN seq_member pm on (gm.gene_member_id = pm.gene_member_id)
                    WHERE
                        gtr.member_type = 'protein'
                        AND gtr.stable_id IS NOT NULL
                        AND gtr.clusterset_id = '#clusterset_id#'
                |,
            },
            -flow_into => {
                1 => WHEN(
                    '-z #output_file#' => { 'remove_empty_file' => { 'full_name' => '#output_file#' } },
                    ELSE { 'archive_long_files' => { 'full_name' => '#output_file#' } },
                ),
            },
          },

        {   -logic_name => 'factory_homology_range_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT MIN(homology_id) AS min_hom_id, MAX(homology_id) AS max_hom_id FROM homology JOIN gene_tree_root ON gene_tree_root_id = root_id WHERE clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -flow_into => {
                2 => WHEN(
                    '#max_hom_id#' => {
                        'dump_all_homologies_tsv' => undef,
                        'dump_all_homologies_orthoxml' => [
                            {'file' => '#xml_dir#/#name_root#.allhomologies.orthoxml.xml'},
                            {'file' => '#xml_dir#/#name_root#.allhomologies_strict.orthoxml.xml', 'high_confidence' => 1},
                        ],
                    } ,
                    '#max_hom_id# && #dump_per_species_tsv#' => {
                        'factory_per_genome_homology_range_dumps' => undef,
                    },
                ),
            },
        },

        {   -logic_name => 'factory_per_genome_homology_range_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT DISTINCT genome_db_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN seq_member USING (seq_member_id) WHERE clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -flow_into => {
                2 => 'dump_per_genome_homologies_tsv',
            },
        },

        {   -logic_name => 'dump_all_homologies_orthoxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML',
            -parameters => {
                'compara_db'            => '#rel_db#',
            },
            -flow_into => {
                1 => {
                    'archive_long_files' => { 'full_name' => '#file#', },
                    }
            },
            -analysis_capacity => $self->o('dump_hom_capacity'),
        },

        {   -logic_name => 'dump_all_trees_orthoxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML',
            -parameters => {
                'compara_db'            => '#rel_db#',
                'tree_type'             => 'tree',
            },
            -rc_name => '1Gb_job',
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#file#' } },
               -1 => [ 'dump_all_trees_orthoxml_himem' ],  # MEMLIMIT
            },
        },

        {   -logic_name => 'dump_all_trees_orthoxml_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML',
            -parameters => {
                'compara_db'            => '#rel_db#',
                'tree_type'             => 'tree',
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                1 => {
                    'archive_long_files' => { 'full_name' => '#file#' },
                    }
            },
        },

          { -logic_name => 'dump_all_homologies_tsv',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV',
            -parameters => {
                'db_conn'       => '#rel_db#',
                'output_file'   => '#tsv_dir#/#name_root#.homologies.tsv',
            },
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#output_file#' } },
            },
            -analysis_capacity => $self->o('dump_hom_capacity'),
          },

          { -logic_name => 'dump_per_genome_homologies_tsv',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV',
            -parameters => {
                'db_conn'       => '#rel_db#',
                'output_file'   => '#tsv_dir#/#species_name#/#name_root#.homologies.tsv',
            },
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#output_file#' } },
            },
            -analysis_capacity => $self->o('dump_per_genome_cap'),
          },

        {   -logic_name => 'create_dump_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT root_id AS tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -flow_into => {
                'A->1' => 'generate_collations',
                '2->A' => { 'dump_a_tree'  => { 'tree_id' => '#tree_id#', 'hash_dir' => '#expr(dir_revhash(#tree_id#))expr#' } },
            },
        },

        {   -logic_name    => 'dump_a_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dump_script'       => $self->o('dump_script'),
                'tree_args'         => '-nh 1 -a 1 -nhx 1 -f 1 -fc 1 -oxml 1 -pxml 1 -cafe 1',
                'base_filename'     => '#work_dir#/#hash_dir#/#tree_id#',
                'cmd'               => '#dump_script# #production_registry# --reg_alias #rel_db# --dirpath #work_dir#/#hash_dir# --tree_id #tree_id# #tree_args#',
            },
            -flow_into     => {
                1 => {
                    'validate_xml' => [
                        { 'schema' => 'orthoxml', 'filename' => '#base_filename#.orthoxml.xml' },
                        { 'schema' => 'phyloxml', 'filename' => '#base_filename#.phyloxml.xml' },
                        { 'schema' => 'phyloxml', 'filename' => '#base_filename#.cafe_phyloxml.xml' },
                    ],
                },
                -1 => [ 'dump_a_tree_himem' ],
            },
            -hive_capacity => $self->o('dump_trees_capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '2Gb_job',
        },

        {   -logic_name    => 'dump_a_tree_himem',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dump_script'       => $self->o('dump_script'),
                'tree_args'         => '-nh 1 -a 1 -nhx 1 -f 1 -fc 1 -oxml 1 -pxml 1 -cafe 1',
                'base_filename'     => '#work_dir#/#hash_dir#/#tree_id#',
                'cmd'               => '#dump_script# #production_registry# --reg_alias #rel_db# --dirpath #work_dir#/#hash_dir# --tree_id #tree_id# #tree_args#',
            },
            -flow_into     => {
                1 => {
                    'validate_xml' => [
                        { 'schema' => 'orthoxml', 'filename' => '#base_filename#.orthoxml.xml' },
                        { 'schema' => 'phyloxml', 'filename' => '#base_filename#.phyloxml.xml' },
                        { 'schema' => 'phyloxml', 'filename' => '#base_filename#.cafe_phyloxml.xml' },
                    ],
                },
            },
            -hive_capacity => $self->o('dump_trees_capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '10Gb_job',
        },

        {   -logic_name    => 'validate_xml',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'xmllint_exe'   => $self->o('xmllint_exe'),
                'cmd'           => '[[ ! -e #filename# ]] || #xmllint_exe# --noout --schema /homes/compara_ensembl/warehouse/xml_schema/#schema#.xsd #filename#',
            },
            -hive_capacity => $self->o('dump_trees_capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '2Gb_job',
        },

        {   -logic_name => 'generate_collations',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'         => [ 'aln.emf', 'nh.emf', 'nhx.emf', 'aa.fasta', 'cds.fasta', 'nt.fasta' ],
                'column_names'      => [ 'extension' ],
            },
            -flow_into => {
                1 => [ 'generate_tarjobs' ],
                2 => { 'collate_dumps'  => { 'extension' => '#extension#', 'dump_file_name' => '#name_root#.#extension#'} },
            },
        },

        {   -logic_name    => 'collate_dumps',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'collated_file' => '#emf_dir#/#dump_file_name#',
                'cmd'           => 'find #work_dir# -name "tree.*.#extension#" | sort -t . -k2 -n | xargs cat > #collated_file#',
            },
            -hive_capacity => 2,
            -flow_into => {
                1 => WHEN(
                    '-z #collated_file#' => { 'remove_empty_file' => { 'full_name' => '#collated_file#' } },
                    ELSE { 'archive_long_files' => { 'full_name' => '#collated_file#' } },
                ),
            },
        },

        {   -logic_name => 'generate_tarjobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'         => [ 'orthoxml.xml', 'phyloxml.xml', 'cafe_phyloxml.xml' ],
                'column_names'      => [ 'extension' ],
            },
            -flow_into => {
                2 => { 'tar_dumps_factory'  => { 'extension' => '#extension#', 'dump_file_name' => '#name_root#.tree.#extension#'} },
            },
        },

        {   -logic_name => 'tar_dumps_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'step'          => $self->o('max_files_per_tar'),
                'contiguous'    => 0,
                'inputcmd'      => 'find #work_dir# -name "tree.*.#extension#" | sed "s:#work_dir#/*::" | sort -t . -k2 -n',
            },
            -hive_capacity => 2,
            -flow_into => {
                2 => [ 'tar_dumps' ],
            },
        },

        {   -logic_name => 'tar_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'file_list'     => '#expr( join("\n", @{ #_range_list# }) )expr#',   # Assumes no whitespace in the filenames
                'min_tree_id'   => '#expr( ($_ = #_range_start#) and $_ =~ s/^.*tree\.(\d+)\..*$/$1/ and $_ )expr#',
                'max_tree_id'   => '#expr( ($_ = #_range_end#)   and $_ =~ s/^.*tree\.(\d+)\..*$/$1/ and $_ )expr#',
                'tar_archive'   => '#xml_dir#/#dump_file_name#.#min_tree_id#-#max_tree_id#.tar',
                'cmd'           => 'echo "#file_list#" | tar cf #tar_archive# -C #work_dir# -T /dev/stdin --transform "s:^.*/:#basename#.:"',
            },
            -hive_capacity => 2,
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#tar_archive#' } },
            },
        },

        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => 'gzip #full_name#',
            },
        },

        {   -logic_name => 'remove_empty_file',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => 'rm #full_name#',
            },
        },

        {   -logic_name => 'md5sum_tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => [ [ '#emf_dir#' ], [ '#xml_dir#' ], [ '#tsv_dir#' ] ],
                'column_names'  => [ 'directory' ],
            },
            -flow_into => {
                2 => [ 'md5sum_tree' ],
            },
        },

        {   -logic_name => 'md5sum_tree',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => 'cd #directory# ; md5sum *.gz >MD5SUM',
            },
        },

    ];
}

1;

