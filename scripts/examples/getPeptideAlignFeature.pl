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

my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
my $pep = $gene_member->get_canonical_peptide_Member;
$pep->print_member("query PEP\n");

my $pafDBA = $comparaDBA-> get_PeptideAlignFeatureAdaptor;
$pafDBA->final_clause("ORDER BY score desc");
my $pafs = $pafDBA->fetch_all_RH_by_member($pep->dbID);
$pafDBA->final_clause("");

# loop through and print
foreach my $paf (@{$pafs}) {
  $paf->display_short 
}



exit(0);
