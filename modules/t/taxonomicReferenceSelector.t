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
 
use Test::More tests => 4;
use Test::Exception;
use Cwd 'abs_path';
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector;

use_ok('Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector');

#####################################################################
##        Set up test database and add to the registry             ##

my $test_query_compara = Bio::EnsEMBL::Test::MultiTestDB->new( "homology_annotation" );
my $query_compara_dba  = $test_query_compara->get_DBAdaptor( "compara" );

my $test_ref_compara = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_compara" );
my $ref_compara_dba  = $test_ref_compara->get_DBAdaptor( "compara" );

#####################################################################
##                         Reuse Variables                         ##

my $query_genome_db_id = 135;
my @species_sets       = ('collection-actinopterygii', 'collection-default', 'collection-mammalia', 'collection-sauropsida');
my @taxon_list         = ('actinopterygii', 'default', 'mammalia', 'sauropsida');
my $taxon_name         = 'collection-mammalia';
my $ref_dump_dir       = abs_path($0);
$ref_dump_dir          =~ s/taxonomicReferenceSelector\.t/homology_annotation_dirs/;
my @file_dir_suffixes  = ('.fa', '.split', 'dmnd');

my $human_gdb = $ref_compara_dba->get_GenomeDBAdaptor->fetch_by_dbID(1);
my $rat_gdb   = $ref_compara_dba->get_GenomeDBAdaptor->fetch_by_dbID(3);
my @genome_files;

foreach my $gdb ($human_gdb, $rat_gdb) {
    my $file_prefix = $gdb->name . '.' . $gdb->assembly . '.' .  $gdb->genebuild;
    my $fasta_file  = $ref_dump_dir . '/' . $file_prefix . '.fasta';
    my $ref_dmnd    = $ref_dump_dir . '/' . $file_prefix . '.dmnd';
    my $ref_splitfa = $ref_dump_dir . '/' . $file_prefix . '.split';
    push @genome_files => { 'ref_gdb' => $gdb, 'ref_fa' => $fasta_file, 'ref_dmnd' => $ref_dmnd, 'ref_splitfa' => $ref_splitfa };
}

#####################################################################
##                        Start testing...                         ##

note("------------------------ collect_reference_classification testing ---------------------------------");

subtest 'collect_reference_classification' => sub {
    my $ref_taxa_list;
    ok($ref_taxa_list = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::collect_reference_classification($ref_compara_dba));
    is_deeply(
        $ref_taxa_list,
        \@taxon_list,
        'ArrayRef contains all the correct values'
    );

};

note("------------------------ match_query_to_reference_taxonomy testing --------------------------------");

subtest 'match_query_to_reference_taxonomy' => sub {
    my $genome_db = $query_compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($query_genome_db_id);
    my $taxon_match;
    # test without @taxon_list
    ok($taxon_match = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::match_query_to_reference_taxonomy($genome_db, $ref_compara_dba));
    is($taxon_match, $taxon_name, 'reference_db taxon matched successfully');

    # test with @taxon_list
    ok($taxon_match = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::match_query_to_reference_taxonomy($genome_db, undef, \@taxon_list));
    is($taxon_match, $taxon_name, 'taxon_list taxon matched successfully');

    # test with both @taxon_list and $reference_dba
    throws_ok {
        $taxon_match = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::match_query_to_reference_taxonomy($genome_db, $ref_compara_dba, \@taxon_list)
    } qr/taxon_list and reference_dba are mutually exclusive, pick one/, 'no matching when there are multiple taxon sources';

    # test with neither @taxon_list or $reference_dba
    throws_ok {
        $taxon_match = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::match_query_to_reference_taxonomy($genome_db)
    } qr/Either taxon_list or reference_dba need to be provided/, 'no matching if no taxon sources to match to';
};

note("--------------------------- collect_species_set_dirs testing ------------------------------------");

subtest 'collect_species_set_dirs' => sub {
    my $ref_paths;
    ok($ref_paths = Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector::collect_species_set_dirs($ref_compara_dba, $taxon_name, $ref_dump_dir));
    is_deeply(
        $ref_paths,
        \@genome_files,
        'the reference file locations match'
    );
};

done_testing();
