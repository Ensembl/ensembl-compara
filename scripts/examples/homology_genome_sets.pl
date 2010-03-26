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

my @list_of_species = ("Homo sapiens","Drosophila melanogaster","Caenorhabditis elegans");
my @gdbs;
foreach my $species_binomial (@list_of_species) {
  push @gdbs, $genomedb_adaptor->fetch_by_name_assembly($species_binomial);
}

my $present_in_all = undef;
while (my $sp1_gdb = shift @gdbs) {
  foreach my $sp2_gdb (@gdbs) {
    print STDERR "# Fetching for ", $sp1_gdb->name, " - ", $sp2_gdb->name, "\n";
    my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
      ('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
    my @orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth)};
    my $count = 0; my $total_count = scalar @orthologies;
    foreach my $ortholog (@orthologies) {
      1;
      # # Do something with the sets
      #       my ($gene1,$gene2) = @{$ortholog->gene_list};
      #       $present_in_all->{$gene1->stable_id}{$sp1_gdb->name}{$gene2->stable_id} = 1;
      #       $present_in_all->{$gene1->stable_id}{$sp2_gdb->name}{$gene1->stable_id} = 1;
      #       $present_in_all->{$gene2->stable_id}{$sp1_gdb->name}{$gene2->stable_id} = 1;
      #       $present_in_all->{$gene2->stable_id}{$sp2_gdb->name}{$gene1->stable_id} = 1;
      #       $count++;
      #       print STDERR "[$count/$total_count]\n" if (0 == $count % 100);
    }
  }
}

## For between species paralogies (dubious orthologs), use this instead
# my $mlss_para = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
# my @paralogies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_para)};

1;
