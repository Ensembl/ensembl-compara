=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks.

=head1 DESCRIPTION

    This runnable offers various groups of healthchecks to check
    the integrity of a gene-tree / homology database.

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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');



my $config = {


    ### Members
    #############

    members_per_genome => {
        params => [ 'genome_db_id', 'hc_member_type' ],
        tests => [
            {
                description => 'Each genome should have some members of the two types: ENSEMBLGENE and #hc_member_type#',
                query => 'SELECT source_name FROM member WHERE genome_db_id = #genome_db_id# AND source_name IN ("#hc_member_type#", "ENSEMBLGENE") GROUP BY source_name HAVING COUNT(*) > 0',
                expected_size => '= 2',
            },
            {
                description => 'Each peptide / transcript should be attached to a gene member',
                query => 'SELECT mp.member_id FROM member mp WHERE mp.genome_db_id = #genome_db_id# AND mp.source_name="#hc_member_type#" AND gene_member_id IS NULL',
            },
            {
                description => 'Each gene should have a canonical peptide / transcript',
                query => 'SELECT mg.member_id FROM member mg LEFT JOIN member mp ON mg.canonical_member_id = mp.member_id WHERE mg.genome_db_id = #genome_db_id# AND mg.source_name = "ENSEMBLGENE" AND mp.member_id IS NULL',
            },
            {
                description => 'Canonical members should belong to their genes (circular references)',
                query => 'SELECT mg.member_id, mg.canonical_member_id, mp.gene_member_id FROM member mg JOIN member mp ON mg.canonical_member_id = mp.member_id WHERE mg.genome_db_id = #genome_db_id# AND mg.source_name = "ENSEMBLGENE" AND mp.gene_member_id != mg.member_id',
            },
            {
                description => 'Peptides and transcripts should have sequences',
                query => 'SELECT member_id FROM member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name = "#hc_member_type#" AND (sequence IS NULL OR LENGTH(sequence) = 0)',
            },
            {
                description => 'Peptides should have CDS sequences (which are made of only ACGTN)',
                query => 'SELECT mp.member_id FROM member mp LEFT JOIN other_member_sequence oms ON mp.member_id = oms.member_id AND oms.seq_type = "cds" WHERE genome_db_id = #genome_db_id# AND source_name = "ENSEMBLPEP" AND (sequence IS NULL OR LENGTH(sequence) = 0 OR sequence REGEXP "[^ACGTN]")',
            },
            {
                description => 'The protein sequences should not be only ACGTN (unless 5aa-long, for an immunoglobulin gene)',
                query => 'SELECT member_id FROM member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name = "ENSEMBLPEP" AND sequence REGEXP "^[ACGTN]*$" AND LENGTH(sequence) > 5',
            },
            {
                description => 'Members should have chromosome coordinates',
                query => 'SELECT member_id FROM member WHERE genome_db_id = #genome_db_id# AND (chr_name IS NULL OR chr_start IS NULL OR chr_end IS NULL)',
            },
            {
                description => 'Members should have the same taxonomy ID as their genomeDB',
                query => 'SELECT member_id FROM member JOIN genome_db USING (genome_db_id) WHERE genome_db_id = #genome_db_id# AND member.taxon_id != genome_db.taxon_id',
            }
        ],
    },


    members_globally => {
        tests => [
            {
                description => 'All the members should have a genome_db_id',
                query => 'SELECT member_id FROM member WHERE genome_db_id IS NULL',
            },
        ],
    },



    ### Blast hits
    ###############

    peptide_align_features => {
        params => [ 'genome_db_id', 'species_count' ],
        tests => [
            {
                description => 'Each species should have hits against all the other species',
                query => 'SELECT DISTINCT hgenome_db_id FROM peptide_align_feature_#genome_db_id#',
                expected_size => '= #species_count#',
            },
        ],
    },



    ### Alignments
    #################

    alignment => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                ## FIXME: only for protein trees
                description => 'Checks that the tree has not lost any genes since the backup',
                query => 'SELECT protein_tree_backup.member_id FROM protein_tree_backup LEFT JOIN gene_tree_node USING (root_id, member_id) WHERE root_id = #gene_tree_id# AND gene_tree_node.member_id IS NULL',
            },
            {
                ## FIXME: only for protein trees
                description => 'Checks that the tree has not gained any genes since the backup',
                query => 'SELECT gene_tree_node.member_id FROM gene_tree_node LEFT JOIN protein_tree_backup USING (root_id, member_id) WHERE root_id = #gene_tree_id# AND gene_tree_node.member_id IS NOT NULL AND protein_tree_backup.member_id IS NULL',
            },
            {
                description => 'Checks that the tree has an alignment',
                query => 'SELECT * FROM gene_tree_root WHERE root_id = #gene_tree_id# AND gene_align_id IS NULL',
            },
            {
                description => 'Checks that the alignment has defined CIGAR lines',
                query => 'SELECT * FROM gene_tree_root JOIN gene_align_member USING (gene_align_id) WHERE root_id = #gene_tree_id# AND (cigar_line IS NULL OR LENGTH(cigar_line) = 0)',
            },
            {
                ## FIXME: only for protein trees
                description => 'Checks that the alignment has not lost any genes since the backup',
                query => 'SELECT protein_tree_backup.member_id FROM protein_tree_backup JOIN gene_tree_root USING (root_id) LEFT JOIN gene_align_member USING (gene_align_id, member_id) WHERE root_id = #gene_tree_id# AND gene_align_member.member_id IS NULL',
            },
            {
                ## FIXME: only for protein trees
                description => 'Checks that the alignment has not gained any genes since the backup',
                query => 'SELECT gene_align_member.member_id FROM protein_tree_backup JOIN gene_tree_root USING (root_id) RIGHT JOIN gene_align_member USING (gene_align_id, member_id) WHERE root_id = #gene_tree_id# AND protein_tree_backup.member_id IS NULL',
            },
        ],
    },



    ### Tree structure
    ####################

    tree_structure => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'Checks that the gene tree is binary',
                query => 'SELECT gtn1.node_id FROM gene_tree_node gtn1 JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id WHERE gtn1.root_id = #gene_tree_id# GROUP BY gtn1.node_id HAVING COUNT(*) NOT IN (0,2)',
            },

            {
                description => 'Checks that the leaves all are members',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_node gtnc ON gtn.node_id = gtnc.parent_id WHERE gtn.root_id = #gene_tree_id# AND gtnc.node_id IS NULL AND gtn.member_id IS NULL',
            },

            {
                description => 'Checks that the "gene_count" tags agree with the actual number of members in the tree',
                query => 'SELECT root_id, COUNT(member_id) AS count, value FROM gene_tree_node JOIN gene_tree_root_tag USING (root_id) WHERE root_id = #gene_tree_id# AND tag = "gene_count" GROUP BY root_id HAVING count != value',
            },
        ],
    },



    ### Attributes / tags of the gene tree nodes
    ##############################################

    tree_attributes => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'All the internal tree nodes should have a node_type and species tree information',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND (node_type IS NULL OR species_tree_node_id IS NULL)',
            },
            {
                description => 'Leaves should not have attributes',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NOT NULL',
            },
            {
                description => 'The "speciation" node_type is exclusive from having a duplication_confidence_score (which should only be for duplications, etc)',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND (node_type = "speciation" XOR duplication_confidence_score IS NULL)',
            },
            {
                description => 'A duplication confidence score of 0 is equivalent to having a "dubious" type, whilst "gene_split" nodes can only have a score of 1',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND member_id IS NULL AND ((node_type = "duplication" AND duplication_confidence_score = 0) OR (node_type = "dubious" AND duplication_confidence_score != 0) OR (node_type = "gene_split" AND duplication_confidence_score != 1))',
            },
            ## TODO: add something to test the presence of tree_support
        ],
    },



    ### Homologies derived from the trees
    #######################################

    tree_homologies => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'A pair of gene can only appear in 1 homology at most',
                query => 'SELECT hm1.member_id, hm2.member_id FROM homology_member hm1 JOIN homology_member hm2 USING (homology_id) JOIN homology h USING (homology_id) WHERE hm1.member_id<hm2.member_id AND gene_tree_root_id = #gene_tree_id# GROUP BY hm1.member_id, hm2.member_id HAVING COUNT(*) > 1',
            },
            {
                description => 'Checks that all the relevant fields of the homology table are non-NULL or non-zero',
                query => 'SELECT * FROM homology JOIN homology_member USING (homology_id) WHERE gene_tree_root_id = #gene_tree_id# AND (description IS NULL OR peptide_member_id IS NULL OR cigar_line IS NULL OR LENGTH(cigar_line) = 0 OR perc_id IS NULL OR perc_pos IS NULL)',
            },
            {
                description => 'Checks that the member_id column of the homology_member table only links to ENSEMBLGENE members',
                query => 'SELECT * FROM homology JOIN homology_member USING (homology_id) JOIN member USING (member_id) WHERE gene_tree_root_id = #gene_tree_id# AND source_name != "ENSEMBLGENE"',
            },
            {
                description => 'Checks that the peptide_member_id column of the homology_member table only links to canonical peptides',
                query => 'SELECT * FROM homology JOIN homology_member USING (homology_id) JOIN member USING (member_id) WHERE gene_tree_root_id = #gene_tree_id# AND canonical_member_id != peptide_member_id',
            },
            {
                description => 'Checks that the members involved in one2one orthologies are not involved in any other orthologies',
                query => 'SELECT method_link_species_set_id, hm.member_id FROM homology h JOIN homology_member hm USING (homology_id) WHERE gene_tree_root_id = #gene_tree_id# GROUP BY method_link_species_set_id, hm.member_id HAVING COUNT(*)>1 AND GROUP_CONCAT(h.description) LIKE "%one2one%"',
            },

        ],
    },


    ### Global properties of the tree set
    #######################################

    global_tree_set => {
        tests => [
            {
                description => 'Clusters should only contain canonical members',
                query => 'SELECT * FROM gene_tree_node gtn LEFT JOIN member mg ON gtn.member_id = mg.canonical_member_id WHERE gtn.member_id IS NOT NULL AND mg.member_id IS NULL',
            },

            {
                description => 'root_id cannot be NULL in the gene_tree_node table',
                query => 'SELECT * FROM gene_tree_node WHERE root_id IS NULL',
            },

            {
                description => 'root_id in the gene_tree_node table should link to the gene_tree_root table',
                query => 'SELECT gene_tree_node.root_id, COUNT(*) FROM gene_tree_node LEFT JOIN gene_tree_root USING (root_id) WHERE gene_tree_root.root_id IS NULL GROUP BY gene_tree_node.root_id',
            },

            {
                description => 'root_id in the gene_tree_node_table should be the same within each tree, and equal to the node_id of the root node',
                query => 'SELECT * FROM gene_tree_root gtr JOIN gene_tree_node gtn ON gtr.root_id = gtn.node_id WHERE gtr.root_id != gtn.root_id',
            },

            {
                description => 'Members cannot be used more than once in the same clusterset',
                query => 'SELECT clusterset_id, member_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE member_id IS NOT NULL GROUP BY clusterset_id, member_id HAVING COUNT(*) > 1',
            },

            {
                description => 'The clusterset tree should be flat',
                query => 'SELECT * FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "clusterset" AND member_id IS NOT NULL AND  NOT( (node_id = root_id AND parent_id IS NULL) OR (node_id != root_id AND parent_id = root_id) )',
            },

            {
                description => 'The hierarchy of tree types should be: "clusterset" > ("supertree" >) "tree"',
                query => 'SELECT gtr1.root_id, gtr2.root_id FROM gene_tree_root gtr1 JOIN gene_tree_node gtn1 USING (root_id) JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id JOIN gene_tree_root gtr2 ON gtr2.root_id = gtn2.root_id WHERE gtr1.root_id != gtr2.root_id AND (gtr1.clusterset_id != gtr2.clusterset_id OR gtr1.member_type != gtr2.member_type OR gtr1.method_link_species_set_id != gtr2.method_link_species_set_id OR NOT ( (gtr1.tree_type = "clusterset" AND gtr2.tree_type = "supertree") OR (gtr1.tree_type = "supertree" AND gtr2.tree_type = "tree") OR (gtr1.tree_type = "clusterset" AND gtr2.tree_type = "tree") ))'
            },

        ],
    },



    ### Homology dN/dS step
    #########################

    homology_dnds => {
        params => [ 'mlss_id' ],
        tests => [
            {
                description => 'In the homology table, each method_link_species_set_id should have some entries with values of "n" and "s"',
                query => 'SELECT * FROM homology WHERE method_link_species_set_id = #mlss_id# AND n IS NOT NULL AND s IS NOT NULL',
                expected_size => '> 0',
            },
        ],
    },

};


sub fetch_input {
    my $self = shift;

    my $mode = $self->param_required('mode');
    die unless exists $config->{$mode};
    my $this_config = $config->{$mode};

    foreach my $param_name (@{$this_config->{params}}) {
        $self->param_required($param_name);
    }
    $self->param('tests', $this_config->{tests});
    $self->_validate_tests;
}


1;

