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

# get GenomeDB for human
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("human");

# simple example of getting members, back referencing to core,
# and then back reference again to compara
# not efficient since gene members are stored in compara, but demonstrates
# the connections

my $ma = $comparaDBA->get_MemberAdaptor;
my $m1 = $ma->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
$m1->print_member;

my $members = $ma->fetch_by_source_taxon("ENSEMBLPEP", $humanGDB->taxon_id);
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

exit(0);

