=heada LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf.

=head1 DESCRIPTION

    The PipeConfig file for a pipeline that should for data integrity of a gene-tree / homology table.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name'         => 'HC',   # name the pipeline to differentiate the submitted processes

        'hc_capacity'           =>   4,

        # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_tree_hc',
        },

        # The database that needs to be checked
        'db_conn' => {
           -host   => 'compara1',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'mm14_compara_homology_70c',
        },

    };
}

sub pipeline_wide_parameters {
    my $self = shift @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'db_conn'   => $self->o('db_conn'),
    }
}



sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'count_number_species',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT "species_count" AS meta_key, COUNT(*) AS meta_value FROM genome_db',
                'fan_branch_code'   => 2,
            },
            -input_ids  => [ {} ],
            -flow_into => {
                1 => [ 'species_factory', 'tree_factory', 'hc_factory_members_globally', 'hc_factory_global_trees' ],
                2 => [ 'mysql:////meta' ],
            },
            -meadow_type    => 'LOCAL',
        },


        {   -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM genome_db',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_factory_members_per_genome', 'hc_factory_pafs' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name => 'tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_factory_align', 'hc_factory_trees', 'hc_factory_tree_attributes', 'hc_factory_homologies' ],
            },
            -meadow_type    => 'LOCAL',
        },



        @{$self->analysis_members_per_genome},
        @{$self->analysis_members_globally},
        @{$self->analysis_pafs},
        @{$self->analysis_alignment},
        @{$self->analysis_tree_structure},
        @{$self->analysis_tree_attr},
        @{$self->analysis_homologies},
        @{$self->analysis_tree_globally},

    ];
}






### Members
#############

sub analysis_members_per_genome {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_members_per_genome',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
            -flow_into          => ['hc_genome_has_members'],
        },

        {   -logic_name => 'hc_genome_has_members',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT source_name FROM member WHERE genome_db_id = #genome_db_id# AND source_name IN ("ENSEMBLPEP", "ENSEMBLGENE") GROUP BY source_name HAVING COUNT(*) > 0',
                'expected_size' => '= 2',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into          => ['hc_peptides_have_genes', 'hc_genes_have_canonical_peptides', 'hc_peptides_have_sequences', 'hc_peptides_have_cds_sequences', 'hc_members_have_chrom_coordinates', 'hc_members_have_correct_taxon_id' ],
        },

        {   -logic_name => 'hc_peptides_have_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT mp.member_id FROM member mp LEFT JOIN member mg ON mp.gene_member_id = mg.member_id WHERE mp.genome_db_id = #genome_db_id# AND mp.source_name = "ENSEMBLPEP" AND mg.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },


        {   -logic_name => 'hc_genes_have_canonical_peptides',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT mg.member_id FROM member mg LEFT JOIN member mp ON mg.canonical_member_id = mp.member_id WHERE mg.genome_db_id = #genome_db_id# AND mg.source_name = "ENSEMBLGENE" AND mp.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },


        {   -logic_name => 'hc_peptides_have_sequences',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT member_id FROM member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name = "ENSEMBLPEP" AND (sequence IS NULL OR LENGTH(sequence) = 0)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_peptides_have_cds_sequences',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT mp.member_id FROM member mp LEFT JOIN other_member_sequence oms ON mp.member_id = oms.member_id AND oms.seq_type = "cds" WHERE genome_db_id = #genome_db_id# AND source_name = "ENSEMBLPEP" AND (sequence IS NULL OR LENGTH(sequence) = 0)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_members_have_chrom_coordinates',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT member_id FROM member WHERE genome_db_id = #genome_db_id# AND (chr_name IS NULL OR chr_start IS NULL OR chr_end IS NULL)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_members_have_correct_taxon_id',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT member_id FROM member JOIN genome_db USING (genome_db_id) WHERE genome_db_id = #genome_db_id# AND member.taxon_id != genome_db.taxon_id',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

    ];
}

sub analysis_members_globally {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_members_globally',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
            -flow_into          => ['hc_members_have_genome'],
        },
 
        {   -logic_name => 'hc_members_have_genome',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT member_id FROM member WHERE genome_db_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

    ];
}


### peptide_align_feature
###########################

sub analysis_pafs {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_pafs',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into          => [ 'hc_paf_hit_against_each_species' ],
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
        },

        {   -logic_name => 'hc_paf_hit_against_each_species',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT DISTINCT hgenome_db_id FROM peptide_align_feature_#name#_#genome_db_id#',
                'expected_size' => '= #species_count#',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },
    ];
}


### alignments
################

sub analysis_alignment {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_align',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into          => [ 'hc_tree_no_lost_gene', 'hc_tree_no_extra_gene', 'hc_tree_has_alignment' ],
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
        },


        {   -logic_name => 'hc_tree_no_lost_gene',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT protein_tree_backup.member_id FROM protein_tree_backup LEFT JOIN gene_tree_node USING (root_id, member_id) WHERE root_id = #gene_tree_id# AND gene_tree_node.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_no_extra_gene',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gene_tree_node.member_id FROM gene_tree_node LEFT JOIN protein_tree_backup USING (root_id, member_id) WHERE root_id = #gene_tree_id# AND gene_tree_node.member_id IS NOT NULL AND protein_tree_backup.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_has_alignment',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_root JOIN gene_align USING (gene_align_id) WHERE root_id = #gene_tree_id#',
                'expected_size' => '1'
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into  => [ 'hc_tree_align_ok', 'hc_align_no_lost_gene', 'hc_align_no_extra_gene' ],
        },

        {   -logic_name => 'hc_tree_align_ok',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_root JOIN gene_align_member USING (gene_align_id) WHERE root_id = #gene_tree_id# AND (cigar_line IS NULL OR LENGTH(cigar_line) = 0)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_align_no_lost_gene',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT protein_tree_backup.member_id FROM protein_tree_backup JOIN gene_tree_root USING (root_id) LEFT JOIN gene_align_member USING (gene_align_id, member_id) WHERE root_id = #gene_tree_id# AND gene_align_member.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_align_no_extra_gene',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gene_align_member.member_id FROM protein_tree_backup JOIN gene_tree_root USING (root_id) RIGHT JOIN gene_align_member USING (gene_align_id, member_id) WHERE root_id = #gene_tree_id# AND protein_tree_backup.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },
    ];
}


sub analysis_tree_structure {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_trees',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into          => [ 'hc_tree_is_binary', 'hc_tree_no_dangling_node', 'hc_tree_gene_count' ],
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
        },

        {   -logic_name => 'hc_tree_is_binary',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn1.node_id FROM gene_tree_node gtn1 JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id WHERE gtn1.root_id = #gene_tree_id# GROUP BY gtn1.node_id HAVING COUNT(*) NOT IN (0,2)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_no_dangling_node',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_node gtnc ON gtn.node_id = gtnc.parent_id WHERE gtn.root_id = #gene_tree_id# AND gtnc.node_id IS NULL AND gtn.member_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },
    ];
}


sub analysis_tree_attr {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_tree_attributes',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into          => [ 'hc_tree_attr_all_internal', 'hc_tree_attr_no_leaves', 'hc_tree_attr_speciation_is_no_confscore', 'hc_tree_attr_check_confscore', 'hc_tree_support_all_internal' ],
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
        },

        {   -logic_name => 'hc_tree_attr_all_internal',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND (node_type IS NULL OR taxon_id IS NULL OR taxon_name IS NULL)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_attr_no_leaves',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NOT NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_attr_speciation_is_no_confscore',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND (node_type = "speciation" XOR duplication_confidence_score IS NULL)',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_attr_check_confscore',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND ((node_type = "duplication" AND duplication_confidence_score = 0) OR (node_type = "dubious" AND duplication_confidence_score != 0) OR (node_type = "gene_split" AND duplication_confidence_score != 1))',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_support_all_internal',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_tag gtnt ON gtn.node_id = gtnt.node_id AND tag = "tree_support" WHERE member_id IS NULL AND tag IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_gene_count',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT root_id FROM gene_tree_node JOIN gene_tree_root_tag USING (root_id) WHERE root_id = #gene_tree_id# AND tag = "gene_count" GROUP BY root_id HAVING COUNT(member_id) != value',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

    ];
}



sub analysis_homologies {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_homologies',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into          => [ 'hc_tree_no_dup_homologies', 'hc_tree_no_null_in_homologies' ],
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
        },

        {   -logic_name => 'hc_tree_no_dup_homologies',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT hm1.member_id, hm2.member_id FROM homology_member hm1 JOIN homology_member hm2 USING (homology_id) JOIN homology h USING (homology_id) WHERE hm1.member_id<hm2.member_id AND tree_node_id = #gene_tree_id# GROUP BY hm1.member_id, hm2.member_id HAVING COUNT(*) > 1',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_no_null_in_homologies',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM homology JOIN homology_member USING (homology_id) WHERE tree_node_id = #gene_tree_id# AND (description IS NULL OR peptide_member_id IS NULL OR cigar_line IS NULL OR LENGTH(cigar_line) = 0 OR perc_id IS NULL OR perc_pos IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into => [ 'hc_tree_homologies_link_to_genes', 'hc_tree_true_one2one' ],
        },

        {   -logic_name => 'hc_tree_homologies_link_to_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM homology JOIN homology_member USING (homology_id) JOIN member USING (member_id) WHERE tree_node_id = #gene_tree_id# AND source_name != "ENSEMBLGENE"',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into => [ 'hc_tree_homologies_link_to_canonical_pep' ],
        },

        {   -logic_name => 'hc_tree_homologies_link_to_canonical_pep',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM homology JOIN homology_member USING (homology_id) JOIN member USING (member_id) WHERE tree_node_id = #gene_tree_id# AND canonical_member_id != peptide_member_id',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_tree_true_one2one',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT hm.member_id FROM homology h JOIN homology_member hm USING (homology_id) WHERE tree_node_id = #gene_tree_id# GROUP BY hm.member_id HAVING COUNT(*)>1 AND GROUP_CONCAT(h.description) LIKE "%one2one%"',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

    ];
}

sub analysis_tree_globally {
    my ($self) = @_;

    return [

        {   -logic_name         => 'hc_factory_global_trees',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -analysis_capacity  => 1,
            -meadow_type        => 'LOCAL',
            -flow_into          => [ 'hc_tree_no_null_root' ],
        },

        {   -logic_name => 'hc_tree_no_null_root',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_node WHERE root_id IS NULL',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into => [ 'hc_tree_rootnode_links_to_rootroot' ],
        },

        {   -logic_name => 'hc_tree_rootnode_links_to_rootroot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT gene_tree_node.root_id, COUNT(*) FROM gene_tree_node LEFT JOIN gene_tree_root USING (root_id) WHERE gene_tree_root.root_id IS NULL GROUP BY gene_tree_node.root_id',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into  => [ 'hc_tree_rootroot_links_to_rootnode' ],
        },

        {   -logic_name => 'hc_tree_rootroot_links_to_rootnode',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_root gtr JOIN gene_tree_node gtn ON gtr.root_id = gtn.node_id WHERE gtr.root_id != gtn.root_id',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -flow_into  => [ 'hc_members_unique_in_clusterset', 'hc_clusterset_is_flat_tree', 'hc_hierarchy_tree_types' ],
        },

        {   -logic_name => 'hc_members_unique_in_clusterset',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT clusterset_id, member_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) GROUP BY clusterset_id, member_id HAVING COUNT(*) > 1',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_clusterset_is_flat_tree',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "clusterset" AND member_id IS NOT NULL AND  NOT( (node_id = root_id AND parent_id IS NULL) OR (node_id != root_id AND parent_id = root_id) )'
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },

        {   -logic_name => 'hc_hierarchy_tree_types',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'inputquery'    => 'SELECT * FROM gene_tree_root gtr1 JOIN gene_tree_node gtn1 USING (root_id) JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id JOIN gene_tree_root gtr2 ON gtr2.root_id = gtn2.root_id WHERE gtr1.clusterset_id != gtr2.clusterset_id OR gtr1.member_type != gt2.member_type OR gtr1.method_link_species_set_id != gtr2.method_link_species_set_id OR NOT ( (gtr1.tree_type = "clusterset" AND gtr2.tree_type = "supertree") OR (gtr1.tree_type = "supertree" AND gtr2.tree_type = "tree") )'
            },
            -analysis_capacity  => $self->o('hc_capacity'),
        },
    ];
}

1;

