#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Time::HiRes qw { time };

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

###########################
# 
# advanced example which uses a recursive approach
# to build single linkage clusters within a species set
#
###########################

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



exit(0);
