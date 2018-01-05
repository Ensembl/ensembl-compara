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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;

# switch on the debug prints
our $verbose = 1;


#
# Set up some objects 
#

my $dbid = 2;
my $dna_collection_id = 1;

my $seq_start = 1;
my $seq_end = 100;

my $dnafrag_id = 12179427;
my $dnafrag_length = 51304566;
my $dnafrag_name = "22";
my $dnafrag_genome_db_id = 90;
my $dnafrag_coord_system_name = "chromosome";
my $dnafrag_is_reference = 1;

my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-dbid => $dnafrag_id,
                                                 -length => $dnafrag_length,
                                                -name => $dnafrag_name,
                                                -genome_db_id => $dnafrag_genome_db_id,
                                                -coord_system_name => $dnafrag_coord_system_name,
                                                -is_reference => $dnafrag_is_reference);

my @dnafrag_chunks;

push @dnafrag_chunks, (new Bio::EnsEMBL::Compara::Production::DnaFragChunk($dnafrag, $seq_start, $seq_end));
push @dnafrag_chunks, (new Bio::EnsEMBL::Compara::Production::DnaFragChunk($dnafrag, ($seq_end+1), ($seq_end*2)));

my $total_basepairs = ($seq_end-$seq_start+1)*2;

#
# Compiles
#
ok(1);

#
# Create empty DnaFragChunkSet object
#

my $dnafrag_chunk_set = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet();
isa_ok($dnafrag_chunk_set, "Bio::EnsEMBL::Compara::Production::DnaFragChunkSet");

#
# Create non-empty DnaFragChunkSet object
#

subtest "Test Bio::EnsEMBL::Compara::Production::DnaFragChunkSet new method", sub {
    my $dnafrag_chunk_set = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet(-dbid => $dbid,
                                                                                   -dna_collection_id => $dna_collection_id);

    isa_ok($dnafrag_chunk_set, "Bio::EnsEMBL::Compara::Production::DnaFragChunkSet");
    is($dnafrag_chunk_set->dbID, $dbid, "dbID");
    is($dnafrag_chunk_set->dna_collection_id, $dna_collection_id, "dna_collection_id");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::Production::DnaFragChunkSet add_DnaFragChunk and get_all_DnaFragChunks", sub {
    my $dnafrag_chunk_set = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet(-dbid => $dbid,
                                                                                   -dna_collection_id => $dna_collection_id);

    $dnafrag_chunk_set->add_DnaFragChunk($dnafrag_chunks[0]);

    is($dnafrag_chunk_set->total_basepairs(), ($seq_end-$seq_start+1), "total_basepairs1"); 

    $dnafrag_chunk_set->add_DnaFragChunk($dnafrag_chunks[1]);
    
    is($dnafrag_chunk_set->total_basepairs(), $total_basepairs, "total_basepairs2"); 


    #Test Bio::EnsEMBL::Compara::Production::DnaFragChunkSet get_all_DnaFragChunks
    my $chunks = $dnafrag_chunk_set->get_all_DnaFragChunks();
    ok (scalar @$chunks == 2);

    for (my $i=0; $i < @$chunks; $i++) {
        is ($chunks->[$i], $dnafrag_chunks[$i], "Chunk $i should be the same");
    }
    
    done_testing();
};

done_testing();
