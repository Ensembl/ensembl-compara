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


#
# This script fetches all the Compara peptide members lying in the first
# 10Mb of the rat chromosome 2, and queries all their homologies with
# human
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = $reg->get_DBAdaptor('Multi', 'compara');
my $homologyDBA = $comparaDBA->get_HomologyAdaptor;

# get GenomeDB for human
my $ratGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("rat");

my $members = $comparaDBA->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($ratGDB, 'ENSEMBLPEP');
my $rat_dnafrag = $comparaDBA->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($ratGDB, 2);

foreach my $pep (@{$members}) {
  next unless($pep->dnafrag_id == $rat_dnafrag->dbID);
  next unless($pep->dnafrag_start < 10000000);
  if($pep->get_Transcript->five_prime_utr) {
    print $pep->gene_member->toString(), "\n";
    my $orths = $homologyDBA->fetch_all_by_Member($pep->gene_member, -TARGET_SPECIES => 'homo_sapiens');
    foreach my $homology (@{$orths}) {
      print $homology->toString(), "\n";
    }
  }
}

