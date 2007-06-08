#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::GenomeDB module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomeDB.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomeDB.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::GenomeDB module.

This script includes XX tests.

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
  plan tests => 7;
}

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');

my $human_name     = $hs_dba->get_MetaContainer->get_Species->binomial;
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

##
#####################################################################

my $genome_db;
my $dbID = 1;
my $taxon_id = 9606;
my $name = "Homo sapiens";
my $assembly = "NCBI36";
my $genebuild = "0510Ensembl";

$genome_db = new Bio::EnsEMBL::Compara::GenomeDB();
ok($genome_db, '/^Bio::EnsEMBL::Compara::GenomeDB/', "Testing new method");

$genome_db = new Bio::EnsEMBL::Compara::GenomeDB(
        $hs_dba,
        $name,
        $assembly,
        $taxon_id,
        $dbID,
        $genebuild
    );
ok($genome_db->db_adaptor, $hs_dba, "Testing dba set in new method");
ok($genome_db->name, $name, "Testing name set in new method");
ok($genome_db->assembly, $assembly, "Testing assembly set in new method");
ok($genome_db->taxon_id, $taxon_id, "Testing taxon_id set in new method");
ok($genome_db->dbID, $dbID, "Testing dbID set in new method");
ok($genome_db->genebuild, $genebuild, "Testing genebuild set in new method");

