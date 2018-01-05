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


#
# This script computes dn/ds values for pairs of homologues, when it hasn't
# been done by Compara
#


my ($input,$species2,$debug);

GetOptions(
        'i|input:s' => \$input,
        'sp2|species2:s' => \$species2,
        'd|debug:s' => \$debug,
);

my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_db(
    -host=>"ensembldb.ensembl.org", 
    -user=>"anonymous",
);
$reg->no_version_check(1) unless ($debug);

my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

my $bioperl_dnastats = 0;
eval {require Bio::Align::DNAStatistics;};
unless ($@) { $bioperl_dnastats = 1; }

$input = 'ENSG00000139618:ENSG00000073910' unless (defined $input and length($input) > 1);
my $result = undef;

print "spa,labela,spb,labelb,dn,ds\n";
foreach my $gene_id (split(':',$input)) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene_id);
  next unless (defined($member));
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member, -TARGET_SPECIES => $species2);
  next unless (defined($all_homologies));

  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    # next unless ($description =~ /para/);    # uncomment for paralogues only
    # next unless ($description =~ /orth/);    # uncomment for orthologs only
    # next unless ($description =~ /one2one/); # uncomment for one2one orthologs only
    my ($a,$b) = @{$this_homology->gene_list};
    my $spa = $a->taxon->get_short_name;
    my $spb = $b->taxon->get_short_name;
    my $labela = $a->stable_id;
    $labela .= "(" . $a->display_label . ")" if $a->display_label;
    my $labelb = $b->stable_id;
    $labelb .= "(" . $b->display_label . ")" if $b->display_label;
    my $dn; my $ds;
    my $lnl = $this_homology->lnl;
    if ($lnl) {
        $dn = $this_homology->dn;
        $ds = $this_homology->ds;
    } else {
        # This bit calculates dnds values using the counting method in bioperl-run
        my $aln = $this_homology->get_SimpleAlign( -seq_type => 'cds');
        if ($bioperl_dnastats) {
            my $stats;
            eval { $stats = new Bio::Align::DNAStatistics;};
            if($stats->can('calc_KaKs_pair')) {
                my ($seq1id,$seq2id) = map { $_->display_id } $aln->each_seq;
                my $results;
                print ">";
                eval { $results = $stats->calc_KaKs_pair($aln, $seq1id, $seq2id);};
                unless ($@) {
                  my $counting_method_dn = $results->[0]{D_n};
                  my $counting_method_ds = $results->[0]{D_s};
                  $dn = $counting_method_dn;
                  $ds = $counting_method_ds;
                }
            }
        }
        ##
    }
    $dn = 'na' if (!defined($dn));
    $ds = 'na' if (!defined($ds));
    print "$spa,$labela,$spb,$labelb,$dn,$ds\n";
  }
}

