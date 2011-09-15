#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script retrieves all the orthologues of a given gene
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


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
    my $utr3_bioseq = $transcript->three_prime_utr;
    print("  3UTR\n") if(defined($utr3_bioseq));
  }
}

