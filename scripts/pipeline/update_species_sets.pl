#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception;
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $registry_file;
my @url;
my $compara_url;
my $dbname = "Multi";

GetOptions(
  "help" => \$help,
  "url=s" => \@url,
  "master_url|compara_url=s" => \$compara_url,
  "dbname=s" => \$dbname,
  "conf|registry=s" => \$registry_file,
);

if ($registry_file) {
  die if (!-e $registry_file);
  $reg->load_all($registry_file);
} elsif (@url) {
  foreach my $this_url (@url) {
    $reg->load_registry_from_url($this_url, 1);
  }
} else {
  $reg->load_all();
}

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor($dbname, "compara");
}

my $species_set_adaptor = $compara_dba->get_adaptor("SpeciesSet");
my $ncbi_taxon_adaptor = $compara_dba->get_adaptor("NCBITaxon");
my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

my $species_sets_with_taxon_id = $species_set_adaptor->fetch_all_by_tag("taxon_id");

foreach my $this_species_set (@$species_sets_with_taxon_id) {
  print $this_species_set->dbID, "\n";
  my $tag_value_hash = $this_species_set->get_tagvalue_hash();
  my $taxon_id = $tag_value_hash->{"taxon_id"};
  my $group_name = $tag_value_hash->{"name"};
  while (my ($tag, $value) = each %$tag_value_hash) {
    print "$tag: $value\n";
  }
  my $genome_dbs = $genome_db_adaptor->fetch_all_by_ancestral_taxon_id($taxon_id);
  my $genome_db_by_name;
  foreach my $genome_db (@$genome_dbs) {
    my $genome_db_name = $genome_db->name;
    next if (!$genome_db->assembly_default());
    $genome_db_by_name->{$genome_db_name} = $genome_db;
  }
  my $species_set = $species_set_adaptor->fetch_by_GenomeDBs([values(%$genome_db_by_name)]);
  if ($species_set) {
    print $species_set->dbID, ": ", join(", ", map {$_->name."(".$_->assembly_default.")"} @{$species_set->genome_dbs}), "\n";
  } else {
    print "I need a new species_set for $group_name\n";
    my $new_species_set = new Bio::EnsEMBL::Compara::SpeciesSet(-genome_dbs => [values(%$genome_db_by_name)]);
    print "NEW: ", join(", ", map {$_->name."(".$_->assembly_default.")"} values(%$genome_db_by_name)), "\n";
    while (my ($tag, $value) = each %$tag_value_hash) {
      $new_species_set->add_tag($tag, $value);
    }
    $species_set_adaptor->store($new_species_set);
    print " -> ", $new_species_set->dbID, "\n";
  }
}

my $low_coverage_species_sets = $species_set_adaptor->fetch_all_by_tag_value("name", "low-coverage");
if (@$low_coverage_species_sets) {
  my $low_coverage_species_set = (sort {$b->species_set_id <=> $a->species_set_id} @$low_coverage_species_sets)[0];
  my $tag_value_hash = $low_coverage_species_set->get_tagvalue_hash();
  my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  my $low_coverage_genome_dbs = [];
  foreach my $this_genome_db (@$all_genome_dbs) {
    next if (!$this_genome_db->assembly_default);
    next if ($this_genome_db->name eq "ancestral_sequences");
    next if ($this_genome_db->name eq "caenorhabditis_elegans");
    my $db_adaptor = $this_genome_db->db_adaptor;
    if (!$db_adaptor) {
      throw("Cannot connect to ".$this_genome_db->name." core DB\n");
    }
    my $meta_container = $db_adaptor->get_MetaContainer;
    my $coverage_depth = $meta_container->list_value_by_key("assembly.coverage_depth")->[0];
#     print $this_genome_db->name, " coverage: $coverage_depth\n";
    if ($coverage_depth eq "low") {
      push(@$low_coverage_genome_dbs, $this_genome_db);
    }
  }
  my $species_set = $species_set_adaptor->fetch_by_GenomeDBs($low_coverage_genome_dbs);
  if ($species_set) {
    print $species_set->dbID, ": ", join(", ", map {$_->name."(".$_->assembly_default.")"} @{$species_set->genome_dbs}), "\n";
  } else {
    print "I need a new species_set for low-coverage genomes\n";
    my $new_species_set = new Bio::EnsEMBL::Compara::SpeciesSet(-genome_dbs => $low_coverage_genome_dbs);
    print "NEW: ", join(", ", map {$_->name."(".$_->assembly_default.")"} @$low_coverage_genome_dbs), "\n";
    while (my ($tag, $value) = each %$tag_value_hash) {
      $new_species_set->add_tag($tag, $value);
    }
    $species_set_adaptor->store($new_species_set);
    print " -> ", $new_species_set->dbID, "\n";
  }
}

