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


# This is a script to aid the transition to "first_release" /
# "last_release" in the genome_db table from only "assembly_default"

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use List::Util qw(max);
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


## Command-line options
my ($master_url, $division, $topup, $help);

GetOptions(
    'master_url=s'  => \$master_url,
    'division=s'    => \$division,
    'topup'         => \$topup,
    'help'          => \$help,
);

if ($help) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

die "Must provide the URL of the master database\n" unless $master_url;

my %fields = (
    genome_db => [qw(name assembly)],
    species_set => [],
    method_link_species_set => [qw(method_link_id species_set_id name)],
);

my %first_division_release = (
    ''          => 24,  # ensembl
    'bacteria'  => 52,
    'fungi'     => 55,
    'metazoa'   => 52,
    'pan_homology'  => 52,
    'plants'        => 55,
    'protists'      => 52,
);

$division = '' unless $division;
die "Unknown division '$division'" unless $first_division_release{$division};

my %first_table_release = (
    genome_db               => 24,
    method_link_species_set => 25,
    species_set             => 38,
    species_set_tag         => 57,
);

my $last_available_rel  = 81;     # last public release

$| = 1;

sub get_compara_url {
    my $rel = shift @_;

    return $master_url if $rel eq 'master';

    # db naming scheme for Ensembl Genomes / Ensembl
    my $db_name = $division ? "ensembl_compara_${division}_".($rel-53)."_${rel}" : "ensembl_compara_${rel}";

    if ($division) {
        # Ensembl Genomes
        if ($rel >= $first_division_release{$division}) {
            return 'mysql://anonymous@mysql-eg-publicsql.ebi.ac.uk:4157/'.$db_name;
        }

    } else {
        # Ensembl
        if((48<=$rel) and ($rel<=$last_available_rel)) {
            return "mysql://anonymous\@ensembldb.ensembl.org:5306/$db_name";
        } elsif((29<=$rel) and ($rel<=47)) {
            return "mysql://anonymous\@ensembldb.ensembl.org:4306/$db_name";
        } elsif((24<=$rel) and ($rel<=28)) {
            return "mysql://anonymous\@ensembldb.ensembl.org:4306/${db_name}_1";
        }
    }

    die "Release $rel cannot be reached\n";
}


sub get_contents {
    my ($rel, $table) = @_;

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url($rel) )->dbc();

    my $dbID_field = $table.'_id';
    my $joined_fields = join(", ", $dbID_field, @{$fields{$table}});
    my $sql = "SELECT $joined_fields FROM $table GROUP BY $dbID_field";
    if (($table eq 'method_link_species_set') and ($rel ne 'master') and ($rel < $first_table_release{species_set})) {
        # There is no species_set_id before release 38
        $sql = "SELECT method_link_species_set_id, method_link_id, 0 AS species_set_id, '' AS name FROM method_link_species_set GROUP BY method_link_species_set_id";
    }
    my $sth = $dbc->prepare($sql);
    $sth->execute();
    my %id_to_contents = ();
    while(my $h = $sth->fetchrow_hashref()) {
        my $set_id = $h->{$dbID_field};
        delete $h->{$dbID_field};
        $id_to_contents{$set_id} = $h;

        if ($table eq 'genome_db') {
            # Names used to be like "Homo sapiens" but now are like "homo_sapiens"
            my $name = $h->{name};
            $name =~ s/ /_/g;
            $h->{name} = lc $name;
        }
    }
    $sth->finish();

    return \%id_to_contents;
}


sub sprintf_contents {
    my  ($self, $table) = @_;
    return join('/', map {$self->{$_}} @{$fields{$table}}) || '';
}


sub find_species_set_names {
    my %name = ();
    foreach my $rel ($first_table_release{species_set_tag}..$last_available_rel) {
        my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url($rel) )->dbc();
        my $all_names = $dbc->db_handle->selectall_arrayref('SELECT species_set_id, value FROM species_set_tag WHERE tag = "genetree_display"');
        $name{$_->[0]} = 'genetree_display_'.$_->[1] for @$all_names;
        $all_names = $dbc->db_handle->selectall_arrayref('SELECT species_set_id, value FROM species_set_tag WHERE tag = "taxon_id"');
        $name{$_->[0]} = 'taxon_'.$_->[1] for @$all_names;
        $all_names = $dbc->db_handle->selectall_arrayref('SELECT species_set_id, value FROM species_set_tag WHERE tag = "name"');
        $name{$_->[0]} = $_->[1] for @$all_names;
    }
    my $master_dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url('master') )->dbc();
    my $sql = 'UPDATE species_set_header SET name = ? WHERE species_set_id = ?';
    my $sth = $master_dbc->prepare($sql);
    foreach my $species_set_id (keys %name) {
        print "species_set $species_set_id: set name to ".$name{$species_set_id}."\n";
        $sth->execute($name{$species_set_id}, $species_set_id);
    }
    $sth->finish();
}


sub find_first_last_rel {

    my ($table) = @_;
    my $master_contents = get_contents('master', $table);

    my $first_available_release = max($first_table_release{$table}, $first_division_release{$division});

    my %first_rel = ();
    my %last_rel = ();

    my $last = undef;

    foreach my $rel ($first_available_release..$last_available_rel) {
        my $rel_contents = get_contents($rel, $table);
        print "\n**** This is release $rel ****\n";
        #print Dumper($rel_contents);

        if ($last) {
            foreach my $dbID (keys %$last) {
                next unless $master_contents->{$dbID};
                if ($rel_contents->{$dbID}) {
                    if (grep {$last->{$dbID}->{$_} ne $rel_contents->{$dbID}->{$_}} @{$fields{$table}}) {
                        warn "Same ${table}_id ($dbID) but different contents !\n\twas ".sprintf_contents($last->{$dbID}, $table)."\n\tis ".sprintf_contents($rel_contents->{$dbID}, $table)."\n";
                    } else {
                        #print "$dbID still there and identical\n";
                    }
                } else {
                    if ($last_rel{$dbID}) {
                        warn "$table $dbID: ".sprintf_contents($last->{$dbID}, $table)." has been removed AGAIN in e$rel\n";
                    } else {
                        print "$table $dbID: ".sprintf_contents($last->{$dbID}, $table)." has been removed in e$rel\n";
                    }
                    $last_rel{$dbID} = $rel-1;
                }
            }
            foreach my $dbID (keys %$rel_contents) {
                next unless $master_contents->{$dbID};
                next if $last->{$dbID};

                if ($first_rel{$dbID}) {
                    warn "$table $dbID: ".sprintf_contents($rel_contents->{$dbID}, $table)." has REAPPEARED in e$rel\n"
                } else {
                    $first_rel{$dbID} = $rel;
                    print "$table $dbID: ".sprintf_contents($rel_contents->{$dbID}, $table)." has appeared in e$rel\n"
                }
            }
        } else {
            foreach my $dbID (keys %$rel_contents) {
                next unless $master_contents->{$dbID};

                $first_rel{$dbID} = $rel;
                print "$table $dbID: ".sprintf_contents($rel_contents->{$dbID}, $table)." has appeared in e$rel (or before)\n"
            }
        }

        $last = $rel_contents;

    }

    print "\n*** FINAL ***\n";

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url('master') )->dbc();
    my $table_to_update = $table eq 'species_set' ? 'species_set_header' : $table;
    my $sql = "UPDATE $table_to_update SET first_release = ?, last_release = ? WHERE ${table}_id = ? AND first_release IS NULL AND last_release IS NULL";
    my $sth = $dbc->prepare($sql);
    foreach my $dbID (sort {$a <=> $b} keys %$master_contents) {
        print $table, " ", $first_rel{$dbID} || 'NEVER', ' -> ', $last_rel{$dbID} || ($first_rel{$dbID} ? 'CUR' : 'NEVER'), ' ', sprintf_contents($master_contents->{$dbID}, $table), "\n";
        $sth->execute($first_rel{$dbID}, $last_rel{$dbID}, $dbID);
    }
    $sth->finish();
}


my $master_dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => get_compara_url('master') )->dbc();
sub run_command_once {
    $master_dbc->do(@_) unless $topup;
}


run_command_once('ALTER TABLE genome_db ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned');
find_first_last_rel('genome_db');
run_command_once('ALTER TABLE genome_db DROP COLUMN assembly_default');

run_command_once(q{
CREATE TABLE species_set_header (
  species_set_id              int(10) unsigned NOT NULL AUTO_INCREMENT,
  name                        varchar(255) NOT NULL default '',
  first_release               smallint,
  last_release                smallint,

  PRIMARY KEY (species_set_id)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
});

$master_dbc->do(q{
INSERT IGNORE INTO species_set_header
	SELECT species_set.species_set_id, IFNULL(value, ""), IF(SUM(first_release IS NULL)>0, NULL, MAX(first_release)), IF(SUM(first_release IS NULL)>0, NULL, IF(SUM(last_release IS NOT NULL)>0, MIN(last_release), NULL))
	FROM species_set JOIN genome_db USING (genome_db_id) LEFT JOIN species_set_tag ON species_set.species_set_id = species_set_tag.species_set_id AND tag = "name"
	GROUP BY species_set.species_set_id;
});
find_first_last_rel('species_set');
#run_command_once('DELETE FROM species_set_tag WHERE tag = "name"');
run_command_once('INSERT INTO species_set_header (name, first_release) VALUES ("empty", 82)');
#find_species_set_names();
$master_dbc->do('UPDATE species_set_header SET name = REPLACE(name, "oldcollection",  "") WHERE name LIKE "oldcollection%"');

run_command_once(q{
ALTER TABLE species_set
	MODIFY COLUMN species_set_id int(10) unsigned NOT NULL,
	MODIFY COLUMN genome_db_id int(10) unsigned NOT NULL,
	DROP INDEX species_set_id.
	ADD PRIMARY KEY (species_set_id,genome_db_id);
});

$master_dbc->do('UPDATE genome_db gdb1 JOIN genome_db gdb2 USING (name, assembly) SET gdb2.first_release = gdb1.first_release, gdb2.last_release = gdb1.last_release WHERE gdb1.genome_component IS NULL AND gdb2.genome_component IS NOT NULL;');

run_command_once(q{ALTER TABLE method_link_species_set ADD COLUMN first_release smallint unsigned, ADD COLUMN last_release smallint unsigned});
$master_dbc->do(q{
CREATE TEMPORARY TABLE method_link_species_set_time AS
	SELECT method_link_species_set_id, IF(SUM(species_set_header.first_release IS NULL)>0, NULL, MAX(species_set_header.first_release)) AS fr, IF(SUM(species_set_header.last_release IS NOT NULL)>0, MIN(species_set_header.last_release), NULL) AS lr
	FROM method_link_species_set JOIN species_set_header USING (species_set_id)
	GROUP BY method_link_species_set_id;
});
$master_dbc->do(q{UPDATE method_link_species_set JOIN method_link_species_set_time USING (method_link_species_set_id) SET first_release = fr, last_release = lr WHERE first_release IS NULL AND last_release IS NULL});
find_first_last_rel('method_link_species_set');

run_command_once("INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_81_82_b.sql|first_last_release')");

