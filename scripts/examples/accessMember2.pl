#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch a gene and all its translations
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $member_adaptor = $reg->get_adaptor('Multi', 'compara', 'Member');
my $gene_member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
$gene_member->print_member;
printf("  description: %s\n", $gene_member->gene->description);

my $members = $gene_member->get_all_peptide_Members;
printf("fetched %d peptides (translated transcripts) for gene\n", scalar(@$members));

foreach my $m2 (@{$members}) {
  printf("seq_length = %d", $m2->seq_length);
  $m2->print_member;
}

