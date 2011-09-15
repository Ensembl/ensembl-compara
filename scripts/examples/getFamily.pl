#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch a family, from a gene.
# Then, it prints the full content of the family
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
    -host=>'ensembldb.ensembl.org',
    -user=>'anonymous', 
);


# get the member
my $member_adaptor = $reg->get_adaptor('Multi', 'compara', 'Member');
my $gene_member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000014138");

# get all family predictions for the gene member should return 1
my $family_adaptor = $reg->get_adaptor('Multi', 'compara', 'Family');
my $families = $family_adaptor->fetch_by_Member($gene_member);

# loop through and print
foreach my $family (@{$families}) {
    printf("family(%d) %s\n", $family->dbID, $family->description);
    my $mem_attribs = $family->get_all_Member_Attribute;
    foreach my $member_attribute (@{$mem_attribs}) {
        my ($member, $atrb) = @{$member_attribute};
        printf("   %s %s(%d)\n", $member->source_name, $member->stable_id, $member->dbID);
    }
}

