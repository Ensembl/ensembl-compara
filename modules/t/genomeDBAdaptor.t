#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomeDBAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomeDBAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor module.

This script includes 8 tests.

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

BEGIN {
  $| = 1;
  use Test;
  plan tests => 8;
}

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species = [
        "homo_sapiens",
        "mus_musculus",
        "rattus_norvegicus",
        "gallus_gallus",
        "bos_taurus",
	"canis_familiaris",
	"macaca_mulatta",
	"monodelphis_domestica",
	"ornithorhynchus_anatinus",
	"pan_troglodytes", 
    ];

## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  my $species_db = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  my $species_db_adaptor = $species_db->get_DBAdaptor('core');
  my $species_gdb = $genome_db_adaptor->fetch_by_name_assembly(
          $species_db_adaptor->get_MetaContainer->get_Species->binomial,
          $species_db_adaptor->get_CoordSystemAdaptor->fetch_all->[0]->version
      );
  $species_gdb->db_adaptor($species_db_adaptor);
}

##
#####################################################################

my $genome_db;
my $all_genome_dbs;
my $num_of_genomes = 35;
my $genome_db_id = 22;
my $method_link_id = 1;
my $num_of_db_links = 9;

$genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
ok($genome_db, '/^Bio::EnsEMBL::Compara::GenomeDB/', "Fetching Bio::EnsEMBL::Compara::GenomeDB by dbID");

$genome_db = $genome_db_adaptor->fetch_by_dbID(-$genome_db_id);
ok($genome_db, undef, "Fetching Bio::EnsEMBL::Compara::GenomeDB by unknown dbID");

$all_genome_dbs = $genome_db_adaptor->fetch_all();
ok(scalar(@$all_genome_dbs), $num_of_genomes, "Checking the total number of genomes");

$genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
my $name = $genome_db->name;
my $assembly = $genome_db->assembly;

$genome_db = $genome_db_adaptor->fetch_by_name_assembly($name);
ok($genome_db->dbID, $genome_db_id, "Fetching by name and default assembly");

$genome_db = $genome_db_adaptor->fetch_by_name_assembly($name, $assembly);
ok($genome_db->dbID, $genome_db_id, "Fetching by name and assembly");


$multi->hide('compara', 'genome_db');
## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  $genome_db_adaptor->create_GenomeDBs; # reset globals
$all_genome_dbs = $genome_db_adaptor->fetch_all();
## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  $genome_db_adaptor->create_GenomeDBs; # reset globals
ok(scalar(@$all_genome_dbs), 0, "Checking hide method");

$genome_db_adaptor->store($genome_db);
## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  $genome_db_adaptor->create_GenomeDBs; # reset globals
$all_genome_dbs = $genome_db_adaptor->fetch_all();
ok(scalar(@$all_genome_dbs), 1, "Checking store method");
$multi->restore('compara', 'genome_db');
## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  $genome_db_adaptor->create_GenomeDBs; # reset globals

$genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
ok(scalar(@{$genome_db_adaptor->get_all_db_links($genome_db, $method_link_id)}), $num_of_db_links,
    "Check number of links for genome_db_id($genome_db_id) and method_link_id($method_link_id)");
