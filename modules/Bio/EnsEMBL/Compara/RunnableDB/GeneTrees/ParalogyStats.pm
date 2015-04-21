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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats

=head1 DESCRIPTION

This runnable will store statistics on a given paralogy MLSS ID
both globally and at the species-tree-node level:
 n_{$homology_type}_groups
 n_{$homology_type}_pairs
 n_{$homology_type}_genes
 avg_{$homology_type}_perc_id

Note that for a given gene-tree, the number of groups would be 1,
and the number of pairs: n_genes*(n_genes-1)/2. But here, numbers
are aggregated over many gene-trees, so the formula does not apply
any more.

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


our $sql_paralogies = '
SELECT description, COUNT(*) AS ngr, SUM(nh), SUM(ng), SUM(perc_id)/SUM(2*nh)
FROM (
    SELECT description, gene_tree_root_id, COUNT(DISTINCT homology_id) AS nh, COUNT(DISTINCT seq_member_id) AS ng, SUM(perc_id) AS perc_id
    FROM homology JOIN homology_member USING (homology_id)
    WHERE method_link_species_set_id = ?
    GROUP BY description, gene_tree_root_id
) t GROUP BY description;
';

our $sql_paralogies_taxon = $sql_paralogies;
$sql_paralogies_taxon =~ s/description/description, species_tree_node_id/g;


sub fetch_input {
    my $self = shift @_;

    my $mlss_id      = $self->param_required('homo_mlss_id');
    my $mlss         = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $genome_dbs   = $mlss->species_set_obj->genome_dbs;

    my $species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param('mlss_id'), 'default');
    my %hash_stn_id  = map {$_->dbID => $_} @{$species_tree->root->get_all_nodes()};

    my $data1 = $self->compara_dba->dbc->db_handle->selectall_arrayref($sql_paralogies, undef, $mlss_id);
    foreach my $line (@$data1) {
        $mlss->store_tag(sprintf('n_%s_groups', $line->[0]), $line->[1]);
        $mlss->store_tag(sprintf('n_%s_pairs', $line->[0]), $line->[2]);
        $mlss->store_tag(sprintf('n_%s_genes', $line->[0]), $line->[3]);
        $mlss->store_tag(sprintf('avg_%s_perc_id', $line->[0]), $line->[4]);
    }

    my $data2 = $self->compara_dba->dbc->db_handle->selectall_arrayref($sql_paralogies_taxon, undef, $mlss_id);
    foreach my $line (@$data2) {
        my $stn = $hash_stn_id{$line->[1]};
        $stn->store_tag(sprintf('n_%s_groups', $line->[0]), $line->[2]);
        $stn->store_tag(sprintf('n_%s_pairs', $line->[0]), $line->[3]);
        $stn->store_tag(sprintf('n_%s_genes', $line->[0]), $line->[4]);
        $stn->store_tag(sprintf('avg_%s_perc_id', $line->[0]), $line->[5]);
    }
}


1;
