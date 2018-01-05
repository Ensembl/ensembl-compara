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
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Utils::IO qw (slurp);
use File::Temp qw/tempfile/;

#
#~/src/ensembl_main/ensembl/modules/t/utilsIo.t
#


# switch on the debug prints
our $verbose = 1;


# Set up some objects 
#

my $dbid = 1;
my $dnafrag_chunk_set_id = 2;
my $seq_start = 1;
my $seq_end = 100;
my $sequence_id = 0; #after insertion of sequence

my $dnafrag_id = 12179427;
my $dnafrag_length = 51304566;
my $dnafrag_name = "22";
my $dnafrag_genome_db_id = 90;
my $dnafrag_coord_system_name = "chromosome";
my $dnafrag_is_reference = 1;

my $small_sequence = "ATTTGCCCTTGCACTTATTTATCTGGATTACTGTCTGCCTGTCCCAAAGAATAAAAGCTTTATCACAGTGGGGACTTTGTTTAAAAAAAAATAATAACGG";

my $sequence = $small_sequence;
my $sequence_length = length $sequence;

my $display_id = "chunkID" . $dbid . ":" . $seq_start . "." . $seq_end;

my $contents = ">" . "$display_id\n";
my $seq = $sequence;
$seq =~ s/(.{60})/$1\n/g;
$seq =~ s/\n$//;
$contents .= $seq . "\n";

my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-dbid => $dnafrag_id,
                                                 -length => $dnafrag_length,
                                                -name => $dnafrag_name,
                                                -genome_db_id => $dnafrag_genome_db_id,
                                                -coord_system_name => $dnafrag_coord_system_name,
                                                -is_reference => $dnafrag_is_reference);

#
# Compiles
#
ok(1);

#
# Create empty DnaFragChunkSet object
#

my $dnafrag_chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk();
isa_ok($dnafrag_chunk, "Bio::EnsEMBL::Compara::Production::DnaFragChunk");

#
# Create non-empty DnaFragChunk object
#

subtest "Test Bio::EnsEMBL::Compara::Production::DnaFragChunk new method", sub {
    my $dnafrag_chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk($dnafrag, $seq_start, $seq_end, $dnafrag_chunk_set_id);
    isa_ok($dnafrag_chunk, "Bio::EnsEMBL::Compara::Production::DnaFragChunk");

    $dnafrag_chunk->dbID($dbid);
    $dnafrag_chunk->sequence($sequence);

    is($dnafrag_chunk->dbID, $dbid, "dbID");
    #ok( test_getter_setter( $dnafrag_chunk, "dbID", $dbid ));   

    is($dnafrag_chunk->dnafrag_chunk_set_id, $dnafrag_chunk_set_id, "dnafrag_chunk_set_id");
    is($dnafrag_chunk->dnafrag_id, $dnafrag_id, "dnafrag_id");
    is($dnafrag_chunk->seq_start, $seq_start, "seq_start");
    is($dnafrag_chunk->seq_end, $seq_end, "seq_end");
    is($dnafrag_chunk->sequence_id, $sequence_id, "sequence_id");
    is($dnafrag_chunk->sequence, $sequence, "sequence");
    is($dnafrag_chunk->length, $sequence_length, "length");
    is($dnafrag_chunk->display_id, $display_id, "display_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::Production::DnaFragChunk dump_to_fasta_file", sub {
    my $dnafrag_chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk($dnafrag, $seq_start, $seq_end, $dnafrag_chunk_set_id);
    $dnafrag_chunk->dbID($dbid);
    $dnafrag_chunk->sequence($sequence);

    my ($tmp_fh, $file) = tempfile();
    $dnafrag_chunk->dump_to_fasta_file($file);

    my $written_contents = slurp($file);
    is ($contents, $written_contents, 'Contents should be the same');
    unlink $file;
    done_testing();
};

#maybe want to try a larger file here
subtest "Test Bio::EnsEMBL::Compara::Production::DnaFragChunk dump_chunks_to_fasta_file", sub {
    my $dnafrag_chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk($dnafrag, $seq_start, $seq_end, $dnafrag_chunk_set_id);
    $dnafrag_chunk->dbID($dbid);
    $dnafrag_chunk->sequence($sequence);

    my ($tmp_fh, $file) = tempfile();
    $dnafrag_chunk->dump_to_fasta_file($file);

    my $written_contents = slurp($file);
    is ($contents, $written_contents, 'Contents should be the same');
    unlink $file;

    done_testing();
};

#Not sure how to do these
#bioseq
#fetch_masked_sequence
#cache_sequence

#my $masked_seq = $dnafrag_chunk->fetch_masked_sequence();
#print "$masked_seq\n";

done_testing();
