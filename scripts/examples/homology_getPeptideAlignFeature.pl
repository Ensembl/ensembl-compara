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
use Getopt::Long;

## Load the registry automatically
my $reg = 'Bio::EnsEMBL::Registry';
$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous',
);

my $gene_stable_id = "ENSG00000060069";

my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'GeneMember');
my $gene_member = $gene_member_adaptor->fetch_by_stable_id($gene_stable_id);
my $peptide_member = $gene_member->get_canonical_SeqMember;
print "QUERY PEP: ", $peptide_member->toString(), "\n";

my $peptide_align_feature_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'PeptideAlignFeature');
my $peptide_align_features = $peptide_align_feature_adaptor->fetch_all_RH_by_member($peptide_member->dbID);

# loop through and print
foreach my $this_peptide_align_feature (@{$peptide_align_features}) {
  print $this_peptide_align_feature->toString(), "\n";
}

