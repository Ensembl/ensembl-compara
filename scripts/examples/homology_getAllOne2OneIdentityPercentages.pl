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


#
# This script queries the Compara database to fetch all the one2one
# homologies, and prints the percentage of identity with the alignment
# length
#

use Bio::EnsEMBL::Registry;

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $gene_member_adaptor = $comparaDBA->get_GeneMemberAdaptor;
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');

foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);

  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    next unless ($description =~ /one2one/); # if only one2one wanted
    foreach my $member (@{$this_homology->get_all_GeneMembers}) {
      my $label = $member->display_label || $member->stable_id;
      print $member->genome_db->get_short_name, ",", $label, "\t";
    }
    my $pairwise_alignment_from_multiple = $this_homology->get_SimpleAlign;
    my $overall_pid = $pairwise_alignment_from_multiple->overall_percentage_identity;
    print sprintf("%0.3f",$overall_pid),"%, ";
    print $pairwise_alignment_from_multiple->length;
    print "bp\n";
  }
}

