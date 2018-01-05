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

my $sp1 = "human";
my $sp2 = "mouse";

# get MethodLinkSpeciesSet for LASTZ_NET alignments between human and mouse
my $blastz_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_registry_aliases("LASTZ_NET", [$sp1, $sp2]);
# get MethodLinkSpeciesSet for orthologies alignments between human and mouse
my $homology_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_registry_aliases("ENSEMBL_ORTHOLOGUES", [$sp1, $sp2]);

my $homology_list = $comparaDBA->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($homology_mlss);
printf("fetched %d homologies\n", scalar(@$homology_list));

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved=>1, -fh=>\*STDOUT, -format=>'psi', -idlength=>20);


my $count=0;
foreach my $homology (@{$homology_list}) {
    $count++;
    print $homology->toString;

    foreach my $member (sort {$a->genome_db_id <=> $b->genome_db_id} @{$homology->get_all_Members}) {
        print $member->toString(), "\n";
    }

    my $one_member = $homology->get_all_Members->[0];
    my $other_member = $homology->get_all_Members->[1];

    # get the alignments on a piece of the DnaFrag
    my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( $blastz_mlss, $one_member->dnafrag, $one_member->dnafrag_start, $one_member->dnafrag_end);

    foreach my $gab (@{$genomic_align_blocks}) {
        my $all_genomic_aligns = $gab->get_all_GenomicAligns();
        my $valid = 1;
        foreach my $ga (@$all_genomic_aligns) {
            foreach my $member (@{$homology->get_all_Members}) {
                $valid = 0 if (($ga->dnafrag->genome_db->dbID == $member->genome_db_id) and ($ga->dnafrag->name ne $member->dnafrag->name));
            }
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

