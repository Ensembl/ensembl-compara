#!/usr/bin/env perl

use strict;
use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";

$reg->load_registry_from_db(
    -host => "ensembldb.ensembl.org",
    -user => "anonymous"
);

my $genomedb_adaptor = $reg->
	get_adaptor("Multi", "compara", "GenomeDB");

print "All Ensembl species:\n";
my $all_genomedb = $genomedb_adaptor->fetch_all();

foreach my $this_genomedb (@$all_genomedb) {
  print "full name: ", $this_genomedb->taxon ? $this_genomedb->taxon->binomial : "?";
  print ", short name: ", $this_genomedb->short_name;
  print ", assembly: ", $this_genomedb->assembly, "\n";
}
