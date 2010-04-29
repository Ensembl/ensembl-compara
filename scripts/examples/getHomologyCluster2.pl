#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Time::HiRes qw { time };

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;

my $reg_conf = shift;
my $gene_name = shift;
$gene_name="ENSDARG00000052960" unless(defined($gene_name));

die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

###########################
# 
# advanced example which uses a recursive approach
# to build single linkage clusters within the orthologues
# by starting at a specific gene and following the links
#
###########################

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');


my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", $gene_name);

my $start = time();
my ($homologies, $genes) = $comparaDBA->get_HomologyAdaptor->fetch_orthocluster_with_Member($gene_member);

foreach my $homology (@$homologies) {
  $homology->print_homology;
}
foreach my $member (@$genes) {
  $member->print_member;
}

printf("cluster has %d links\n", scalar(@$homologies));
printf("cluster has %d genes\n", scalar(@$genes));
printf("%1.3f msec\n", 1000.0*(time() - $start));

exit(0);

1;
