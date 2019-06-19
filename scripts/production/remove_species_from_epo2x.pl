#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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


use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ( $help, $species_name, $reg_conf, $compara_db, $mlss_id );
GetOptions(
    "help"           => \$help,
    "species_name=s" => \$species_name,
    "reg_conf=s"     => \$reg_conf,
    "compara_db=s"   => \$compara_db,
    "mlss_id=s"      => \$mlss_id,
);

die &helptext if ( $help || !$compara_db );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($species_name);

print STDERR "removing all $species_name genomic_align entries..\n";
my $delete_alns_for_species_sql = "DELETE a, t 
FROM genomic_align a JOIN genomic_align_tree t JOIN dnafrag d JOIN genomic_align_block b
WHERE a.node_id = t.node_id AND a.dnafrag_id = d.dnafrag_id AND a.genomic_align_block_id 
= b.genomic_align_block_id AND d.genome_db_id = ?";
$delete_alns_for_species_sql .= " AND b.method_link_species_set_id = $mlss_id" if defined $mlss_id;

my $delete_alns_for_species_sth = $compara_dba->dbc->prepare($delete_alns_for_species_sql);
my $entries_deleted = $delete_alns_for_species_sth->execute($genome_db->dbID);
print STDERR " -- removed $entries_deleted entries!\n";

print STDERR "detecting defunct genomic_align_trees with too few leaves..\n";
my $trees_to_delete_sql = "SELECT root_id FROM genomic_align_tree GROUP BY root_id HAVING count(*) < 3";
$trees_to_delete_sql =~ s/GROUP/WHERE LEFT(root_id, 4) = '$mlss_id' GROUP/ if defined $mlss_id;
my $trees_to_delete_sth = $compara_dba->dbc->prepare($trees_to_delete_sql);
$trees_to_delete_sth->execute();

my $cleanup_gat_sql = "FROM genomic_align a JOIN genomic_align_tree t JOIN genomic_align_block b
WHERE a.node_id = t.node_id AND a.genomic_align_block_id = b.genomic_align_block_id 
AND t.root_id = ?";
$cleanup_gat_sql .= " AND b.method_link_species_set_id = $mlss_id" if defined $mlss_id;

my $c = 0;
while ( my $gat_root_id = $trees_to_delete_sth->fetchrow_arrayref ) {
    $gat_root_id = $gat_root_id->[0];
    # tables need to be cleaned in specific order to satisfy FK
    my $anything_deleted = 0;
    foreach my $table_id ( 'a', 't', 'b' ) { 
        my $cleanup_gat_sth = $compara_dba->dbc->prepare("DELETE $table_id $cleanup_gat_sql");
        my $rows_affected = $cleanup_gat_sth->execute($gat_root_id);
        $anything_deleted = 1 unless $rows_affected eq '0E0';
    }
    $c++ if $anything_deleted;
}
print " -- cleaned up $c trees!\n\n";

sub helptext {
	my $msg = <<HELPEND;

Usage: remove_species_from_epo2x.pl [options]

    --reg_conf     : registry config file
    --compara_db   : URL or registry alias
    --species_name : production_name of species to remove from alignment
    --mlss_id      : (optional) only delete blocks from this mlss_id

HELPEND
	return $msg;
}
