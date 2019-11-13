=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery' => 'SELECT method_link_species_set_id AS mlss_id, COUNT(*) as exp_line_count FROM homology GROUP BY method_link_species_set_id',
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
                    h.homology_id, h.description AS homology_type, h.gene_tree_node_id, h.gene_tree_root_id, h.species_tree_node_id,
                    sm1.gene_member_id, sm1.seq_member_id, sm1.stable_id as seq_member_stable_id, sm1.genome_db_id, hm1.perc_id AS identity, hm1.perc_cov AS coverage,
                    sm2.gene_member_id AS hom_gene_member_id, sm2.seq_member_id AS hom_seq_member_id, sm2.stable_id as hom_seq_member_stable_id, sm2.genome_db_id AS hom_genome_db_id, hm2.perc_id AS hom_identity, hm2.perc_cov AS hom_coverage
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
          -rc_name => '500Mb_job',
        },  
    ];
}

1;
