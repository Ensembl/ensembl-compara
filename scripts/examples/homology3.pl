#!/usr/bin/env perl

use strict;
use warnings;


#
# This script retrieves all the homologs and paralogs between two species
#

use Bio::EnsEMBL::Registry;

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;
my $mlss_adaptor = $comparaDBA->get_MethodLinkSpeciesSetAdaptor;
my $genomedb_adaptor = $comparaDBA->get_GenomeDBAdaptor;

my $sp1 = "homo_sapiens";
my $sp2 = "mus_musculus";

my $sp1_gdb = $genomedb_adaptor->fetch_by_name_assembly($sp1);
my $sp2_gdb = $genomedb_adaptor->fetch_by_name_assembly($sp2);

my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
  ('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
my $mlss_para = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
  ('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
my @orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth)};
my @paralogies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_para)};

print scalar(@orthologies), " orthologies between $sp1 and $sp2\n";
print scalar(@paralogies), " paralogies between $sp1 and $sp2\n";

