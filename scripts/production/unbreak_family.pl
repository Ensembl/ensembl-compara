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

use strict;
use Bio::SeqIO;
use Getopt::Long;
use Data::Dumper;

#first we need to duplicate the directory 2015-12-18/
#my $unbreaking_file;
#
#GetOptions( 'unbreaking_file=s' => \$unbreaking_file );
#
#unless ($unbreaking_file) {
#    print "\nERROR : must provide a file with the list of families to promote.\n\n";
#    usage();
#}

my $family_to_unbreak      = "PTHR19971";
my $promote_from_path      = "/nfs/production/panda/ensembl/warehouse/compara/hmms/treefam/2014-04-29";
my $promote_to_path        = "/nfs/production/panda/ensembl/warehouse/compara/hmms/treefam/2019-01-02";

my $in_file = Bio::SeqIO->new( -file => "$promote_to_path/globals/con.Fasta", -format => 'fasta' );
my $in_file_old = Bio::SeqIO->new( -file => "$promote_from_path/globals/con.Fasta", -format => 'fasta' );

open my $fh_new, ">", "/nfs/production/panda/ensembl/warehouse/compara/hmms/treefam/con.Fasta.unbroke" || die "Could not open file";

while ( my $seq = $in_file->next_seq() ) {
    my $seq_id = $seq->id;
    if ($seq_id !~ /^$family_to_unbreak/){
        print $fh_new ">$seq_id\n";
        print $fh_new $seq->seq."\n";
    }
}

while ( my $seq = $in_file_old->next_seq() ) {
    my $seq_id = $seq->id;
    if ($seq_id =~ /^$family_to_unbreak/){
        print $fh_new ">$seq_id\n";
        print $fh_new $seq->seq."\n";
    }
}

close($fh_new);

#/nfs/software/ensembl/RHEL7-JUL2017-core2/linuxbrew/bin/makeblastdb -in con.Fasta -dbtype prot
#Building a new DB, current time: 01/03/2019 12:48:12
#New DB name:   con.Fasta
#New DB title:  con.Fasta
#Sequence type: Protein
#Keep Linkouts: T
#Keep MBits: T
#Maximum file size: 1000000000B
#Adding sequences from FASTA; added 128495 sequences in 6.23249 seconds.

