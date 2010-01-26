#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $desc = "
USAGE: getPeptideAlignFeature [options]

WHERE options are:

--url ensembl_db_url
    mysql://anonymous\@ensembldb.ensembl.org, for example

--conf|--registry registry_file
    ensembl registry configuration file

--compara_url compara_db_url
    mysql://anonymous\@ensembldb.ensembl.org/ensembl_compara_57, for example

--gene_stable_id|--stable_id ensembl_gene_stable_id
    ENSG00000060069, for example

Only one of url, conf or compara_url are required. If none is provided, the
script will look for the registry configuration file in the standard place.
";

my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $registry_file;
my $url;
my $compara_url;
my $gene_stable_id = "ENSG00000060069";

GetOptions(
  "help" => \$help,
  "url=s" => \$url,
  "compara_url=s" => \$compara_url,
  "conf|registry=s" => \$registry_file,
  "gene_stable_id|stable_id=s" => \$gene_stable_id,
);

if ($help) {
  print $desc;
  exit(0);
}

if ($registry_file) {
  die if (!-e $registry_file);
  $reg->load_all($registry_file);
} elsif ($url) {
  $reg->load_registry_from_url($url);
} else {
  $reg->load_all();
}

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

###########################
# 
# advanced example which uses a recursive approach
# to build single linkage clusters within a species set
#
###########################

my $member_adaptor = $compara_dba->get_MemberAdaptor;
my $gene_member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", $gene_stable_id);
my $peptide_member = $gene_member->get_canonical_peptide_Member;
$peptide_member->print_member("query PEP\n");

my $peptide_align_feature_adaptor = $compara_dba->get_PeptideAlignFeatureAdaptor;
$peptide_align_feature_adaptor->final_clause("ORDER BY score desc");
my $peptide_align_features = $peptide_align_feature_adaptor->fetch_all_RH_by_member($peptide_member->dbID);
$peptide_align_feature_adaptor->final_clause("");

# loop through and print
foreach my $this_peptide_align_feature (@{$peptide_align_features}) {
  $this_peptide_align_feature->display_short;
}


exit(0);
