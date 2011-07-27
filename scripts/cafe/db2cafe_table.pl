#!/usr/bin/perl

# This table will serve both for cafe and as a general table of families descriptions.
use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

# select * from method_link_species_set where method_link_species_set_id = 40074;
# select * from species_set where species_set_id = 33880;

my $mlss = 40074;

my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_db(
                            -host => "127.0.0.1",
                            -user => "ensro",
                            -pass => "",
                            -port => 2901,
#                            -verbose => 1,
);


# Get all the species for the mlss:

my $mlss_adaptor = $reg->get_adaptor("multi", "compara", "MethodLinkSpeciesSet");
my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($mlss);
my $species_set = $method_link_species_set->species_set();
my @species_names = map {$_->name} @$species_set;

# Get the number of members per family
my $nctree_adaptor = $reg->get_adaptor("multi", "compara", "NCTree");
my $all_trees = $nctree_adaptor->fetch_all();

print "FAMILYDESC\tFAMILY\t", join("\t", map {ucfirst} @species_names), "\n";
for my $tree (@$all_trees) {
  my $root_id = $tree->node_id();
  my $nctree = $nctree_adaptor->fetch_node_by_node_id($root_id);
  my $model_name = $nctree->get_tagvalue('model_name');
  my $nctree_members = $nctree->get_all_leaves();
  my %species;
  for my $member (@$nctree_members) {
    my $sp;
    eval {$sp = $member->genome_db->name};
    next if ($@);
    $species{$sp}++;
  }

  my @flds = ($model_name, $root_id);
  for my $sp (@species_names) {
    push @flds, ($species{$sp} || 0);
  }
  print join ("\t", @flds), "\n";
}



