#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

=head1 NAME

update_members_e88.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut


use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;

my $help;
my $reg_conf;
my $compara;
my $production_url;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "production_url=s" => \$production_url,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !$reg_conf or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $gene_biotype_sql = q{SELECT name, biotype_group FROM biotype WHERE is_current=1 AND is_dumped = 1 AND object_type = "gene" AND FIND_IN_SET('core', db_type)};
my $production_dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-url => $production_url);
my %biotype_groups = map {$_->[0] => $_->[1]} @{ $production_dbc->db_handle->selectall_arrayref($gene_biotype_sql) };
$production_dbc->disconnect_if_idle();

my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
my $genome_db_adaptor = $compara_db->get_GenomeDBAdaptor();

foreach my $master_genome_db (@{$genome_db_adaptor->fetch_all}) {
    next if $master_genome_db->name eq 'ancestral_sequences';
    my $sql1 = 'UPDATE gene_member SET biotype_group = ? WHERE gene_member_id = ?';
    my $sth1 = $compara_db->prepare($sql1);
    foreach my $gene_member (@{$compara_db->get_GeneMemberAdaptor->fetch_all_by_GenomeDB($master_genome_db)}) {
        $sth1->execute($biotype_groups{$gene_member->get_Gene->biotype}, $gene_member->gene_member_id);
    }
    $sth1->finish;
    my $sql2 = 'UPDATE seq_member SET has_transcript_edits = ?, has_translation_edits = ? WHERE seq_member_id = ?';
    my $sth2 = $compara_db->prepare($sql2);
    foreach my $seq_member (@{$compara_db->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($master_genome_db)}) {
        my $transcript = $seq_member->get_Transcript;
        my $translate = ($transcript->source_name =~ /PEP/);
        my $has_transcript_edits = (scalar(@{$transcript->get_all_SeqEdits('_rna_edit')}) ? 1 : 0);
        my $has_translation_edits= (($translate && scalar(grep {$_->length_diff && length($_->alt_seq)<5} @{$transcript->translation->get_all_SeqEdits('amino_acid_sub')})) ? 1 : 0);
        $sth1->execute($has_transcript_edits, $has_translation_edits, $seq_member->seq_member_id);
    }
    $sth2->finish;
    $master_genome_db->db_adaptor->dbc->disconnect_if_idle;
}

