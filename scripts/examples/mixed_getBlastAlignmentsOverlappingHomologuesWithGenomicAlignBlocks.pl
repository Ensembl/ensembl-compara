#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Registry;
use Bio::AlignIO;


#
# This script gets all the LASTZ alignments covering the orthologues
# between human and mouse (via GenomicAlignBlocks)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'compara');

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $human_gdb_id = $humanGDB->dbID;
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $mouse_gdb_id = $mouseGDB->dbID;

# get MethodLinkSpeciesSet for LASTZ_NET alignments between human and mouse
my $blastz_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_GenomeDBs("LASTZ_NET", [$humanGDB, $mouseGDB]);

my $homology_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $homology_list = $comparaDBA->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($homology_mlss);
printf("fetched %d homologies\n", scalar(@$homology_list));

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved=>1, -fh=>\*STDOUT, -format=>'psi', -idlength=>20);


my $count=0;
foreach my $homology (@{$homology_list}) {
    $count++;
    $homology->print_homology;

    my $human_gene = undef;
    my $mouse_gene = undef;
    foreach my $member(@{$homology->get_all_Members}) {
        if($member->genome_db_id == $mouse_gdb_id) { $mouse_gene = $member; }
        if($member->genome_db_id == $human_gdb_id) { $human_gene = $member; }
    }
    next unless($mouse_gene and $human_gene);
    $mouse_gene->print_member;
    $human_gene->print_member;

    my $dnafrag = $mouse_gene->dnafrag;
    unless($dnafrag) { print("oops no dnafrag\n"); next; }

# get the alignments on a piece of the DnaFrag
    my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( $blastz_mlss, $dnafrag, $mouse_gene->dnafrag_start, $mouse_gene->dnafrag_end);

    foreach my $gab (@{$genomic_align_blocks}) {
        my $all_genomic_aligns = $gab->get_all_GenomicAligns();
        my $valid = 1;
        foreach my $ga (@$all_genomic_aligns) {
            $valid = 0 if (($ga->dnafrag->genome_db->dbID == $human_gdb_id) and ($ga->dnafrag->name ne $human_gene->dnafrag->name));
            $valid = 0 if (($ga->dnafrag->genome_db->dbID == $mouse_gdb_id) and ($ga->dnafrag->name ne $mouse_gene->dnafrag->name));
        }
        next unless ($valid);

        print "Bio::EnsEMBL::Compara::GenomicAlignBlock #", $gab->dbID, "\n";
        print "=====================================================\n";
        print " length: ", $gab->length, "; score: ", $gab->score, "\n";
        foreach my $ga (@$all_genomic_aligns) {
            print "  - ", join(" : ", $ga->dnafrag->genome_db->name, $ga->dnafrag->coord_system_name,
                $ga->dnafrag->name, $ga->dnafrag_start, $ga->dnafrag_end, $ga->dnafrag_strand), "\n";
        }
        print $alignIO $gab->get_SimpleAlign;
    }
    last if($count > 10);
}

