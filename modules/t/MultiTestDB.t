#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use Test::More;
use strict;

use Bio::EnsEMBL::Test::MultiTestDB;

my $num_of_species = 60;

# Database will be dropped when this
# object goes out of scope
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
isa_ok($multi, "Bio::EnsEMBL::Test::MultiTestDB", "Getting Bio::EnsEMBL::Test::MultiTestDB object for multi species");

my $dba = $multi->get_DBAdaptor('compara');
isa_ok($dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', "Getting Bio::EnsEMBL::Compara::DBSQL::DBAdaptor object for compara DB");

my $sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;

is(scalar($sth->rows), $num_of_species, "Checking the number of species present in the test DB");


# now hide the genome_db table i.e. make an empty version of it
$multi->hide("compara","genome_db");
$sth->execute;
is($sth->rows, 0,
    "Checking that there is no species left in the <genome_db> table after hiding it");


# restore the genome_db table
$multi->restore();
$sth->execute;
is(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after restoring the <genome_db> table");


# now save the genome_db table i.e. make a copy of it
$multi->save("compara","genome_db");
$sth->execute;
is(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after saving the <genome_db> table");


# delete 1 entry from the db
$sth = $dba->dbc->prepare("delete from genome_db where name = 'homo_sapiens'");
$sth->execute;

$sth = $dba->dbc->prepare("select * from genome_db");
$sth->execute;
is(scalar($sth->rows), ($num_of_species - 1),
    "Checking the number of species present in the copy table after deleting the human entry");


# check to see whether the restore works again
$multi->restore();
$sth->execute;
is(scalar($sth->rows), $num_of_species,
    "Checking the number of species present in the test DB after restoring the <genome_db> table");
$sth->finish;

done_testing();

