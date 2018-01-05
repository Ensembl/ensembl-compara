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

use Test::More;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');

##
#####################################################################

#
# Compiles
#
ok(1);

my $dbID = 1;
my $taxon_id = 9606;
my $name = "homo_sapiens";
my $taxon_name = "Homo sapiens";
my $assembly = "GRCh37";
my $genebuild = "2010-07-Ensembl";

subtest "Test Bio::EnsEMBL::Compara::GenomeDB new(void)", sub {

    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
    isa_ok($genome_db, "Bio::EnsEMBL::Compara::GenomeDB", "check object");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB new(ALL) method", sub {
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(
                                                         -dbID => $dbID,
                                                         -db_adaptor => $hs_dba,
                                                         -name => $name,
                                                         -assembly => $assembly,
                                                         -taxon_id => $taxon_id,
                                                         -genebuild => $genebuild
                                                        );

    $genome_db->adaptor($genome_db_adaptor);

    is($genome_db->db_adaptor, $hs_dba, "Testing dba set in new method");
    is($genome_db->name, $name, "Testing name set in new method");
    is($genome_db->assembly, $assembly, "Testing assembly set in new method");
    is($genome_db->taxon_id, $taxon_id, "Testing taxon_id set in new method");
    is($genome_db->dbID, $dbID, "Testing dbID set in new method");
    is($genome_db->genebuild, $genebuild, "Testing genebuild set in new method");

    is($genome_db->taxon->name, $taxon_name);
    done_testing();
};

#Test new_fast method
subtest "Test Bio::EnsEMBL::Compara::GenomeDB new_fast method", sub {
    my $genome_db_hash;
    %$genome_db_hash = ('adaptor' => $genome_db_adaptor,
                        '_db_adaptor' => $hs_dba,
                        'name'       => $name,
                        'assembly'   => $assembly,
                        '_taxon_id'  => $taxon_id,
                        'dbID'       => $dbID,
                        'genebuild'  => $genebuild);
    
    my $genome_db = new_fast Bio::EnsEMBL::Compara::GenomeDB($genome_db_hash);
    
    is($genome_db->db_adaptor, $hs_dba, "Testing dba set in new method");
    is($genome_db->name, $name, "Testing name set in new method");
    is($genome_db->assembly, $assembly, "Testing assembly set in new method");
    is($genome_db->taxon_id, $taxon_id, "Testing taxon_id set in new method");
    is($genome_db->dbID, $dbID, "Testing dbID set in new method");
    is($genome_db->genebuild, $genebuild, "Testing genebuild set in new method");
    
    is($genome_db->taxon->name, $taxon_name);
    done_testing();
};

done_testing();
