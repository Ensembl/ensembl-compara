#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::GenomicAlign module
#
# Written by Abel Ureta-Vidal (abel@ebi.ac.uk)
# Updated by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

MutliTestDB.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl MultiTestDB.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script tests whether the Bio::EnsEMBL::MulTiTestDB module and the test DB are working or not.

This script includes 8 tests.

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

use Test;
use strict;

BEGIN { $| = 1; plan tests => 8 }

use Bio::EnsEMBL::Test::MultiTestDB;

my $num_of_species = 35;

# Database will be dropped when this
# object goes out of scope
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
ok($multi, '/^Bio::EnsEMBL::Test::MultiTestDB/',
    "Getting Bio::EnsEMBL::Test::MultiTestDB object for multi species");

my $dba = $multi->get_DBAdaptor('compara');
ok($dba, '/^Bio::EnsEMBL::Compara::DBSQL::DBAdaptor/',
    "Getting Bio::EnsEMBL::Compara::DBSQL::DBAdaptor object for compara DB");

my $sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;

ok(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB");


# now hide the gene table i.e. make an empty version of it
$multi->hide("compara","genome_db");
$sth->execute;
ok($sth->rows, 0,
    "Checking that there is no species left in the <genome_db> table after hiding it");


# restore the gene table
$multi->restore();
$sth->execute;
ok(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after restoring the <genome_db> table");


# now save the gene table i.e. make a copy of it
$multi->save("compara","genome_db");
$sth->execute;
ok(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after saving the <genome_db> table");


# delete 1 entry from the db
$sth = $dba->dbc->prepare("delete from genome_db where name = 'Homo sapiens'");
$sth->execute;

$sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;
ok(scalar($sth->rows), ($num_of_species - 1),
    "Checking the number of species present in the copy table after deleting the human entry");


# check to see whether the restore works again
$multi->restore();
$sth->execute;
ok(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after restoring the <genome_db> table");


$sth->finish;
