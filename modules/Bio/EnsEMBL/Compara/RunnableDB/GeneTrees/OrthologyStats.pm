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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats

=head1 DESCRIPTION

This runnable will store statistics on a given homology MLSS ID.
For orthologs, it extracts:
 n_${homology_type}_(pairs|groups)
 n_${homology_type}_${genome_db_id}_genes
 avg_${homology_type}_${genome_db_id}_perc_id

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


our $sql_orthologies = '
SELECT description, c1, c2, COUNT(*), SUM(n1), SUM(n2), SUM(nh)/2, SUM(perc_id), SUM(p1), SUM(p2)
FROM (
    SELECT description, gene_tree_node_id,
        SUM(nh) AS nh,
        SUM(perc_id) AS perc_id,
        IF(SUM(genome_db_id=?)=1, "one", "many") AS c1,
        IF(SUM(genome_db_id=?)=1, "one", "many") AS c2,
        SUM(genome_db_id=?) AS n1,
        SUM(genome_db_id=?) AS n2,
        SUM(IF(genome_db_id=?,perc_id,0)) AS p1,
        SUM(IF(genome_db_id=?,perc_id,0)) AS p2
    FROM (
        SELECT homology.description, gene_tree_node_id, gene_member_id, genome_db_id, COUNT(DISTINCT homology_id) AS nh, SUM(perc_id) AS perc_id
        FROM homology JOIN homology_member USING (homology_id) JOIN gene_member USING (gene_member_id)
        WHERE method_link_species_set_id = ? AND biotype_group = "coding"
        GROUP BY homology.description, gene_tree_node_id, gene_member_id, genome_db_id
    ) t1 GROUP BY description, gene_tree_node_id
) te GROUP BY description, c1, c2;
';


sub fetch_input {
    my $self = shift @_;

    my $member_type  = $self->param_required('member_type');
    my $mlss_id      = $self->param_required('homo_mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $genome_dbs   = $mlss->species_set->genome_dbs;

    my $gdb_id_1     = $genome_dbs->[0]->dbID;
    my $gdb_id_2     = $genome_dbs->[1]->dbID;

    my $data = $self->compara_dba->dbc->db_handle->selectall_arrayref($sql_orthologies, undef,
        $gdb_id_1, $gdb_id_2, $gdb_id_1, $gdb_id_2, $gdb_id_1, $gdb_id_2, $mlss_id);
    foreach my $line (@$data) {
        my $homology_type = sprintf('%s_%s-to-%s', $member_type, $line->[1], $line->[2]);
        $mlss->store_tag(sprintf('n_%s_pairs', $homology_type), int($line->[6]));
        $mlss->store_tag(sprintf('n_%s_groups', $homology_type), $line->[3]);
        $mlss->store_tag(sprintf('n_%s_%d_genes', $homology_type, $gdb_id_1), $line->[4]);
        $mlss->store_tag(sprintf('n_%s_%d_genes', $homology_type, $gdb_id_2), $line->[5]);
        $mlss->store_tag(sprintf('avg_%s_%d_perc_id', $homology_type, $gdb_id_1), $line->[8] / $line->[6]);
        $mlss->store_tag(sprintf('avg_%s_%d_perc_id', $homology_type, $gdb_id_2), $line->[9] / $line->[6]);
    }
}


1;
