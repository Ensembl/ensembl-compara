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
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

###########################
# 
# example to get all orthologues which 
# contain a specified gene
#
###########################

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');

my $memberAdaptor = Bio::EnsEMBL::Registry->get_adaptor('compara', 'compara', 'Member');
#my $gene_member = $memberAdaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
my $gene_member = $memberAdaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000014138");

my $homologies = $comparaDBA-> get_HomologyAdaptor-> 
       fetch_all_by_Member_method_link_type($gene_member, 'ENSEMBL_ORTHOLOGUES');

# loop through and print
foreach my $homology (@{$homologies}) {
  printf("homology(%d) %s\n", $homology->dbID, $homology->description);
  my $mem_attribs = $homology->get_all_Member_Attribute;
  foreach my $member_attribute (@{$mem_attribs}) {
    my ($member, $atrb) = @{$member_attribute};
    $member->print_member;
    my $peptide_member = $memberAdaptor->fetch_by_dbID($atrb->peptide_member_id);
    $peptide_member->print_member;
    my $transcript = $peptide_member->get_Transcript;
    my $utr3_bioseq = $transcript ->three_prime_utr;
    print("  3UTR\n") if(defined($utr3_bioseq));
  }
}


exit(0);
