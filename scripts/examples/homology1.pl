#!/usr/bin/env perl

use strict;
use warnings;


#
# This script queries the Compara database and prints all the homologs
# of a given human gene
#

use Bio::EnsEMBL::Registry;

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $member_adaptor = $comparaDBA->get_MemberAdaptor;
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  next unless defined($member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);
  my $biotype = $gene->biotype;
  foreach my $this_homology (@$all_homologies) {
    $this_homology->print_homology;
  }
}

