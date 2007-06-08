#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DnaFrag module
#
# Written by Abel Ureta-Vidal (abel@ebi.ac.uk) and Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

dnaFrag.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl dnaFrag.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DnaFrag module.

This script includes 24 tests.

=head1 AUTHORS

Abel Ureta-Vidal (abel@ebi.ac.uk)
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
 
use Test::Harness;
use Test;
BEGIN { plan tests => 24 }

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomeDB;

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

my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor;
my $dummy_db = new Bio::EnsEMBL::Compara::GenomeDB;

ok(!$dnafrag_adaptor, "", "Checking Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor object");
ok(!$dummy_db, "", "Checking Bio::EnsEMBL::Compara::GenomeDB object");

my $dnafrag;
my $dbID = 905401;
my $adaptor = $dnafrag_adaptor;
my $length = 88827254;
my $name = "16";
my $genome_db_id = 22;
my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
my $coord_system_name = "chromosome";

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
ok($dnafrag, '/^Bio::EnsEMBL::Compara::DnaFrag/', "Creating a new Bio::EnsEMBL::Compara::DnaFrag obejct");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-dbID => $dbID);
ok($dnafrag->dbID, $dbID, "Checking dbID set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-adaptor => $dnafrag_adaptor);
ok($dnafrag->adaptor, $dnafrag_adaptor, "Checking adaptor set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-length => $length);
ok($dnafrag->length, $length, "Checking length set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-name => $name);
ok($dnafrag->name, $name, "Checking name set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-genome_db => $genome_db);
ok($dnafrag->genome_db, $genome_db, "Checking genome_db set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-genome_db_id => $genome_db_id);
ok($dnafrag->genome_db_id, $genome_db_id, "Checking genome_db_id set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-coord_system_name => $coord_system_name);
ok($dnafrag->coord_system_name, $coord_system_name, "Checking coord_system_name set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->dbID($dbID);
ok($dnafrag->dbID, $dbID, "Checking dbID method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->adaptor($dnafrag_adaptor);
ok($dnafrag->adaptor, $dnafrag_adaptor, "Checking adaptor method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->length($length);
ok($dnafrag->length, $length, "Checking length method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->name($name);
ok($dnafrag->name, $name, "Checking name method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->genome_db($genome_db);
ok($dnafrag->genome_db, $genome_db, "Checking genome_db method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(-adaptor=>$dnafrag_adaptor, -genome_db_id=>$genome_db_id);
ok($dnafrag->genome_db->dbID, $genome_db_id, "Getting genome_db from adaptor and genome_db_id");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->genome_db_id($genome_db_id);
ok($dnafrag->genome_db_id, $genome_db_id, "Checking genome_db_id method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->genome_db($genome_db);
ok($dnafrag->genome_db_id, $genome_db_id, "Getting genome_db_id from genome_db");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
$dnafrag->coord_system_name($coord_system_name);
ok($dnafrag->coord_system_name, $coord_system_name, "Checking coord_system_name set in new method");

$dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
        -adaptor => $dnafrag_adaptor,
        -genome_db_id => $genome_db_id,
        -coord_system_name => $coord_system_name,
        -name => $name
    );
ok($dnafrag->slice, '/^Bio::EnsEMBL::Slice/', "Checking slice getter method");


# Test deprecated methods...
my $prev_verbose_level = verbose();
verbose(0);
ok( test_getter_setter( $dnafrag, "start", 1 ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::start method ");
ok( test_getter_setter( $dnafrag, "end", 256 ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::end method ");
ok( test_getter_setter( $dnafrag, "genomedb", $dummy_db ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::genomedb method ");
ok( test_getter_setter( $dnafrag, "type", "dummy" ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::type method ");
verbose($prev_verbose_level);
