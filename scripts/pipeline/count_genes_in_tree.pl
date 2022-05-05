#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

count_genes_in_tree.pl

=head1 DESCRIPTION

Calculates the number of genes in the given genome that have been assigned
to a gene tree in the gene-tree collection associated with the given MLSS.
The number of unassigned genes is also calculated. Both values are stored
as a tag for the relevant species-tree node in the given Compara database.

=head1 SYNOPSIS

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/count_genes_in_tree.pl \
        --url <db_url> --genome_db_id <genome_db_id> --mlss_id <mlss_id>

=head1 EXAMPLES

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/count_genes_in_tree.pl \
        --url mysql://ensadmin:xxxxx@mysql-ens-compara-prod-0:65536/jo_default_plants_protein_trees_107 \
        --genome_db_id 421 --mlss_id 40160

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url gene_tree_db_url]>

Gene-tree database URL.

=item B<[--genome_db_id genome_db_id]>

Genome DB ID of the relevant organism.

=item B<[--mlss_id mlss_id]>

MLSS ID of the relevant gene tree.

=back

=cut


use strict;
use warnings;

use DBI;
use Getopt::Long;
use JSON qw(encode_json);
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


my ( $help, $url, $genome_db_id, $mlss_id );
GetOptions(
    "help|?"         => \$help,
    "url=s"          => \$url,
    "genome_db_id=i" => \$genome_db_id,
    "mlss_id=i"      => \$mlss_id,
) or pod2usage(-verbose => 2);

# Handle "print usage" scenarios
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$url or !$genome_db_id or !$mlss_id;


my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);

my $gene_member_dba = $dba->get_GeneMemberAdaptor();
my $nb_genes = scalar @{ $gene_member_dba->fetch_all_by_GenomeDB($genome_db_id) };
my $nb_genes_in_tree = count_genes_in_tree($dba, $genome_db_id, $mlss_id);
my $nb_genes_unassigned = $nb_genes - $nb_genes_in_tree;

my $tree_dba = $dba->get_SpeciesTreeAdaptor();
my $species_tree = $tree_dba->fetch_by_method_link_species_set_id_label($mlss_id, 'default');
my $species_tree_node = $species_tree->root->find_leaves_by_field('genome_db_id', $genome_db_id)->[0];
$species_tree_node->store_tag('nb_genes_in_tree', $nb_genes_in_tree);
$species_tree_node->store_tag('nb_genes_unassigned', $nb_genes_unassigned);


sub count_genes_in_tree {
    my ($dba, $genome_db_id, $mlss_id) = @_;

    my $sql = q/
        SELECT
            COUNT(*)
        FROM
            gene_member gm
                LEFT JOIN
            gene_tree_node gtn ON (gm.canonical_member_id = gtn.seq_member_id)
                INNER JOIN
            gene_tree_root gtr USING (root_id)
        WHERE
            gm.genome_db_id = ?
            AND gtr.method_link_species_set_id = ?
            AND gtr.ref_root_id IS NULL
            AND gtn.seq_member_id IS NOT NULL
    /;

    my $sth = $dba->dbc->prepare($sql);
    $sth->execute($genome_db_id, $mlss_id);
    my $nb_genes_in_tree = $sth->fetchrow();
    $sth->finish();

    return $nb_genes_in_tree;
}
