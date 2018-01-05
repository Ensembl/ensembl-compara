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
# This script fetches all the peptide reciprocal hits
# with human for a given rat location
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $pafDBA = $comparaDBA-> get_PeptideAlignFeatureAdaptor;

my $humanGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("human");
my $ratGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("rat");

my $members = $comparaDBA->get_GeneMemberAdaptor->fetch_all_by_GenomeDB($ratGDB);
my $rat_dnafrag = $comparaDBA->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($ratGDB, '15');

foreach my $pep (@{$members}) {
  next unless($pep->dnafrag_id == $rat_dnafrag->dbID);
  next unless($pep->dnafrag_start < 4893881 );
  next unless($pep->dnafrag_end > 4883962 );

  print $pep->toString(), "\n";

  my $pafs = $pafDBA->fetch_all_RH_by_member_genomedb($pep->canonical_member_id, $humanGDB->dbID);

  foreach my $paf (@{$pafs}) {
    print $paf->toString, "\n";
    print "  ", $paf->hit_member->gene_member->toString(), "\n";
  }
  print "\n";
}

