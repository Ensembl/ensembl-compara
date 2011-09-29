#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script fetches all the peptide reciprocal hits
# with human for a given rat location
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $pafDBA = $comparaDBA-> get_PeptideAlignFeatureAdaptor;
$pafDBA->final_clause("ORDER BY score desc");

my $humanGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("human");
my $ratGDB = $comparaDBA->get_GenomeDBAdaptor-> fetch_by_registry_name("rat");

my $members = $comparaDBA->get_MemberAdaptor->fetch_by_source_taxon(
  'ENSEMBLPEP', $ratGDB->taxon_id);

foreach my $pep (@{$members}) {
  next unless($pep->chr_name eq '15');
  next unless($pep->chr_start < 4801065 );
  next unless($pep->chr_end > 4791387 );

  $pep->print_member;

  my $pafs = $pafDBA->fetch_all_RH_by_member_genomedb($pep->dbID, $humanGDB->dbID);

  foreach my $paf (@{$pafs}) {
    $paf->display_short;
    $paf->hit_member->gene_member->print_member;
  }
}

