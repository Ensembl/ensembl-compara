#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch a gene and its canonical
# translation (brute force version)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get GenomeDB for human
my $genomedb_adaptor = $reg->get_adaptor('Multi', 'compara', 'GenomeDB');
my $humanGDB = $genomedb_adaptor->fetch_by_registry_name("human");

# simple example of getting members, back referencing to core,
# and then back reference again to compara
# not efficient since gene members are stored in compara, but demonstrates
# the connections

my $member_adaptor = $reg->get_adaptor('Multi', 'compara', 'Member');
my $m1 = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
$m1->print_member;

my $members = $member_adaptor->fetch_by_source_taxon("ENSEMBLPEP", $humanGDB->taxon_id);
printf("fetched %d members\n", scalar(@$members));

foreach my $m2 (@{$members}) {
  next unless($m2->chr_name eq $m1->chr_name);
  my $gene = $m2->get_Gene;
  if($m1->stable_id eq $gene->stable_id) {
    printf("%s : %s %d-%d\n", $m2->stable_id, $m2->chr_name, $m2->chr_start, $m2->chr_end);
    print("MATCHED ", $m2->get_Gene->stable_id, " ", $m2->get_Gene, "\n");
    print("        ", $m2->get_Transcript->stable_id, " ", $m2->get_Transcript, "\n");
    print("        ", $m2->get_Translation->stable_id, " ", $m2->get_Translation, "\n");
    last;
  }
}

