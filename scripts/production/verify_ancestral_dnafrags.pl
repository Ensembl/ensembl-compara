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

=pod

=head2 SYNOPSIS

    verify_ancestral_dnafrags.pl -compara $(mysql-ensembl details url ensembl_compara_89) -ancestral $(mysql-ensembl details url ensembl_ancestral_89)

=head2 DESCRIPTION

Check that the ancestral dnafrags of the compara database are in sync
with the seq_regions of the ancestral (core) database

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Test::Deep::NoTest;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

my $reg = "Bio::EnsEMBL::Registry";

my $compara = 'Multi';
my $ancestral = 'ancestral_sequences';
my $registry_file;

GetOptions(
    'reg_conf=s'    => \$registry_file,
    'compara=s'     => \$compara,
    'ancestral=s'   => \$ancestral,
);


if ($registry_file) {
    $reg->load_all($registry_file, 0, 0, 0, "throw_if_missing");
} elsif (not (($compara =~ /:\/\//) && ($ancestral =~ /:\/\//))) {
    $reg->load_all();
}

$reg->no_version_check(1);

my $compara_dba = $compara =~ /:\/\// ? Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $compara ) : $reg->get_DBAdaptor($compara, 'compara');
my $ancestral_dba = $ancestral =~ /:\/\// ? Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $ancestral ) : $reg->get_DBAdaptor($ancestral, 'core');

# We can assume that both databases have been healthchecked, so we only
# need to compare the links between them

my $ancestral_gdb_id = $compara_dba->dbc->sql_helper->execute_single_result(
    -SQL => 'SELECT genome_db_id FROM genome_db WHERE name = ?',
    -PARAMS => [ 'ancestral_sequences' ],
);
my $compara_sql = q{SELECT coord_system_name, name, length FROM dnafrag WHERE genome_db_id = ? ORDER BY name};
my $ancestral_sql = q{SELECT coord_system.name, seq_region.name, seq_region.length FROM seq_region JOIN coord_system USING (coord_system_id) ORDER BY seq_region.name};

my $compara_sth = $compara_dba->dbc->prepare($compara_sql, { 'mysql_use_result' => 1 });
$compara_sth->execute($ancestral_gdb_id);
my $ancestral_sth = $ancestral_dba->dbc->prepare($ancestral_sql, { 'mysql_use_result' => 1 });
$ancestral_sth->execute();

my $compara_row = $compara_sth->fetch;
my $ancestral_row = $ancestral_sth->fetch;
my $n = 1;
# While there are rows
while ($compara_row && $ancestral_row) {
    unless (eq_deeply($compara_row, $ancestral_row)) {
        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse  = 1;
        die sprintf("Rows num. $n differ: compara=%s vs ancestral=%s\n", Dumper($compara_row), Dumper($ancestral_row));
    }
    # Go to the next rows, using the fact that the rows are sorted by name
    if ($compara_row->[1] eq $ancestral_row->[1]) {
        $compara_row = $compara_sth->fetch;
        $ancestral_row = $ancestral_sth->fetch;
        $n++;
    } elsif ($compara_row->[1] le $ancestral_row->[1]) {
        $compara_row = $compara_sth->fetch;
        $n++;
    } else {
        $ancestral_row = $ancestral_sth->fetch;
    } 
}

# Test if there are some rows remaining in one table
if ($ancestral_row) {
    $n = 0;
    $n++ while $ancestral_sth->fetch;
    die "$n rows remaining in the ancestral database\n";
} elsif ($compara_row) {
    $n = 0;
    $n++ while $compara_sth->fetch;
    die "$n rows remaining in the compara database\n";
}

print "Both databases are in sync\n";

