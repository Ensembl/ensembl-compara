#!/usr/bin/env perl

use strict;
use warnings;


#
# This script queries the Compara database to fetch all the one2one
# homologies, and prints the percentage of identity with the alignment
# length
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

my $genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    next unless ($description =~ /one2one/); # if only one2one wanted
    my $all_member_attributes = 
    $this_homology->get_all_Member_Attribute();
    my $first_found = 0;
    foreach my $ma (@$all_member_attributes) {
      1;#??
      my ($mb, $attr) = @$ma;
      my $label = $mb->display_label || $mb->stable_id;
      print $mb->genome_db->short_name, ",", $label, "\t";
    }
    my $pairwise_alignment_from_multiple = $this_homology->get_SimpleAlign;
    my $overall_pid = $pairwise_alignment_from_multiple->overall_percentage_identity;
    print sprintf("%0.3f",$overall_pid),",";
    print $pairwise_alignment_from_multiple->length;
    print "\n";
  }
}

