#!/usr/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous");

my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Homology");

my $mlss_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "MethodLinkSpeciesSet");

my $genomedb_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "GenomeDB");

my $sp1_gdb = $genomedb_adaptor->fetch_by_name_assembly("Homo sapiens");
my $sp2_gdb = $genomedb_adaptor->fetch_by_name_assembly("Mus musculus");

my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
  ('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
my $mlss_para = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
  ('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
my @orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth)};
my @paralogies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_para)};

1;
