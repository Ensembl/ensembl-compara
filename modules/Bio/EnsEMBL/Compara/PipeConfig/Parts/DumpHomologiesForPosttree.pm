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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree

=head1 DESCRIPTION

The PipeConfig file for the pipeline that dumps the homologies into TSV format for use
in the post-tree analyses of the homology pipelines

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

sub pipeline_analyses_dump_homologies_posttree {
    my ($self) = @_;
    return [
        {   -logic_name => 'homology_dumps_mlss_id_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'    => {
                    'ENSEMBL_PARALOGUES'    => 2,
                    'ENSEMBL_ORTHOLOGUES'   => 2,
                    'ENSEMBL_HOMOEOLOGUES'  => 2,
                },
                'line_count' => 1,
            },
            -flow_into => {
                2 => [ 'dump_per_mlss_homologies_tsv' ],
            },
        },

        { -logic_name => 'dump_per_mlss_homologies_tsv',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV',
          -parameters => {
              'hashed_id'   => '#expr(dir_revhash(#mlss_id#))expr#',
              'output_file' => '#homology_dumps_dir#/#hashed_id#/#mlss_id#.#member_type#.homologies.tsv',
              # WHERE hm1.gene_member_id < hm2.gene_member_id avoids duplication of data in different orientation
              # i.e. we don't need B->A if we already have A->B
              'input_query' => q|
                SELECT
                    h.homology_id, h.description AS homology_type, h.gene_tree_node_id, h.gene_tree_root_id, h.species_tree_node_id, h.is_tree_compliant,
                    sm1.gene_member_id, sm1.seq_member_id, sm1.stable_id, sm1.genome_db_id, hm1.perc_id, hm1.perc_cov,
                    sm2.gene_member_id AS homology_gene_member_id, sm2.seq_member_id AS homology_seq_member_id, sm2.stable_id as homology_stable_id, sm2.genome_db_id AS homology_genome_db_id, hm2.perc_id AS homology_perc_id, hm2.perc_cov AS homology_perc_cov
                FROM
                    homology h
                    JOIN (homology_member hm1 JOIN seq_member sm1 USING (seq_member_id)) USING (homology_id)
                    JOIN (homology_member hm2 JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id)
                WHERE
                    hm1.gene_member_id < hm2.gene_member_id
                    #extra_filter#
              |,
              'healthcheck' => 'line_count',
          },
          -hive_capacity => 10,
        },  
    ];
}

sub pipeline_analyses_split_homologies_posttree {
    my ($self) = @_;
    return [
        {   -logic_name => 'homology_dumps_mlss_id_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory',
            -parameters => {
                'methods'    => {
                    'ENSEMBL_ORTHOLOGUES'  => 2,
                    'ENSEMBL_PARALOGUES'   => 2,
                    'ENSEMBL_HOMOEOLOGUES' => 2,
                },
                'batch_size' => 100,
            },
            -flow_into => {
                2 => [ 'split_tree_homologies' ],
            },
        },

        { -logic_name => 'split_tree_homologies',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SplitOrthoTreeOutput',
        },
    ];
}

1;
