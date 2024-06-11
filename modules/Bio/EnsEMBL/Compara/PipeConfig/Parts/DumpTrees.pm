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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees

=head1 DESCRIPTION

This PipeConfig contains the core analyses required to dump all the
gene-trees and homologies under #base_dir#.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  # Allow this particular config to use conditional dataflow and INPUT_PLUS

sub pipeline_analyses_dump_trees {
    my ($self) = @_;
    return [

        {   -logic_name => 'dump_trees_pipeline_start',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
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
            -rc_name    => '1Gb_job',
            -flow_into => {
                '2->A' => [ 'mk_work_dir' ],
                'A->1' => [ 'md5sum_tree_funnel_check' ],
            },
        },

        {   -logic_name => 'md5sum_tree_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'md5sum_tree_factory' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'mk_work_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'         => 'mkdir -p #hash_dir#/tar',
            },
            -flow_into  => [
                    WHEN('#member_type# eq "protein" && #clusterset_id# eq "default"' => 'dump_for_uniprot'),
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
                'output_file'   => '#base_dir#/#division#.#uniprot_file#',
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
            -hive_capacity => $self->o('dump_trees_capacity'),
            -rc_name       => '1Gb_168_hour_job',
            -flow_into => {
                1 => WHEN(
                    '-z #output_file#' => { 'remove_empty_file' => { 'full_name' => '#output_file#' } },
                    ELSE { 'archive_long_files' => { 'full_name' => '#output_file#' } },
                ),
            },
          },

        {   -logic_name => 'factory_homology_range_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name   => '1Gb_168_hour_job',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT MIN(homology_id) AS min_hom_id, MAX(homology_id) AS max_hom_id FROM homology JOIN gene_tree_root ON gene_tree_root_id = root_id WHERE clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -hive_capacity => $self->o('dump_trees_capacity'),
            -flow_into => { 2 => 'factory_per_genome_homology_range_dumps' },
        },

        {   -logic_name => 'factory_per_genome_homology_range_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT DISTINCT genome_db_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN seq_member USING (seq_member_id) WHERE clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -hive_capacity => $self->o('dump_trees_capacity'),
            -rc_name       => '1Gb_24_hour_job',
            -flow_into => {
                '2->A' => [ 'fetch_exp_line_count_per_genome' ],
                'A->1' => [ 'per_genome_homology_funnel_check' ],
            },
        },

        {   -logic_name => 'per_genome_homology_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'concatenate_genome_homologies_tsv' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'dump_all_trees_orthoxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML',
            -parameters => {
                'compara_db'            => '#rel_db#',
                'tree_type'             => 'tree',
            },
            -rc_name => '1Gb_168_hour_job',
            -hive_capacity => $self->o('dump_trees_capacity'),
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
            -rc_name => '4Gb_168_hour_job',
            -flow_into => {
                1 => {
                    'archive_long_files' => { 'full_name' => '#file#' },
                    }
            },
        },

        {   -logic_name => 'concatenate_genome_homologies_tsv',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'cmd'         => q{rm #output_file#; for filename in $(find #tsv_dir# -name #name_root#.homologies.tsv); do if [ ! -e #output_file# ]; then head -1 $filename > #output_file#; fi; tail -n +2 $filename >> #output_file#; done},
                'output_file' => '#tsv_dir#/#name_root#.homologies.tsv',
            },
            -flow_into => {
                1 => [ 'archive_per_genome_homologies_tsv_factory' ],
                '1->A' => {
                    'convert_tsv_to_orthoxml' => [
                        {'tsv_file' => '#output_file#', 'xml_file' => '#xml_dir#/#name_root#.allhomologies.orthoxml.xml'},
                        {'tsv_file' => '#output_file#', 'xml_file' => '#xml_dir#/#name_root#.allhomologies_strict.orthoxml.xml', 'high_confidence' => 1},
                    ],
                },
                'A->1' => { 'concatenated_homology_funnel_check' => { 'full_name' => '#output_file#' } }
            },
        },

        {   -logic_name => 'concatenated_homology_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'archive_long_files' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'archive_per_genome_homologies_tsv_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name    => '1Gb_job',
            -parameters => {
                'inputcmd'      => 'find #tsv_dir# -mindepth 2 -name #name_root#.homologies.tsv',
                'column_names'  => [ 'full_name' ],
            },
            -flow_into => {
                2 => 'archive_long_files'
            },
        },

        {   -logic_name => 'convert_tsv_to_orthoxml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HomologiesTSVToOrthoXML',
            -parameters => {
                'compara_db' => '#rel_db#',
            },
            -flow_into  => { 1 => {
                'archive_long_files' => [
                    { 'full_name' => '#xml_file#', },
                ]
            }},
            -rc_name => '16Gb_168_hour_job',
        },

        {   -logic_name => 'fetch_exp_line_count_per_genome',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name   => '1Gb_job',
            -parameters => {
                'db_conn' => '#rel_db#',
                'inputquery' => q/SELECT
                                      COUNT(*) AS exp_line_count
                                  FROM
                                      homology h
                                      JOIN (
                                            homology_member hm1
                                            JOIN gene_member gm1 USING (gene_member_id)
                                      ) USING (homology_id)
                                      JOIN (
                                            homology_member hm2
                                            JOIN gene_member gm2 USING (gene_member_id)
                                      ) USING (homology_id)
                                  WHERE
                                      homology_id BETWEEN #min_hom_id# AND #max_hom_id#
                                      AND hm1.gene_member_id > hm2.gene_member_id
                                      AND gm1.genome_db_id = #genome_db_id#/,
                'column_names' => 1,
            },
            -hive_capacity => $self->o('dump_per_genome_cap'),
            -flow_into => {
                2 => [ 'dump_per_genome_homologies_tsv' ],
            },
        },

          { -logic_name => 'dump_per_genome_homologies_tsv',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV',
            -rc_name   => '1Gb_job',
            -parameters => {
                'db_conn'       => '#rel_db#',
                'output_file'   => '#tsv_dir#/#species_name#/#name_root#.homologies.tsv',
            },
            -hive_capacity => $self->o('dump_per_genome_cap'),
          },

        {   -logic_name => 'create_dump_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => '#rel_db#',
                'inputquery'            => 'SELECT root_id AS tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "#clusterset_id#" AND member_type = "#member_type#"',
            },
            -hive_capacity => $self->o('dump_trees_capacity'),
            -rc_name   => '1Gb_job',
            -flow_into => {
                '2->A' => { 'dump_a_tree'  => { 'tree_id' => '#tree_id#', 'hashed_id' => '#expr(dir_revhash(#tree_id#))expr#' } },
                'A->1' => 'tree_dump_funnel_check',
            },
        },

        {   -logic_name => 'tree_dump_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'generate_collations' => INPUT_PLUS() } ],
        },

        {   -logic_name    => 'dump_a_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dump_script'       => $self->o('dump_gene_tree_exe'),
                'tree_args'         => '-nh 1 -a 1 -nhx 1 -f 1 -fc 1 -oxml 1 -pxml 1 -cafe 1',
                'dataflow_file'     => '#hash_dir#/#hashed_id#/tree.#tree_id#.dataflow.json',
                'cmd'               => '#dump_script# --reg_conf #reg_conf# --reg_alias #rel_db# --dirpath #hash_dir#/#hashed_id# --tree_id #tree_id# --dataflow_file #dataflow_file# #tree_args#',
            },
            -flow_into     => {
                1  => [ 'validate_xml' ],
                -1 => [ 'dump_a_tree_himem' ],
            },
            -hive_capacity => $self->o('dump_trees_capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '2Gb_job',
        },

        {   -logic_name    => 'dump_a_tree_himem',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dump_script'       => $self->o('dump_gene_tree_exe'),
                'tree_args'         => '-nh 1 -a 1 -nhx 1 -f 1 -fc 1 -oxml 1 -pxml 1 -cafe 1',
                'dataflow_file'     => '#hash_dir#/#hashed_id#/tree.#tree_id#.dataflow.json',
                'cmd'               => '#dump_script# --reg_conf #reg_conf# --reg_alias #rel_db# --dirpath #hash_dir#/#hashed_id# --tree_id #tree_id# --dataflow_file #dataflow_file# #tree_args#',
            },
            -flow_into     => {
                1  => [ 'validate_xml' ],
            },
            -hive_capacity => $self->o('dump_trees_capacity'),       # allow several workers to perform identical tasks in parallel
            -rc_name       => '16Gb_job',
        },

        {   -logic_name    => 'validate_xml',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'xmllint_exe'   => $self->o('xmlschema_validate_exe'),
                'cmd'           => '#xmllint_exe# --noout --schema #schema_file# #filename#',
                'schema_file'   => $self->o('shared_hps_dir') . '/xml_schema/#schema#.xsd',
            },
            -batch_size    => $self->o('batch_size'),
            -analysis_capacity => $self->o('dump_trees_capacity'),
            -rc_name       => '2Gb_24_hour_job',
        },

        {   -logic_name => 'generate_collations',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name    => '1Gb_job',
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
            -rc_name       => '1Gb_24_hour_job',
            -parameters    => {
                'collated_file' => '#emf_dir#/#dump_file_name#',
                'cmd'           => 'find #hash_dir# -name "tree.*.#extension#" | sort -t . -k2 -n | xargs cat > #collated_file#',
            },
            -flow_into => {
                1 => WHEN(
                    '-z #collated_file#' => { 'remove_empty_file' => { 'full_name' => '#collated_file#' } },
                    ELSE { 'archive_long_files' => { 'full_name' => '#collated_file#' } },
                ),
            },
        },

        {   -logic_name => 'generate_tarjobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name    => '1Gb_job',
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
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'step'          => $self->o('max_files_per_tar'),
                'contiguous'    => 0,
                'inputcmd'      => 'find #hash_dir# -name "tree.*.#extension#" | sed "s:#hash_dir#/*::" | sort -t . -k2 -n',
            },
            -flow_into => {
                '2->A' => [ 'tar_dumps' ],
                'A->1' => [ 'tar_dump_funnel_check' ],
            },
        },

        {   -logic_name => 'tar_dump_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'tar_list' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'tar_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'file_list'     => '#expr( join("\n", @{ #_range_list# }) )expr#',   # Assumes no whitespace in the filenames
                'min_tree_id'   => '#expr( ($_ = #_range_start#) and $_ =~ s/^.*tree\.(\d+)\..*$/$1/ and $_ )expr#',
                'max_tree_id'   => '#expr( ($_ = #_range_end#)   and $_ =~ s/^.*tree\.(\d+)\..*$/$1/ and $_ )expr#',
                'tar_archive'   => '#hash_dir#/tar/#dump_file_name#.#min_tree_id#-#max_tree_id#.tar',
                'cmd'           => 'echo "#file_list#" | tar cf #tar_archive# -C #hash_dir# -T /dev/stdin --transform "s:^.*/:#basename#.:"',
            },
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#tar_archive#' } },
            },
        },

        {   -logic_name => 'tar_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'file_list'     => '#hash_dir#/tar/#dump_file_name#.list',
                'cmd'           => 'find #hash_dir#/tar -name "#dump_file_name#.*-*.tar.gz" | sort > #file_list#',
            },
            -flow_into => {
                1 => WHEN('-s #file_list#' => [ 'tar_tar_dumps' ]),
            },
        },

        {   -logic_name => 'tar_tar_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'file_list'     => '#hash_dir#/tar/#dump_file_name#.list',
                'tar_tar_path'  => '#xml_dir#/#dump_file_name#.tar',
                'cmd'           => 'tar cf #tar_tar_path# -C #xml_dir# --files-from #file_list# --transform "s:^.*/::"',
            },
        },

        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_24_hour_job',
            -parameters => {
                'cmd'         => 'gzip -f #full_name#',
            },
        },

        {   -logic_name => 'remove_empty_file',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'         => 'rm #full_name#',
            },
        },

        {   -logic_name => 'md5sum_tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name    => '1Gb_job',
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
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd' => 'cd #directory# ; md5sum *.gz >MD5SUM',
            },
        },

    ];
}

1;
