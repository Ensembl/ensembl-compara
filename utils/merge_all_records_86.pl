#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

use Data::Dumper;
use DBI;
use Getopt::Long qw(GetOptions);


# Help
sub usage {
  print("This script copies the data from old user db schema to the newer schema to make it compatible with this plugin.\n");
  print("\t-host=<database host>        \tServer address where database is hosted.\n");
  print("\t-dbname=<database name>      \tName of the accounts database\n");
  print("\t-user=<User name>            \tUser name for connecting to the db\n");
  print("\t-pass=<password>             \tPassword (default to null)\n");
  print("\t-port=<port>                 \tDatbaase port (defaults to 3306)\n");
  print("\t-type=<user/session/both>    \tType of the records to be copied\n");
  print("\t-days=<number of days>       \tNumber of days for which records should be preserved (default 90)\n");
  print("\t-after=<time since>          \tWhere clause for modified_at\n");
  print("\t--help                       \tDisplays this info and exits (optional)\n");
  exit;
}

sub create_table {
  my $dbh = shift;

  printf "\n---- Creating table all_record ----\n";

  my $sql = "CREATE TABLE IF NOT EXISTS `all_record` (
    `record_id` int(11) NOT NULL AUTO_INCREMENT,
    `record_type` enum('user','group','session') NOT NULL DEFAULT 'session',
    `record_type_id` int(11) DEFAULT NULL,
    `type` varchar(255) DEFAULT NULL,
    `code` varchar(255) DEFAULT NULL,
    `data` text,
    `created_by` int(11) DEFAULT NULL,
    `created_at` datetime DEFAULT NULL,
    `modified_by` int(11) DEFAULT NULL,
    `modified_at` datetime DEFAULT NULL,
    PRIMARY KEY (`record_id`),
    UNIQUE KEY `record_type_code` (`record_type`,`record_type_id`,`type`,`code`),
    KEY `record_type_idx` (`record_type_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1";

  my $sth = $dbh->prepare($sql);
  $sth->execute;
}

sub get_session_ids {
  my ($dbh, $hashref, $table, $sql) = @_;

  printf "  Getting unique sessions from %s\n", $table;

  my $sth = $dbh->prepare($sql);
  $sth->execute;
  my $sessions = $sth->fetchall_arrayref;

  printf "    TABLE %s: %s unique sessions found\n", $table, scalar @$sessions;

  $hashref->{$_->[0]} = 1 for @$sessions;
}

sub copy_records {
  my ($dbh, $table, $sql, $last_modified_hashref) = @_;

  printf "  Copying records from `%s` table\n", $table;

  my $sth = $dbh->prepare($sql);
  $sth->execute;

  my $records = $sth->fetchall_arrayref;

  printf "    %d records found\n", scalar @$records;

  my @filtered_records;
  my $last_modified = 0;

  foreach my $record (@$records) {
    my $data = eval("$record->[4]");

    # ignore any possible errors or incompatible data column
    next if $@ || !$data || !ref($data) || ref($data) ne 'HASH' || !scalar keys %$data;

    $last_modified = $record->[8];

    if ($record->[2] eq 'image_config') { # image configs save nodes specific data in a sub key 'nodes'

      if ($record->[3] && $record->[3] =~ /^(MultiBottom|MultiTop|alignslicebottom)$/) {

        foreach my $species (keys %$data) {
          my %nodes = map { $_ => delete $data->{$species}{$_} } grep $_ ne 'track_order', keys %{$data->{$species} || {}};
          $data->{$species}{'nodes'} = \%nodes if keys %nodes;
          delete $data->{$species} unless scalar keys %{$data->{$species}};
        }
      } else {

        my %nodes = map { $_ => delete $data->{$_} } grep $_ ne 'track_order', keys %$data;
        $data->{'nodes'} = \%nodes if keys %nodes;
      }

      next unless keys %$data
    }

    $record->[4] = Data::Dumper->new([ $data ])->Sortkeys(1)->Useqq(1)->Terse(1)->Indent(0)->Maxdepth(0)->Dump;

    push @filtered_records, $record;
  }

  $last_modified_hashref->{$table} = $last_modified;

  my $count = push_record($dbh, \@filtered_records);

  printf "    %d records copied to all_record\n", $count;

  return $count;
}

sub push_record {
  my ($dbh, $records) = @_;

  my $sth = $dbh->prepare("INSERT INTO all_record (
    `record_type`,
    `record_type_id`,
    `type`,
    `code`,
    `data`,
    `created_by`,
    `created_at`,
    `modified_by`,
    `modified_at`
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

  my $count = 0;
  for (@$records) {
    if ($sth->execute(@$_)) {
      $count++;
    } else {
      print "      Couldn't INSERT, performing an UPDATE\n";

      my $where = " WHERE
          `record_type`     = ? AND
          `record_type_id`  = ? AND
          `type`            = ? AND
          `code`            = ?
        ";

      my $sth1 = $dbh->prepare("SELECT modified_at FROM all_record $where");
      if ($sth1->execute($_->[0], $_->[1], $_->[2], $_->[3])) {
        my $rows = $sth1->fetchall_arrayref;
        if ($rows && @$rows && $rows->[0][0] eq $_->[8]) {
          next;
        }
      }

      my $sth2 = $dbh->prepare("UPDATE all_record SET `data` = ?, `modified_at` = ? $where");

      $count++ if $sth2->execute($_->[4], $_->[8], $_->[0], $_->[1], $_->[2], $_->[3]);
    }
  }

  return $count;
}


# Get arguments
my ($host, $dbname, $username, $pass, $type, $after);
my $port = 3306;
my $days = 90;
GetOptions(
  'host=s'    => \$host,
  'dbname=s'  => \$dbname,
  'user=s'    => \$username,
  'pass=s'    => \$pass,
  'port=i'    => \$port,
  'type=s'    => \$type,
  'days=i'    => \$days,
  'after=s'   => \$after,
  'help'      => \&usage
);


# Validate arguments
print "Argument(s) missing.\n" and usage if (!$host || !$dbname || !$username || !$type || $type !~ /^(both|session|user)$/);


# Connect to db
my $dbh = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $dbname, $host, $port), $username, $pass || '')
  or die('Could not connect to the database');


# Create table if it doesn't exist
create_table($dbh);


# last modified_at
my $last_modified = {};

# Copy session_records and configuration_record to all_record
if ($type eq 'session' || $type eq 'both') {

  my %sessions;

  printf "\n---- Fetching unique sessions for last %d days ----\n", $days;

  get_session_ids($dbh, \%sessions, 'configuration_details', "
    select distinct(cd.record_type_id) as session_id
    from configuration_details cd
    left join configuration_record cr
    on cr.record_id = cd.record_id
    where cd.record_type = 'session' and cd.servername not like '%archive%' and cr.modified_at > DATE(NOW()) - INTERVAL $days DAY");

  get_session_ids($dbh, \%sessions, 'session_record', "
    select distinct(session_id)
    from session_record
    where modified_at > DATE(NOW()) - INTERVAL $days DAY");

  my @sessions = keys %sessions;

  printf "Total unique sessions found in both tables: %d\n", scalar @sessions;

  print "\n---- Copying session record ----\n";

  my $i = 0;
  my $count = 0;
  my $where = $after ? " WHERE modified_at > '$after' AND " : " WHERE ";
  while (@sessions) {

    printf "ITERATION: %d\n", ++$i;

    my @subgroup    = splice @sessions, 0, 1000;
    my $session_ids = join(',', @subgroup);

    $count += copy_records($dbh, 'configuration_details', "
      select
        cd.record_type,
        cd.record_type_id,
        cr.type,
        cr.code,
        cr.data,
        null as created_by,
        cr.created_at,
        null as modified_by,
        cr.modified_at
      from configuration_record cr
      left join configuration_details cd
      on cr.record_id = cd.record_id
      $where record_type = 'session' and active = 'y' and is_set ='n' and servername not like '%archive%' and
      cd.record_type_id in ($session_ids)
      order by modified_at asc", $last_modified);

    $count += copy_records($dbh, 'session_record', "
      select
        'session' as record_type,
        session_id as record_type_id,
        type,
        code,
        data,
        null as created_by,
        created_at,
        null as modified_by,
        modified_at
      from session_record
      $where session_id in ($session_ids)
      order by modified_at asc", $last_modified);
  }

  printf "Total session records copied: %d\n", $count;
}


# copy user records from record table
if ($type eq 'user' || $type eq 'both') {
  my $where = $after ? " WHERE modified_at > '$after' " : '';

  my $count = copy_records($dbh, 'record', "
    select
      record_type,
      record_type_id,
      type,
      null as code,
      data,
      created_by,
      created_at,
      modified_by,
      modified_at
    from record $where
    order by modified_at asc", $last_modified);

  printf "Total user records copied: %d\n", $count;

}

for (keys %$last_modified) {
  printf " ---- NOTE: %s last modified row: %s\n", $_, $last_modified->{$_};
}

$dbh->disconnect;

print "\nDONE\n";

exit;
