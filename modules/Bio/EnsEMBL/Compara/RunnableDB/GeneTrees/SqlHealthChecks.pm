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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks.

=head1 DESCRIPTION

    This runnable offers various groups of healthchecks to check
    the integrity of a gene-tree / homology database.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');



our $config = {

    ### Species Tree
    #################

    species_tree => {
        params => [ 'species_tree_root_id', 'binary', 'n_missing_species_in_tree' ],
        tests => [
            {
                description => 'genome_db_id can only be populated on leaves',
                query => 'SELECT stn.*, COUNT(*) AS n_children FROM species_tree_node stn JOIN species_tree_node stnc ON stnc.parent_id = stn.node_id WHERE stn.root_id = #species_tree_root_id# AND stn.genome_db_id IS NOT NULL GROUP BY stn.node_id'
            },
            {
                description => 'All the leaves of the species tree should have a genome_db',
                query => 'SELECT stn.* FROM species_tree_node stn LEFT JOIN species_tree_node stnc ON stnc.parent_id = stn.node_id WHERE stn.root_id = #species_tree_root_id# AND stnc.node_id IS NULL AND stn.genome_db_id IS NULL'
            },
            {
                description => 'All the genome_dbs should be in the species tree',
                query => 'SELECT gdb.* FROM genome_db gdb LEFT JOIN species_tree_node stn ON gdb.genome_db_id = stn.genome_db_id AND stn.root_id = #species_tree_root_id# WHERE gdb.name != "ancestral_sequences" AND stn.node_id IS NULL',
                expected_size => '= #n_missing_species_in_tree#',
            },
            {
                description => 'Checks that the species tree is minimized (i.e. nodes cannot have a single child)',
                query => 'SELECT stn1.node_id FROM species_tree_node stn1 JOIN species_tree_node stn2 ON stn1.node_id = stn2.parent_id WHERE stn1.root_id = #species_tree_root_id# GROUP BY stn1.node_id HAVING COUNT(*) = 1',
            },
            {
                description => 'Checks that the species tree is binary',
                query => 'SELECT stn1.node_id FROM species_tree_node stn1 JOIN species_tree_node stn2 ON stn1.node_id = stn2.parent_id WHERE stn1.root_id = #species_tree_root_id# GROUP BY stn1.node_id HAVING COUNT(*) > 2 AND #binary#',
            },
        ],
    },

    ### Members
    #############

    members_per_genome => {
        params => [ 'genome_db_id', 'allow_ambiguity_codes', 'allow_missing_coordinates', 'allow_missing_cds_seqs', 'only_canonical' ],
        tests => [
            {
                description => 'Each genome should have some genes',
                query => 'SELECT gene_member_id FROM gene_member WHERE genome_db_id = #genome_db_id#',
                expected_size => '> 0',
            },
            {
                description => 'Each genome should have some seq_member',
                query => 'SELECT seq_member_id FROM seq_member WHERE genome_db_id = #genome_db_id#',
                expected_size => '> 0',
            },
            {
                description => 'Each peptide / transcript should be attached to a gene',
                query => 'SELECT mp.seq_member_id FROM seq_member mp WHERE mp.genome_db_id = #genome_db_id# AND gene_member_id IS NULL',
            },
            {
                description => 'Each gene should have a canonical peptide / transcript',
                query => 'SELECT mg.gene_member_id FROM gene_member mg LEFT JOIN seq_member mp ON mg.canonical_member_id = mp.seq_member_id WHERE mg.genome_db_id = #genome_db_id# AND mp.seq_member_id IS NULL',
            },
            {
                description => 'Canonical members should belong to their genes (circular references)',
                query => 'SELECT mg.gene_member_id, mg.canonical_member_id, mp.gene_member_id FROM gene_member mg JOIN seq_member mp ON mg.canonical_member_id = mp.seq_member_id WHERE mg.genome_db_id = #genome_db_id# AND mp.gene_member_id != mg.gene_member_id',
            },
            {
                description => 'Peptides and transcripts should have sequences',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND (sequence IS NULL OR LENGTH(sequence) = 0)',
            },
            {
                description => 'Peptides should have CDS sequences (which are made of only ACGTN). Ambiguity codes have to be explicitely switched on.',
                query => 'SELECT mp.seq_member_id FROM seq_member mp LEFT JOIN other_member_sequence oms ON mp.seq_member_id = oms.seq_member_id AND oms.seq_type = "cds" WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%PEP" AND (sequence IS NULL OR LENGTH(sequence) = 0 OR (sequence REGEXP "[^ACGTN]" AND NOT #allow_ambiguity_codes#) OR (sequence REGEXP "[^ACGTNKMRSWYVHDB]")) AND NOT #allow_missing_cds_seqs# AND stable_id NOT LIKE "LRG%"',
            },
            {
                description => 'The protein sequences should not be only ACGTN (unless a few exceptions like some immunoglobulin genes)',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%PEP" AND sequence REGEXP "^[ACGTN]*$"',
                expected_size => '< 10',
            },
            {
                description => 'The ncRNA sequences have to be only ACGTN. Ambiguity codes have to be explicitly switched on',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%TRANS" AND ((sequence REGEXP "[^ACGTN]" AND NOT #allow_ambiguity_codes#) OR (sequence REGEXP "[^ACGTNKMRSWYVHDB]"))',
            },
            {
                description => 'ncRNA sequences cannot be entirely made of N',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%TRANS" AND (sequence REGEXP "^N*$")',
            },
            {
                description => 'protein sequences cannot be entirely made of X',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN sequence USING (sequence_id) WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%PEP" AND (sequence REGEXP "^X*$")',
            },
            {
                description => 'CDS sequences cannot be entirely made of N',
                query => 'SELECT mp.seq_member_id FROM seq_member mp JOIN other_member_sequence oms ON mp.seq_member_id = oms.seq_member_id AND oms.seq_type = "cds" WHERE genome_db_id = #genome_db_id# AND source_name LIKE "%PEP" AND (sequence REGEXP "^N*$")',
            },
            {
                description => 'GeneMembers should have chromosome coordinates',
                query => 'SELECT gene_member_id FROM gene_member WHERE genome_db_id = #genome_db_id# AND (dnafrag_id IS NULL OR dnafrag_start IS NULL OR dnafrag_end IS NULL) AND NOT #allow_missing_coordinates#',
            },
            {
                description => 'GeneMembers should map to a dnafrag of their own species',
                query => 'SELECT gene_member_id FROM gene_member LEFT JOIN dnafrag USING (dnafrag_id) WHERE gene_member.genome_db_id = #genome_db_id# AND (dnafrag.dnafrag_id IS NULL OR gene_member.genome_db_id != dnafrag.genome_db_id) AND NOT #allow_missing_coordinates#',
            },
            {
                description => 'GeneMembers should have the same taxonomy ID as their genomeDB',
                query => 'SELECT gene_member_id FROM gene_member JOIN genome_db USING (genome_db_id) WHERE genome_db_id = #genome_db_id# AND gene_member.taxon_id != genome_db.taxon_id',
            },
            {
                description => 'SeqMembers should have chromosome coordinates',
                query => 'SELECT seq_member_id FROM seq_member WHERE genome_db_id = #genome_db_id# AND (dnafrag_id IS NULL OR dnafrag_start IS NULL OR dnafrag_end IS NULL) AND NOT #allow_missing_coordinates#',
            },
            {
                description => 'SeqMembers should map to a dnafrag of their own species',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN dnafrag USING (dnafrag_id) WHERE seq_member.genome_db_id = #genome_db_id# AND (dnafrag.dnafrag_id IS NULL OR seq_member.genome_db_id != dnafrag.genome_db_id) AND NOT #allow_missing_coordinates#',
            },
            {
                description => 'SeqMembers should have the same taxonomy ID as their genomeDB',
                query => 'SELECT seq_member_id FROM seq_member JOIN genome_db USING (genome_db_id) WHERE genome_db_id = #genome_db_id# AND seq_member.taxon_id != genome_db.taxon_id',
            },
            {
                description => 'only canonical SeqMembers are in the database#expr(#only_canonical# ? "" : " [SKIPPED]")expr#',
                query => 'SELECT seq_member_id FROM seq_member LEFT JOIN gene_member ON seq_member_id = canonical_member_id WHERE #only_canonical# AND gene_member.gene_member_id IS NULL',
            }
        ],
    },


    members_globally => {
        tests => [
            {
                description => 'All the gene_members should have a genome_db_id',
                query => 'SELECT gene_member_id FROM gene_member WHERE genome_db_id IS NULL',
            },
            {
                description => 'All the seq_members should have a genome_db_id',
                query => 'SELECT seq_member_id FROM seq_member WHERE genome_db_id IS NULL AND source_name NOT LIKE "Uniprot%"',
            },
        ],
    },


    stable_id_mapping => {
        tests => [
            {
                description => 'There are stable IDs coming from at least 2 releases (Have you configured "mapping_db" correctly ?)',
                query => 'SELECT DISTINCT LEFT(stable_id, 9) AS prefix FROM gene_tree_root WHERE stable_id IS NOT NULL',
                expected_size => '>= 2',
            },
        ],
    },


    ### EPO Removed members
    #########################

     epo_removed_members => {
                             params => [ 'gene_tree_id' ],
                             tests => [
                                       {
                                        description => 'All the removed members should not be in the clusters anymore',
                                        query       => 'SELECT gtn.node_id, gtn.root_id, gtn.seq_member_id, gtb.root_id FROM gene_tree_backup gtb JOIN gene_tree_node gtn USING (seq_member_id) WHERE gtn.root_id = #gene_tree_id# AND is_removed = 1;',
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
            {
                description => 'Each target member must be associated to a single target species',
                query => 'SELECT hmember_id FROM peptide_align_feature_#genome_db_id# GROUP BY hmember_id HAVING COUNT(DISTINCT hgenome_db_id) > 1',
            }
        ],
    },



    ### Alignments
    #################

    alignment => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'Checks that the tree has an alignment',
                query => 'SELECT * FROM gene_tree_root WHERE root_id = #gene_tree_id# AND gene_align_id IS NULL',
            },
            {
                description => 'Checks that the alignment exists',
                query => 'SELECT * FROM gene_tree_root JOIN gene_align USING (gene_align_id) WHERE root_id = #gene_tree_id#',
                expected_size => '=1',
            },
            {
                description => 'Checks that the alignment has defined CIGAR lines',
                query => 'SELECT * FROM gene_tree_root JOIN gene_align_member USING (gene_align_id) WHERE root_id = #gene_tree_id# AND (cigar_line IS NULL OR LENGTH(cigar_line) = 0)',
            },
            {
                description => 'Checks that the alignment has not lost any genes since the backup',
                query => 'SELECT gene_tree_backup.seq_member_id FROM gene_tree_backup JOIN gene_tree_root USING (root_id) LEFT JOIN gene_align_member USING (gene_align_id, seq_member_id) WHERE root_id = #gene_tree_id# AND gene_align_member.seq_member_id IS NULL AND is_removed = 0',
            },
            {
                description => 'Checks that the alignment has not gained any genes since the backup',
                query => 'SELECT gene_align_member.seq_member_id FROM gene_tree_backup JOIN gene_tree_root USING (root_id) RIGHT JOIN gene_align_member USING (gene_align_id, seq_member_id) WHERE root_id = #gene_tree_id# AND gene_tree_backup.seq_member_id IS NULL',
            },
        ],
    },

    unpaired_alignment => {
        params => [ 'gene_tree_id', 'gene_align_id' ],
        tests => [
            {
                description => 'Checks that the alignment exists',
                query => 'SELECT * FROM gene_align WHERE gene_align_id = #gene_align_id#',
                expected_size => '=1',
            },
            {
                description => 'Checks that the alignment has defined CIGAR lines',
                query => 'SELECT * FROM gene_align_member WHERE gene_align_id = #gene_align_id# AND (cigar_line IS NULL OR LENGTH(cigar_line) = 0)',
            },
            {
                description => 'Checks that the alignment has not lost any genes since the backup',
                query => 'SELECT gene_tree_backup.seq_member_id FROM gene_tree_backup LEFT JOIN gene_align_member USING (seq_member_id) WHERE gene_align_id = #gene_align_id# AND root_id = #gene_tree_id# AND gene_align_member.seq_member_id IS NULL AND is_removed = 0',
            },
            {
                description => 'Checks that the alignment has not gained any genes since the backup',
                query => 'SELECT gene_align_member.seq_member_id FROM gene_tree_backup RIGHT JOIN gene_align_member USING (seq_member_id) WHERE gene_align_id = #gene_align_id# AND root_id = #gene_tree_id# AND gene_tree_backup.seq_member_id IS NULL',
            },
        ],
    },




    ### Tree structure
    ####################

    tree_structure => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'Checks that the gene tree is binary (and minimized)',
                query => 'SELECT gtn1.node_id FROM gene_tree_root gtr JOIN gene_tree_node gtn1 ON gtr.root_id=gtn1.node_id JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id WHERE gtn1.root_id = #gene_tree_id# GROUP BY clusterset_id, gtn1.root_id, gtn1.node_id HAVING COUNT(*) != IF(gtn1.node_id!=gtn1.root_id OR clusterset_id IN ("default","murinae") OR clusterset_id LIKE "nj-%" OR clusterset_id LIKE "mur\_nj-%" OR clusterset_id LIKE "phyml-%" OR clusterset_id LIKE "mur\_phyml-%" OR clusterset_id LIKE "rax%" OR clusterset_id LIKE "notung%" OR clusterset_id LIKE "treerecs%" OR clusterset_id LIKE "mur_rax%" OR clusterset_id LIKE "pg\_%" OR clusterset_id LIKE "mur\_pg\_%",2, IF(COUNT(*) = 2 AND COUNT(gtn2.seq_member_id) = 2, 2, 3) )',
            },

            {
                description => 'Checks that the leaves all are members',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn LEFT JOIN gene_tree_node gtnc ON gtn.node_id = gtnc.parent_id WHERE gtn.root_id = #gene_tree_id# AND gtnc.node_id IS NULL AND gtn.seq_member_id IS NULL',
            },

            {
                description => 'Checks that the "tree_num_leaves" tags agree with the actual number of members in the tree',
                query => 'SELECT root_id, COUNT(seq_member_id) AS real_count, tree_num_leaves FROM gene_tree_node JOIN gene_tree_root_attr USING (root_id) WHERE root_id = #gene_tree_id# GROUP BY root_id HAVING real_count != tree_num_leaves',
            },
            {
                description => 'Checks that right_index-left_index is not greater than 1 only on leaves',
                query => 'SELECT * FROM gene_tree_node gtn LEFT JOIN gene_tree_node gtn2 ON (gtn.node_id = gtn2.parent_id) WHERE gtn2.node_id IS NULL AND (gtn.right_index - gtn.left_index) > 1 AND gtn.root_id = #gene_tree_id#',
            },
            {
                description => 'Checks that right_index-left_index is not equal to 1 on internal nodes',
                query => 'SELECT * FROM gene_tree_node gtn LEFT JOIN gene_tree_node gtn2 ON (gtn.node_id = gtn2.parent_id) WHERE gtn2.node_id IS NOT NULL AND (gtn.right_index - gtn.left_index) = 1 AND gtn.root_id = #gene_tree_id#',
            }
        ],
    },

    tree_content => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'Checks that the tree has not lost any genes since the backup',
                query => 'SELECT gtb.seq_member_id FROM gene_tree_backup gtb LEFT JOIN gene_tree_node gtn USING (root_id, seq_member_id) WHERE gtb.root_id = #gene_tree_id# AND gtn.seq_member_id IS NULL AND is_removed = 0',
            },
            {
                description => 'Checks that the tree has not gained any genes since the backup',
                query => 'SELECT gene_tree_node.seq_member_id FROM gene_tree_node LEFT JOIN gene_tree_backup USING (root_id, seq_member_id) WHERE root_id = #gene_tree_id# AND gene_tree_node.seq_member_id IS NOT NULL AND gene_tree_backup.seq_member_id IS NULL',
            },
            {
                description => 'All the species a tree contains must be part of the MethodLinkSpeciesSet',
                query => 'SELECT gene_tree_node.*, seq_member.genome_db_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN seq_member USING (seq_member_id) JOIN method_link_species_set USING (method_link_species_set_id) LEFT JOIN species_set USING (species_set_id, genome_db_id) WHERE species_set.species_set_id IS NULL AND root_id = #gene_tree_id#',
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
                query => 'SELECT gtn.node_id FROM gene_tree_root gtr JOIN gene_tree_node gtn USING (root_id) LEFT JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND seq_member_id IS NULL AND (node_type IS NULL OR (species_tree_node_id IS NULL AND clusterset_id NOT LIKE "ftga\_%" AND clusterset_id NOT LIKE "mur\_ftga\_%" AND clusterset_id NOT LIKE "ml\_it\_%" AND clusterset_id NOT LIKE "mur\_ml\_it\_%" AND clusterset_id NOT IN ("pg_it_phyml", "mur_pg_it_phyml", "ft_it_ml", "mur_ft_it_ml") AND clusterset_id NOT LIKE "ss\_it\_%" AND clusterset_id NOT LIKE "mur\_ss\_it\_%" ))',
            },
            {
                description => 'Leaves should not have attributes',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND seq_member_id IS NOT NULL',
            },
            {
                description => 'The "speciation" node_type is exclusive from having a duplication_confidence_score (which should only be for duplications, etc)',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND seq_member_id IS NULL AND (node_type = "speciation" XOR duplication_confidence_score IS NULL)',
            },
            {
                description => 'A duplication confidence score of 0 is equivalent to having a "dubious" type, whilst "gene_split" nodes can only have a score of 1',
                query => 'SELECT gtn.node_id FROM gene_tree_node gtn JOIN gene_tree_node_attr gtna USING (node_id) WHERE gtn.root_id = #gene_tree_id# AND seq_member_id IS NULL AND ((node_type = "duplication" AND duplication_confidence_score = 0) OR (node_type = "dubious" AND duplication_confidence_score != 0) OR (node_type = "gene_split" AND duplication_confidence_score != 1))',
            },
            ## TODO: add something to test the presence of tree_support
            #{
                #description => '"tree_support" tags must be present at all internal nodes',
                #query => 'SELECT gene_tree_node.*, COUNT(value) FROM gene_tree_node LEFT JOIN gene_tree_node_tag ON gene_tree_node.node_id = gene_tree_node_tag.node_id AND tag = "tree_support" WHERE root_id = #gene_tree_id# GROUP BY gene_tree_node.node_id HAVING (seq_member_id IS NULL) XOR (COUNT(value) > 0)',
            #},
        ],
    },

    ### Supertrees
    ################

    supertrees => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'The "gene_count" tags must sum-up to the super-tree\'s',
                query => 'SELECT COUNT(*), gtra1.gene_count, SUM(gtra2.gene_count) FROM (gene_tree_node gtn1 JOIN gene_tree_root_attr gtra1 USING (root_id))  JOIN gene_tree_node gtn2 ON gtn2.parent_id = gtn1.node_id AND gtn2.root_id != gtn1.root_id JOIN gene_tree_root_attr gtra2 ON gtra2.root_id=gtn2.root_id WHERE gtn1.root_id = #gene_tree_id# HAVING gtra1.gene_count != SUM(gtra2.gene_count)',
            },
        ],
    },

    ### Homologies derived from the trees
    #######################################

    tree_homologies => {
        params => [ 'gene_tree_id' ],
        tests => [
            {
                description => 'A pair of gene can only appear in 1 homology at most',
                query => 'SELECT hm1.gene_member_id, hm2.gene_member_id FROM homology_member hm1 JOIN homology_member hm2 USING (homology_id) JOIN homology h USING (homology_id) WHERE hm1.gene_member_id < hm2.gene_member_id AND gene_tree_root_id = #gene_tree_id# GROUP BY hm1.gene_member_id, hm2.gene_member_id HAVING COUNT(*) > 1',
            },
            {
                description => 'Checks that all the relevant fields of the homology table are non-NULL or non-zero',
                query => 'SELECT * FROM homology JOIN homology_member USING (homology_id) WHERE gene_tree_root_id = #gene_tree_id# AND (description IS NULL OR seq_member_id IS NULL OR cigar_line IS NULL OR LENGTH(cigar_line) = 0 OR perc_id IS NULL OR perc_pos IS NULL)',
            },
            {
                description => 'Checks that the seq_member_id column of the homology_member table only links to canonical peptides',
                query => 'SELECT * FROM homology JOIN homology_member hm USING (homology_id) JOIN gene_member gm USING (gene_member_id) WHERE gene_tree_root_id = #gene_tree_id# AND gm.canonical_member_id != hm.seq_member_id',
            },
        ],
    },


    ### Global properties of the tree set
    #######################################

    global_tree_set => {
        tests => [
            {
                description => 'Clusters should only contain canonical members',
                query => 'SELECT * FROM gene_tree_node gtn LEFT JOIN gene_member mg ON gtn.seq_member_id = mg.canonical_member_id WHERE gtn.seq_member_id IS NOT NULL AND mg.gene_member_id IS NULL',
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
                query => 'SELECT clusterset_id, seq_member_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE seq_member_id IS NOT NULL GROUP BY clusterset_id, seq_member_id HAVING COUNT(*) > 1',
            },

            {
                description => 'The clusterset tree should be flat',
                query => 'SELECT * FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = "clusterset" AND seq_member_id IS NOT NULL AND  NOT( (node_id = root_id AND parent_id IS NULL) OR (node_id != root_id AND parent_id = root_id) )',
            },

            {
                description => 'The hierarchy of tree types should be: "clusterset" > ("supertree" >) "tree"',
                query => 'SELECT gtr1.root_id, gtr2.root_id FROM gene_tree_root gtr1 JOIN gene_tree_node gtn1 USING (root_id) JOIN gene_tree_node gtn2 ON gtn1.node_id = gtn2.parent_id JOIN gene_tree_root gtr2 ON gtr2.root_id = gtn2.root_id WHERE gtr1.root_id != gtr2.root_id AND (gtr1.clusterset_id != gtr2.clusterset_id OR gtr1.member_type != gtr2.member_type OR gtr1.method_link_species_set_id != gtr2.method_link_species_set_id OR NOT ( (gtr1.tree_type = "clusterset" AND gtr2.tree_type = "supertree") OR (gtr1.tree_type = "supertree" AND gtr2.tree_type = "tree") OR (gtr1.tree_type = "clusterset" AND gtr2.tree_type = "tree") ))'
            },

            {
                description => 'The "gene_count" tags of sub-trees must sum-up to their super-tree\'s gene count',
                query => 'SELECT gtr1.root_id, COUNT(*), gtra1.gene_count, SUM(gtra2.gene_count) FROM (gene_tree_root gtr1 JOIN gene_tree_node gtn1 USING (root_id) JOIN gene_tree_root_attr gtra1 USING (root_id)) JOIN gene_tree_node gtn2 ON gtn2.parent_id = gtn1.node_id AND gtn2.root_id != gtn1.root_id JOIN gene_tree_root_attr gtra2 ON gtra2.root_id=gtn2.root_id WHERE tree_type = "supertree" AND clusterset_id IN ("default","murinae") GROUP BY gtr1.root_id HAVING gtra1.gene_count != SUM(gtra2.gene_count)',
            },
        ],
    },


    ### Homology dN/dS step
    #########################

    homology_dnds => {
        params => [ 'homo_mlss_id' ],
        tests => [
            {
                description => 'In the homology table, each method_link_species_set_id should have some entries with values of "n" and "s"',
                query => 'SELECT * FROM homology WHERE method_link_species_set_id = #homo_mlss_id# AND n IS NOT NULL AND s IS NOT NULL',
                expected_size => '> 0',
            },
        ],
    },


    ### CAFE's output
    ###################

    cafe => {
        params => [ 'cafe_tree_label' ],
        tests => [
            {
                description => 'There are some CAFE families',
                query => 'SELECT * FROM CAFE_gene_family',
                expected_size => '> 0',
            },

            {
                description => 'CAFE_gene_family.root_id links to a tree with the correct label',
                query => 'SELECT * FROM CAFE_gene_family JOIN species_tree_root USING (root_id) WHERE label != "#cafe_tree_label#"',
            },

            {
                description => 'CAFE_gene_family.lca_id links to a node of its tree',
                query => 'SELECT * FROM CAFE_gene_family JOIN species_tree_node ON lca_id = node_id  WHERE CAFE_gene_family.root_id != species_tree_node.root_id',
            },

            {
                description => 'All the trees have at least one pvalue',
                query => 'SELECT * FROM CAFE_species_gene GROUP BY cafe_gene_family_id HAVING COUNT(pvalue) = 0',
            },

            {
                description => 'There are some (very) significant p-values',
                query => 'SELECT * FROM CAFE_species_gene WHERE pvalue IS NOT NULL ANd pvalue < 0.001',
                expected_size => '> 0',
            },

            {
                description => 'There are some non-significant p-values',
                query => 'SELECT * FROM CAFE_species_gene WHERE pvalue IS NOT NULL ANd pvalue >= 0.05',
                expected_size => '> 0',
            },

            {
                description => 'All the trees have at least one node with a non-zero member count',
                query => 'SELECT * FROM CAFE_species_gene GROUP BY cafe_gene_family_id HAVING SUM(n_members > 0) = 0',
            },

            {
                description => 'Some nodes have n_members=0',
                query => 'SELECT * FROM CAFE_species_gene WHERE n_members = 0',
                expected_size => '> 0',
            },

            {
                description => 'All the combinations of (CAFE_gene_family.cafe_gene_family_id,species_tree_node.node_id) are in CAFE_species_gene',
                query => 'SELECT * FROM CAFE_gene_family JOIN species_tree_node USING (root_id) LEFT JOIN CAFE_species_gene USING (cafe_gene_family_id,node_id) WHERE CAFE_species_gene.cafe_gene_family_id IS NULL;',
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


sub _embedded_call {
    my $self = shift;
    my $test_name = shift;
    $self->param('tests', $config->{$test_name}->{tests});
    Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck::_validate_tests($self);
    my $failures = 0;
    foreach my $test (@{ $self->param('tests') }) {
        if (not Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck::_run_test($self, $test)) {
            $failures++;
            $self->warning(sprintf("The following test has failed: %s\n   > %s\n", $test->{description}, $test->{subst_query}));
        }
    }
    die "$failures HCs failed.\n" if $failures;
}


1;

