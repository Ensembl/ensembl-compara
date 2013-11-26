#!/usr/bin/env perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

my $members = $comparaDBA->get_SeqMemberAdaptor->fetch_all_by_source_taxon(
  'ENSEMBLPEP', $ratGDB->taxon_id);

foreach my $pep (@{$members}) {
  next unless($pep->chr_name eq '2');
  next unless($pep->dnafrag_start < 10000000);
  if($pep->get_Transcript->five_prime_utr) {
    $pep->gene_member->print_member;
    my $orths = $homologyDBA->fetch_all_by_Member_paired_species($pep->gene_member, 'homo_sapiens');
    foreach my $homology (@{$orths}) {
      $homology->print_homology;
    }
  }
}

