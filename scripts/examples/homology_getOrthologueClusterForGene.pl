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
# This script gets the orthologue clusters starting from
# a specific gene and following the links (with the API)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $gene_name = shift;
$gene_name="ENSDARG00000052960" unless(defined($gene_name));


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $gene_member = $comparaDBA->get_GeneMemberAdaptor->fetch_by_stable_id($gene_name);
my ($homologies, $genes) = $comparaDBA->get_HomologyAdaptor->fetch_orthocluster_with_Member($gene_member);

foreach my $homology (@$homologies) {
  print $homology->toString();
}
foreach my $member (@$genes) {
  print $member->toString();
}

printf("cluster has %d links\n", scalar(@$homologies));
printf("cluster has %d genes\n", scalar(@$genes));

