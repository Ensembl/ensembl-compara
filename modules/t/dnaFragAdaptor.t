#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

dnaFragAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl dnaFragAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor module.

This script includes 40 tests.

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
  plan tests => 40;
}

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species = [
        "homo_sapiens",
#         "mus_musculus",
        "rattus_norvegicus",
        "gallus_gallus",
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

my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
ok($dnafrag_adaptor, '/^Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor/',
    "Getting the adaptor");

    
#####################################################################
## Values matching entries in the test DB

my $dnafrag;
my $dnafrags;
my $dnafrag_id = 19;
my $dnafrag_length = 105311216;
my $dnafrag_name = "14";
my $genome_db_id = 1;
my $coord_system_name = "chromosome";

my $num_of_dnafrags = 12;

my $genome_db_id_2 = 11;
my $dnafrags_2 = {
  23222 => {
          length => 108638738,
          name => 3,
          coord_system_name => "chromosome"
      },
  23227 => {
          length => 56310377,
          name => 5,
          coord_system_name => "chromosome"
      },
  23237 => {
          length => 165033910,
          name => "Un",
          coord_system_name => "chromosome"
      }
  };

##
#####################################################################



$dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
ok($dnafrag, '/^Bio::EnsEMBL::Compara::DnaFrag/', "Fetching by dbID");
ok($dnafrag->dbID, $dnafrag_id, "Fetching by dbID. Checking dbID");
ok($dnafrag->length, $dnafrag_length, "Fetching by dbID. Checking length");
ok($dnafrag->name, $dnafrag_name, "Fetching by dbID. Checking name");
ok($dnafrag->genome_db_id, $genome_db_id, "Fetching by dbID. Checking genome_db_id");
ok($dnafrag->coord_system_name, $coord_system_name, "Fetching by dbID. Checking coord_system_name");

$dnafrag = eval { $dnafrag_adaptor->fetch_by_dbID(-$dnafrag_id) };
ok($dnafrag, undef, "Fetching by dbID with wrong dbID");

$dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db_id, $dnafrag_name);
ok($dnafrag, '/^Bio::EnsEMBL::Compara::DnaFrag/', "Fetching by GenomeDB and name");
ok($dnafrag->dbID, $dnafrag_id, "Fetching by GenomeDB and name. Checking dbID");
ok($dnafrag->length, $dnafrag_length, "Fetching by GenomeDB and name. Checking length");
ok($dnafrag->name, $dnafrag_name, "Fetching by GenomeDB and name. Checking name");
ok($dnafrag->genome_db_id, $genome_db_id, "Fetching by GenomeDB and name. Checking genome_db_id");
ok($dnafrag->coord_system_name, $coord_system_name, "Fetching by GenomeDB and name. Checking coord_system_name");

$dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db_id, $dnafrag_name);
ok($dnafrag, '/^Bio::EnsEMBL::Compara::DnaFrag/', "Fetching by GenomeDB and name");
ok($dnafrag->dbID, $dnafrag_id, "Fetching by GenomeDB and name. Checking dbID");
ok($dnafrag->length, $dnafrag_length, "Fetching by GenomeDB and name. Checking length");
ok($dnafrag->name, $dnafrag_name, "Fetching by GenomeDB and name. Checking name");
ok($dnafrag->genome_db_id, $genome_db_id, "Fetching by GenomeDB and name. Checking genome_db_id");
ok($dnafrag->coord_system_name, $coord_system_name, "Fetching by GenomeDB and name. Checking coord_system_name");

$dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
        $genome_db_adaptor->fetch_by_dbID($genome_db_id),
        $dnafrag_name
    );
ok($dnafrag, '/^Bio::EnsEMBL::Compara::DnaFrag/', "Fetching by GenomeDB and name (2)");
ok($dnafrag->dbID, $dnafrag_id, "Fetching by GenomeDB and name (2). Checking dbID");
ok($dnafrag->length, $dnafrag_length, "Fetching by GenomeDB and name (2). Checking length");
ok($dnafrag->name, $dnafrag_name, "Fetching by GenomeDB and name (2). Checking name");
ok($dnafrag->genome_db_id, $genome_db_id, "Fetching by GenomeDB and name (2). Checking genome_db_id");
ok($dnafrag->coord_system_name, $coord_system_name, "Fetching by GenomeDB and name (2). Checking coord_system_name");

$dnafrag = eval { $dnafrag_adaptor->fetch_by_GenomeDB_and_name(-$genome_db_id, $dnafrag_name) };
ok($dnafrag, undef, "Fetching by GenomeDB and name with a wrong genome_db_id");

$dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
        $genome_db_adaptor->fetch_by_dbID($genome_db_id),
        $coord_system_name,
        $dnafrag_name
    );
ok(@$dnafrags, 1);
ok($dnafrags->[0], '/^Bio::EnsEMBL::Compara::DnaFrag/', "Fetching all by GenomeDB and region");
ok($dnafrags->[0]->dbID, $dnafrag_id, "Fetching all by GenomeDB and region. Checking dbID");
ok($dnafrags->[0]->length, $dnafrag_length, "Fetching all by GenomeDB and region. Checking length");
ok($dnafrags->[0]->name, $dnafrag_name, "Fetching all by GenomeDB and region. Checking name");
ok($dnafrags->[0]->genome_db_id, $genome_db_id, "Fetching all by GenomeDB and region. Checking genome_db_id");
ok($dnafrags->[0]->coord_system_name, $coord_system_name, "Fetching all by GenomeDB and region. Checking coord_system_name");

$dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
        $genome_db_adaptor->fetch_by_dbID($genome_db_id_2)
    );
ok(@$dnafrags, keys(%$dnafrags_2));
do {
  my $fail = "";
  foreach my $dnafrag (@$dnafrags) {
    if (!defined($dnafrags_2->{$dnafrag->dbID})) {
      $fail .= "Found unexpected Bio::EnsEMBL::Compara::DnaFrag(".$dnafrag->dbID.")";
      next;
    }
    if (($dnafrags_2->{$dnafrag->dbID}->{length} != $dnafrag->length)) {
      $fail .= "Unexpected length (".$dnafrag->length.") for DnaFrag(".$dnafrag->dbID.")";
    }
    if (($dnafrags_2->{$dnafrag->dbID}->{name} ne $dnafrag->name)) {
      $fail .= "Unexpected name (".$dnafrag->name.") for DnaFrag(".$dnafrag->dbID.")";
    }
    if (($dnafrags_2->{$dnafrag->dbID}->{coord_system_name} ne $dnafrag->coord_system_name)) {
      $fail .= "Unexpected name (".$dnafrag->coord_system_name.") for DnaFrag(".$dnafrag->dbID.")";
    }
    
  }
  ok($fail, "", "Fetching all by GenomeDB and region");
};

$dnafrags = $dnafrag_adaptor->fetch_all();
ok(@$dnafrags, $num_of_dnafrags, "Fetching all");


$dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
$multi->hide("compara", "dnafrag");

$dnafrags = $dnafrag_adaptor->fetch_all();
ok(@$dnafrags, 0, "Fetching all after hiding table");

#
$dnafrag->genome_db;
$dnafrag->{adaptor} = undef;
$dnafrag_adaptor->store($dnafrag);
$dnafrags = $dnafrag_adaptor->fetch_all();
ok(@$dnafrags, 1, "Fetching all after hiding table");
$dnafrag->{adaptor} = undef;
$dnafrag_adaptor->store_if_needed($dnafrag);
$dnafrags = $dnafrag_adaptor->fetch_all();
ok(@$dnafrags, 1, "Fetching all after hiding table");

$multi->restore("compara", "dnafrag");
