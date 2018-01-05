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
# This script gets all the GenomicAlignBlocks covering the orthologues
# between human and mouse (via DnaDnaAlignFeature)
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
    printf("fetch_all_by_species_region(%s,%s,%s,%s,%s,%d,%s)\n",
            $other_member->genome_db->name, $other_member->genome_db->assembly,
            $one_member->genome_db->name, $one_member->genome_db->assembly,
            $other_member->dnafrag->name, $other_member->dnafrag_start, $other_member->dnafrag_end,
            'LASTZ_NET');


    my $dnafeatures = $comparaDBA->get_DnaAlignFeatureAdaptor->fetch_all_by_species_region(
            $other_member->genome_db->name, $other_member->genome_db->assembly,
            $one_member->genome_db->name, $one_member->genome_db->assembly,
            $other_member->dnafrag->name, $other_member->dnafrag_start, $other_member->dnafrag_end,
            'LASTZ_NET');

    foreach my $ddaf (@{$dnafeatures}) {
        next unless (($other_member->dnafrag->name eq $ddaf->seqname) and ($one_member->dnafrag->name eq $ddaf->hseqname));

        print "=====================================================\n";
        print " length: ", $ddaf->alignment_length, "; score: ", $ddaf->score, "\n";
        print "  - ", join(" : ", $ddaf->species, $ddaf->coord_system_name,
            $ddaf->seqname, $ddaf->start, $ddaf->end, $ddaf->strand), "\n";
        print "  - ", join(" : ", $ddaf->hspecies, $ddaf->coord_system_name,
            $ddaf->hseqname, $ddaf->hstart, $ddaf->hend, $ddaf->hstrand), "\n";
        print $alignIO $ddaf->get_SimpleAlign;
    }
    last if($count > 10);
}

