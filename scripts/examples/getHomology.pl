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

my $homologies = $comparaDBA-> get_HomologyAdaptor-> 
       fetch_all_by_Member_method_link_type($gene_member, 'ENSEMBL_ORTHOLOGUES');

# loop through and print
foreach my $homology (@{$homologies}) {
  printf("homology(%d) %s\n", $homology->dbID, $homology->description);
  my $mem_attribs = $homology->get_all_Member_Attribute;
  foreach my $member_attribute (@{$mem_attribs}) {
    my ($member, $atrb) = @{$member_attribute};
    $member->print_member;
  }
}


exit(0);
