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
my $homologyDBA = Bio::EnsEMBL::Registry->get_adaptor('compara', 'compara', 'Homology');

# get GenomeDB for human
my $ratGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("rat");

my $members = $comparaDBA->get_MemberAdaptor->fetch_by_source_taxon(
  'ENSEMBLPEP', $ratGDB->taxon_id);

foreach my $pep (@{$members}) {
  next unless($pep->chr_name eq '2');
  next unless($pep->chr_start < 10000000);
  if($pep->get_Transcript->five_prime_utr) {
    $pep->gene_member->print_member;
    my $orths = $homologyDBA->fetch_by_Member_paired_species($pep->gene_member, 'Homo sapiens');
    foreach my $homology (@{$orths}) {
      $homology->print_homology;
    }
  }
}

exit(0);

