#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script gets the orthologue clusters starting from
# a specific gene and following the links (with the API)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $gene_name = shift;
$gene_name="ENSDARG00000052960" unless(defined($gene_name));

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $MA = $comparaDBA->get_MemberAdaptor;

my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", $gene_name);
my ($homologies, $genes) = $comparaDBA->get_HomologyAdaptor->fetch_orthocluster_with_Member($gene_member);

foreach my $homology (@$homologies) {
  $homology->print_homology;
}
foreach my $member (@$genes) {
  $member->print_member;
}

printf("cluster has %d links\n", scalar(@$homologies));
printf("cluster has %d genes\n", scalar(@$genes));

