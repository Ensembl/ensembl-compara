#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');

my $ma = $comparaDBA->get_MemberAdaptor;
my $gene_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
$gene_member->print_member;
printf("  description: %s\n", $gene_member->gene->description);

my $members = $gene_member->get_all_peptide_Members;
printf("fetched %d peptides (translated transcripts) for gene\n", scalar(@$members));

foreach my $m2 (@{$members}) {
  printf("seq_length = %d", $m2->seq_length);
  $m2->print_member;
}

exit(0);

