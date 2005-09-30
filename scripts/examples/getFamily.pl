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
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000014138");

# get all family predictions for the gene member should return 1
my $families = $comparaDBA-> get_FamilyAdaptor-> fetch_by_Member($gene_member);

# loop through and print
foreach my $family (@{$families}) {
  printf("family(%d) %s\n", $family->dbID, $family->description);
  my $mem_attribs = $family->get_all_Member_Attribute;
  foreach my $member_attribute (@{$mem_attribs}) {
    my ($member, $atrb) = @{$member_attribute};
    printf("   %s %s(%d)\n", $member->source_name, $member->stable_id, $member->dbID);
  }
}


exit(0);
