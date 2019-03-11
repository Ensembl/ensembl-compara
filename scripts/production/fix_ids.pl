#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

=head1 NAME

fix_ids.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script will reassign a given set of ids throughout a database. The script
will check for all occurrences of the id in the database and generate a list of
UPDATE commands.

The ids can be defined on command line or in a YML file.

=head1 SYNOPSIS

  perl fix_ids.pl --help

  perl fix_ids.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_url_or_alias
    [--id_name name_of_id]
    [--from_id 123]
    [--to_id 456]
    [--file_of_ids /path/to/yml/file]
    [--offset_first]
    [--dry_run]
    [--no_dry_run]

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--compara compara_db_url_or_alias>

The compara database to update. You can use either the URL or any of the
aliases given in the registry_configuration_file

=item B<[--id_name name_of_id]>

Name of id you wish to update (e.g. species_set_id)

=item B<[--from_id 123]>

Current value of the id

=item B<[--to_id 456]>

Desired value of the id

=item B<[--file_of_ids /path/to/yml/file]>

Path to YML formatted file defining ids and their mappings (see 
ensembl-compara/scripts/production/fix_ids.sample.yml). Format is

name_of_id:
    from_id: to_id

=item B<[--offset_first]>

When setting ids to values that may already exist, it's a good idea to
offset all of the ids first and then set them to their final value. Turn
this option on. Default offset = 100000000000

=item B<[--dry_run]>

Only write commands to STDOUT, don't perform update on db. This is on by
default.

=item B<[--no_dry_run]>

Perform the update on the database

=back

=cut

use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;
use YAML::Tiny;

use Data::Dumper;

my ($help, $reg_conf, $compara_db, $id_name, $from_id, $to_id, $file_of_ids, $offset_first, $dry_run, $no_dry_run);

GetOptions(
	'help'           => \$help,
	'reg_conf=s'     => \$reg_conf,
	'compara=s'      => \$compara_db,    
	'id_name=s'      => \$id_name,
	'from_id=s'      => \$from_id,
	'to_id=s'        => \$to_id,
	'file_of_ids=s'  => \$file_of_ids,
	'offset_first=i' => \$offset_first,
	'dry_run!'       => \$dry_run,
	'no_dry_run!'    => \$no_dry_run,
);

$dry_run = $no_dry_run ? 0 : 1 unless $dry_run;
$offset_first = 100000000000 if defined $offset_first && $offset_first == 1;

die &helptext unless ( $compara_db && (($id_name && $from_id && $to_id) || $file_of_ids) );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if ($reg_conf);
my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );

my %id_map;
if ( $file_of_ids ) {
	my $yaml = YAML::Tiny->read( $file_of_ids );
	%id_map = %{ $yaml->[0] };
} else {
	$id_map{$id_name} = {$from_id => $to_id};
}

my (@offset_first_sql_list, @update_sql_list);
my $db_name = $dba->dbc->dbname;
foreach my $this_id_name ( keys %id_map ) { 
	# find all tables with specific column name
	print STDERR "Identifying all tables with '$this_id_name'...\n";
	my $get_tables_sql = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE column_name = '$this_id_name' AND TABLE_SCHEMA='$db_name'";
	my $tables_sth = $dba->dbc->prepare($get_tables_sql);
	$tables_sth->execute;

	my $sql_result_tables = $tables_sth->fetchall_arrayref;
	my @relevant_tables = map {$_->[0]} @$sql_result_tables;
	print STDERR "Found " . scalar @relevant_tables . " tables!\n\n";

	
	foreach my $this_from_id ( keys %{ $id_map{$this_id_name} } ) {
		my $this_to_id = $id_map{$this_id_name}->{$this_from_id};
		# loop through them and change the id
		foreach my $this_table ( @relevant_tables ) {
			if ( $offset_first ) {
				my $offset_first_id = $this_from_id + $offset_first;
				# create 2 lists of SQL command - first to offset_first the ids, then update them to their final value
				push( @offset_first_sql_list, "UPDATE $this_table SET $this_id_name = $offset_first_id WHERE $this_id_name = $this_from_id;");
				push( @update_sql_list, "UPDATE $this_table SET $this_id_name = $this_to_id WHERE $this_id_name = $offset_first_id;");
			} else {
				push( @update_sql_list, "UPDATE $this_table SET $this_id_name = $this_to_id WHERE $this_id_name = $this_from_id;");
			}
		}
	}
}

my @command_list = ( @offset_first_sql_list, @update_sql_list );
unshift @command_list, "SET FOREIGN_KEY_CHECKS = 0;";
push @command_list, "SET FOREIGN_KEY_CHECKS = 1;";

if ( $dry_run ) {
	print join( "\n", @command_list ) . "\n";
} else {
	print STDERR "\n!! EXECUTING UPDATE !!\n\n"
	# my $update_sth = $dba->dbc->prepare( join('', @command_list) );
	# $update_sth->execute();
}

sub helptext {
	my $message = <<"END_MESSAGE";

Usage examples:
    # print UPDATE commands to change seq_member_id 123 to 456
    fix_ids.pl -compara <database_url> -id_name seq_member_id -from_id 123 -to_id 456

    # perform update on database with alias <db_alias> using ids defined in YML file
    fix_ids.pl -reg_conf /path/to/reg_conf -compara <db_alias> -file_of_ids /path/to/yml --no_dry_run

See POD for more

END_MESSAGE
    return $message;
}
