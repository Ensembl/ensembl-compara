#!/usr/bin/env perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception;
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $registry_file;
my @url;
my $compara_url;
my $dbname = "Multi";
my $dry_run;

GetOptions(
  "help" => \$help,
  "url=s" => \@url,
  "master_url|compara_url=s" => \$compara_url,
  "dbname=s" => \$dbname,
  "conf|registry=s" => \$registry_file,
  'dry!' => \$dry_run,
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

my $compara_dba = $compara_url
    ? Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url)
    : $reg->get_DBAdaptor($dbname, "compara");

my $species_set_adaptor = $compara_dba->get_adaptor("SpeciesSet");
my $genome_db_adaptor   = $compara_dba->get_adaptor("GenomeDB");

my $species_sets_with_taxon_id = $species_set_adaptor->fetch_all_by_tag("taxon_id");
print "\nFound a total of ".scalar(@$species_sets_with_taxon_id)." SpeciesSets with taxon_id defined.\n";

my $low_coverage_species_sets = $species_set_adaptor->fetch_all_by_tag_value("name", "low-coverage");
print "Found a total of ".scalar(@$low_coverage_species_sets)." low-coverage SpeciesSets.\n";

    # filter the latest (by species_set_id) from each group
my %taxon_id_2_latest_ss = ();
foreach my $curr_ss (@$species_sets_with_taxon_id, @$low_coverage_species_sets) {
    my $taxon_id = $curr_ss->get_value_for_tag('taxon_id') || 0;
    my $prev_ss = $taxon_id_2_latest_ss{$taxon_id};

    if(!$prev_ss or ($prev_ss->dbID<$curr_ss->dbID)) {
        $taxon_id_2_latest_ss{$taxon_id} = $curr_ss;
    }
}
print "\nFiltered the latest version for each of ".scalar(keys %taxon_id_2_latest_ss)." groups (assuming latest SpeciesSet has larger species_set_id).\n";

foreach my $taxon_id (sort keys %taxon_id_2_latest_ss) {
    my $tag_containing_ss = $taxon_id_2_latest_ss{ $taxon_id };

    my $tag_value_hash = $tag_containing_ss->get_tagvalue_hash();
    my $ss_name     = $tag_value_hash->{'name'};

    print "\nFor '$ss_name' we have the following latest SpeciesSet ".$tag_containing_ss->toString()." with tags:\n";

    while (my ($tag, $value) = each %$tag_value_hash) {
        print "\t$tag: $value\n";
    }

    my $uptodate_gdbs   = ($taxon_id>0)     # needs to be a numeric comparison
        ? $genome_db_adaptor->fetch_all_by_ancestral_taxon_id($taxon_id, 1)     # filter out ones with assembly_default==1
        : $genome_db_adaptor->fetch_all_by_low_coverage();
    my $uptodate_ss     = $species_set_adaptor->fetch_by_GenomeDBs($uptodate_gdbs); # exact set

    if ($uptodate_ss) {
        # Comparing the content of the species_sets
        if ($uptodate_ss->toString eq $tag_containing_ss->toString) {
            print "The SpeciesSet for '$ss_name' is up-to-date, no need to create a new set or transfer any tags\n";
        } else {
            die "There is an up-to-date SpeciesSet for '$ss_name',\n\t".$uptodate_ss->toString()."\n\t, but it is not the latest tag-bearing one. You may want to investigate this before going further.";
        }
    } else {
        $uptodate_ss = new Bio::EnsEMBL::Compara::SpeciesSet(-genome_dbs => $uptodate_gdbs);
        print "Created a NEW SpeciesSet for '$ss_name': ". $uptodate_ss->toString()."\n";
        while (my ($tag, $value) = each %$tag_value_hash) {
            $uptodate_ss->add_tag($tag, $value);
        }
        if($dry_run) {
            print "NOT STORING the SpeciesSet in dry_run mode\n";
        } else {
            $species_set_adaptor->store($uptodate_ss);
            print "STORED the SpeciesSet ( ". $uptodate_ss->dbID. " )\n";
        }
    }
}

