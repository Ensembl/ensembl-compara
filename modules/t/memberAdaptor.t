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

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::DBSQL::TranslationAdaptor;
use Bio::EnsEMBL::DBSQL::TranscriptAdaptor;

use Bio::EnsEMBL::Test::MultiTestDB;

my $ref_species = "homo_sapiens";
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly($ref_species,$human_assembly);
$hs_gdb->db_adaptor($hs_dba);

is($ref_species, 'homo_sapiens');

my $gm_sql = q/
    SELECT
        *
    FROM
        gene_member
    WHERE
        genome_db_id = 90
    AND
        stable_id = "ENSG00000263163"
/;
my ($g_member_id, $g_stable_id, $g_version, $g_source_name, $g_taxon_id, $g_genome_db_id, $g_biotype, $g_canonical_id, $g_description, $g_dnafrag_id, $g_dnafrag_start, $g_dnafrag_end, $g_dnafrag_strand, $g_display_label) = $compara_dba->dbc->db_handle->selectrow_array($gm_sql);

my $sm_sql = q/
    SELECT
        *
    FROM
        seq_member
    WHERE
        genome_db_id = 90
    AND
        stable_id = "ENSP00000458504"
/;

my $gma = $compara_dba->get_GeneMemberAdaptor;
my $sma = $compara_dba->get_SeqMemberAdaptor;

my ($s_member_id, $s_stable_id, $s_version, $s_source_name, $s_taxon_id, $s_genome_db_id, $s_sequence_id, $s_gene_member_id, $has_transcript_edits, $has_translation_edits, $s_description, $s_dnafrag_id, $s_dnafrag_start, $s_dnafrag_end, $s_dnafrag_strand, $s_display_label) =
        $compara_dba->dbc->db_handle->selectrow_array($sm_sql);

my $gene = $hs_dba->get_GeneAdaptor->fetch_by_stable_id("ENSG00000263163");
my $transcript = $hs_dba->get_TranscriptAdaptor->fetch_by_stable_id("ENST00000575439");
my $exons = $hs_dba->get_ExonAdaptor->fetch_all();
my $rank = 1;
foreach my $exon ( @{$exons} ) {
    if ($exon->dbID < 880283) {
        $transcript->add_Exon($exon, $rank);
        $rank++;
    }
}
my $translation = $hs_dba->get_TranslationAdaptor->fetch_by_Transcript($transcript);

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor", sub {

    isa_ok($gma, 'Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor', "Getting the gene_member adaptor");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::fetch_by_stable_id_GenomeDB gene_member", sub {

    my $g_member = $gma->fetch_by_stable_id_GenomeDB($g_stable_id, $hs_gdb);

    ok( $g_member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor"), "Fetching gene_member by stable_id genomedb is gene_member" );
    is( $g_member->dbID, $g_member_id, "Fetching gene_member by stable_id genomedb dbID" );
    is( $g_member->stable_id, $g_stable_id, "Fetching gene_member by stable_id genomedb stable_id" );
    is( $g_member->version, $g_version, "Fetching gene_member by stable_id genomedb version" );
    is( $g_member->display_label, $g_display_label, "Fetching gene_member by stable_id genomedb display_label" );
    is( $g_member->description, $g_description, "Fetching gene_member by stable_id genomedb description" );
    is( $g_member->source_name, $g_source_name, "Fetching gene_member by stable_id genomedb source_name" );
    is( $g_member->dnafrag_id, $g_dnafrag_id, "Fetching gene_member by stable_id genomedb dnafrag_id" );
    is( $g_member->dnafrag_start, $g_dnafrag_start, "Fetching gene_member by stable_id genomedb dnafrag_start" );
    is( $g_member->dnafrag_end, $g_dnafrag_end, "Fetching gene_member by stable_id genomedb dnafrag_end" );
    is( $g_member->dnafrag_strand, $g_dnafrag_strand, "Fetching gene_member by stable_id genomedb dnafrag_end" );
    is( $g_member->taxon_id, $g_taxon_id, "Fetching gene_member by stable_id genomedb taxon_id" );
    is( $g_member->genome_db_id, $g_genome_db_id, "Fetching gene_member by stable_id genomedb genome_db_id" );
    is( $g_member->canonical_member_id, $g_canonical_id, "Fetching gene_member by stable_id genomedb canonical_member_id" );
    is( $g_member->biotype_group, $g_biotype, "Fetching gene_member by stable_id genomedb canonical_member_id" );

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::fetch_by_Gene gene_member", sub {

    my $g_member = $gma->fetch_by_Gene($gene);

    ok( $g_member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor"), "Fetching gene_member by stable_id genomedb is gene_member" );
    is( $g_member->dbID, $g_member_id, "Fetching gene_member by stable_id genomedb dbID" );
    is( $g_member->stable_id, $g_stable_id, "Fetching gene_member by stable_id genomedb stable_id" );
    is( $g_member->version, $g_version, "Fetching gene_member by stable_id genomedb version" );
    is( $g_member->display_label, $g_display_label, "Fetching gene_member by stable_id genomedb display_label" );
    is( $g_member->description, $g_description, "Fetching gene_member by stable_id genomedb description" );
    is( $g_member->source_name, $g_source_name, "Fetching gene_member by stable_id genomedb source_name" );
    is( $g_member->dnafrag_id, $g_dnafrag_id, "Fetching gene_member by stable_id genomedb dnafrag_id" );
    is( $g_member->dnafrag_start, $g_dnafrag_start, "Fetching gene_member by stable_id genomedb dnafrag_start" );
    is( $g_member->dnafrag_end, $g_dnafrag_end, "Fetching gene_member by stable_id genomedb dnafrag_end" );
    is( $g_member->dnafrag_strand, $g_dnafrag_strand, "Fetching gene_member by stable_id genomedb dnafrag_end" );
    is( $g_member->taxon_id, $g_taxon_id, "Fetching gene_member by stable_id genomedb taxon_id" );
    is( $g_member->genome_db_id, $g_genome_db_id, "Fetching gene_member by stable_id genomedb genome_db_id" );
    is( $g_member->canonical_member_id, $g_canonical_id, "Fetching gene_member by stable_id genomedb canonical_member_id" );
    is( $g_member->biotype_group, $g_biotype, "Fetching gene_member by stable_id genomedb canonical_member_id" );

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor", sub {

    isa_ok($sma, 'Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor', "Getting the seq_member adaptor");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::fetch_by_stable_id_GenomeDB seq_member", sub {

    my $s_member = $sma->fetch_by_stable_id_GenomeDB($s_stable_id, $hs_gdb);

    ok( $s_member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor"), "Fetching seq_member by stable_id genomedb is seq_member" );
    is( $s_member->dbID, $s_member_id, "Fetching seq_member by stable_id genomedb dbID" );
    is( $s_member->stable_id, $s_stable_id, "Fetching seq_member by stable_id genomedb stable_id" );
    is( $s_member->version, $s_version, "Fetching seq_member by stable_id genomedb version" );
    is( $s_member->display_label, $s_display_label, "Fetching seq_member by stable_id genomedb display_label" );
    is( $s_member->source_name, $s_source_name, "Fetching seq_member by stable_id genomedb source_name" );
    is( $s_member->dnafrag_id, $s_dnafrag_id, "Fetching seq_member by stable_id genomedb dnafrag_id" );
    is( $s_member->dnafrag_start, $s_dnafrag_start, "Fetching seq_member by stable_id genomedb dnafrag_start" );
    is( $s_member->dnafrag_end, $s_dnafrag_end, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->dnafrag_strand, $s_dnafrag_strand, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->taxon_id, $s_taxon_id, "Fetching seq_member by stable_id genomedb taxon_id" );
    is( $s_member->genome_db_id, $s_genome_db_id, "Fetching seq_member by stable_id genomedb genome_db_id" );
    is( $s_member->has_transcript_edits, $has_transcript_edits, "Fetching seq_member by stable_id genomedb has_transcript_edits" );
    is( $s_member->has_translation_edits, $has_translation_edits, "Fetching seq_member by stable_id genomedb has_translation_edits" );
    is( $s_member->sequence_id, $s_sequence_id, "Fetching seq_member by stable_id genomedb sequence_id" );
    is( $s_member->gene_member_id, $s_gene_member_id, "Fetching seq_member by stable_id genomedb gene_member_id" );
    is( $s_member->description, $s_description, "Fetching seq_member by stable_id genomedb description" );

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::fetch_by_Transcript seq_member", sub {

    my $s_member = $sma->fetch_by_Transcript($transcript);
    ok( $s_member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor"), "Fetching seq_member by stable_id genomedb is seq_member" );
    is( $s_member->dbID, $s_member_id, "Fetching seq_member by stable_id genomedb dbID" );
    is( $s_member->stable_id, $s_stable_id, "Fetching seq_member by stable_id genomedb stable_id" );
    is( $s_member->version, $s_version, "Fetching seq_member by stable_id genomedb version" );
    is( $s_member->display_label, $s_display_label, "Fetching seq_member by stable_id genomedb display_label" );
    is( $s_member->source_name, $s_source_name, "Fetching seq_member by stable_id genomedb source_name" );
    is( $s_member->dnafrag_id, $s_dnafrag_id, "Fetching seq_member by stable_id genomedb dnafrag_id" );
    is( $s_member->dnafrag_start, $s_dnafrag_start, "Fetching seq_member by stable_id genomedb dnafrag_start" );
    is( $s_member->dnafrag_end, $s_dnafrag_end, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->dnafrag_strand, $s_dnafrag_strand, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->taxon_id, $s_taxon_id, "Fetching seq_member by stable_id genomedb taxon_id" );
    is( $s_member->genome_db_id, $s_genome_db_id, "Fetching seq_member by stable_id genomedb genome_db_id" );
    is( $s_member->has_transcript_edits, $has_transcript_edits, "Fetching seq_member by stable_id genomedb has_transcript_edits" );
    is( $s_member->has_translation_edits, $has_translation_edits, "Fetching seq_member by stable_id genomedb has_translation_edits" );
    is( $s_member->sequence_id, $s_sequence_id, "Fetching seq_member by stable_id genomedb sequence_id" );
    is( $s_member->gene_member_id, $s_gene_member_id, "Fetching seq_member by stable_id genomedb gene_member_id" );
    is( $s_member->description, $s_description, "Fetching seq_member by stable_id genomedb description" );

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor::fetch_by_Translation seq_member", sub {

    my $s_member = $sma->fetch_by_Translation($translation);
    ok( $s_member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor"), "Fetching seq_member by stable_id genomedb is seq_member" );
    is( $s_member->dbID, $s_member_id, "Fetching seq_member by stable_id genomedb dbID" );
    is( $s_member->stable_id, $s_stable_id, "Fetching seq_member by stable_id genomedb stable_id" );
    is( $s_member->version, $s_version, "Fetching seq_member by stable_id genomedb version" );
    is( $s_member->display_label, $s_display_label, "Fetching seq_member by stable_id genomedb display_label" );
    is( $s_member->source_name, $s_source_name, "Fetching seq_member by stable_id genomedb source_name" );
    is( $s_member->dnafrag_id, $s_dnafrag_id, "Fetching seq_member by stable_id genomedb dnafrag_id" );
    is( $s_member->dnafrag_start, $s_dnafrag_start, "Fetching seq_member by stable_id genomedb dnafrag_start" );
    is( $s_member->dnafrag_end, $s_dnafrag_end, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->dnafrag_strand, $s_dnafrag_strand, "Fetching seq_member by stable_id genomedb dnafrag_end" );
    is( $s_member->taxon_id, $s_taxon_id, "Fetching seq_member by stable_id genomedb taxon_id" );
    is( $s_member->genome_db_id, $s_genome_db_id, "Fetching seq_member by stable_id genomedb genome_db_id" );
    is( $s_member->has_transcript_edits, $has_transcript_edits, "Fetching seq_member by stable_id genomedb has_transcript_edits" );
    is( $s_member->has_translation_edits, $has_translation_edits, "Fetching seq_member by stable_id genomedb has_translation_edits" );
    is( $s_member->sequence_id, $s_sequence_id, "Fetching seq_member by stable_id genomedb sequence_id" );
    is( $s_member->gene_member_id, $s_gene_member_id, "Fetching seq_member by stable_id genomedb gene_member_id" );
    is( $s_member->description, $s_description, "Fetching seq_member by stable_id genomedb description" );

    done_testing();
};

done_testing();
