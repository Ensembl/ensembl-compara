#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script fetches all the Compara peptide members lying in the first
# 10Mb of the rat chromosome 2, and queries all their homologies with
# human
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = $reg->get_DBAdaptor('compara', 'compara');
my $homologyDBA = $comparaDBA->get_HomologyAdaptor;

# get GenomeDB for human
my $ratGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("rat");

my $members = $comparaDBA->get_MemberAdaptor->fetch_by_source_taxon(
  'ENSEMBLPEP', $ratGDB->taxon_id);

foreach my $pep (@{$members}) {
  next unless($pep->chr_name eq '2');
  next unless($pep->chr_start < 10000000);
  if($pep->get_Transcript->five_prime_utr) {
    $pep->gene_member->print_member;
    my $orths = $homologyDBA->fetch_all_by_Member_paired_species($pep->gene_member, 'homo_sapiens');
    foreach my $homology (@{$orths}) {
      $homology->print_homology;
    }
  }
}

