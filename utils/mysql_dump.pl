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


# Script for dumping the mysql files for the release
# script can be run for different hostname (one connection at a time ).
# hostname= is for the hostname of the database server (one hostname at a time)
# port= is for port number to listen to on the database server
# username= is for username to login on the database server
# pass= is for the password for the database server
# path= is for path where to dump the mysql files. By default it will dump where the script is run
# ex: perl dump.pl 60 hostname=xxx port=xxxx username=xxxx pass=xxxx
#
# Can be run for specific databasename, table name.
# db= is for databasename (one at a time no comma separated list allowed)
# table= is for tablename, can be a list of comma separated tablenames (no space) and should specify databasename (db=) for this to work
# ex: perl dump.pl 60 hostname=xxx port=xxxx username=xxxx pass=xxxx db=ensembl_mart table=meta_conf__user__dm,meta_template__template__main


use strict;
use Time::HiRes qw(time);
use constant MAX => 1024 * 1024 * 1024;
use DBI;

my $VERSION = shift @ARGV; #release version should always be the first argument when running the script

my ($arg,$db,$table_name,$hostname,$PORT,$USER,$PASS,$path);
foreach my $row (@ARGV)
{
  $row =~ s/,/|/g if($row =~ /table/i);                         #only argv table are allowed to have comma separated list
  ($arg,$db)        = split(/=/,$row) if($row =~ /db=/i);       #splitting ARGV db for different database name
  ($arg,$table_name)= split(/=/,$row) if($row =~ /table/i);     #splitting ARGV table for different table name 
  ($arg,$hostname)  = split(/=/,$row) if($row =~ /hostname/i);
  ($arg,$PORT)      = split(/=/,$row) if($row =~ /port/i);
  ($arg,$USER)      = split(/=/,$row) if($row =~ /username/i);
  ($arg,$PASS)      = split(/=/,$row) if($row =~ /pass/i);
  ($arg, $path)     = split(/=/,$row) if($row =~ /path/i);
  
}
if($table_name && !$db){
  print "[ERROR]No database specified!!! include db= when running the script for specific table.\n\n";
  exit;
}

my $current_directory = `pwd`;
chomp($current_directory);

chomp($path);
$current_directory = $path if($path);

my $sub_dir      = "$current_directory/release-$VERSION";
mkdir "$sub_dir";
#my $hostname = `hostname`;

our $ST = time;
chomp $hostname;
open( LH, ">$current_directory/$hostname.log" );


my $C = "mysql -h$hostname -P$PORT -u$USER -p$PASS -e 'show databases'";
my @databases = `mysql -h$hostname -P$PORT -u$USER -p$PASS -e 'show databases'`; 
shift(@databases);
if($db && !grep(/^($db)$/, @databases)){
  print "[ERROR]Could not find database::$db on server::$hostname!!! \n";
  exit;
}

foreach my $db_name ( @databases ) {
  chomp($db_name);
  if($db){
    next if($db_name !~ /$db/);
    log_msg("[INFO]Dumping whole database::$db") if(!$table_name);
  }
  log_msg( $db_name );
  my $dbh = DBI->connect("dbi:mysql:$db_name:$hostname:$PORT",$USER,$PASS);
  my $DIR = "$sub_dir/$db_name";
  my $SQL = '';
 
  system( "rm -r $sub_dir/$db_name")  if($db && !$table_name);  
  system( "mkdir $DIR" );

  system( "chmod 777 $DIR");
  chdir( $DIR );  
  my @tables = map {@$_} @{$dbh->selectall_arrayref('show tables')};

  #check if table exist when running script for specific tables
  if($table_name){
    foreach my $each_table (split(/\|/,$table_name)){
      log_msg("[WARN]Could not find table::$each_table in database::$db!!!") if(!grep(/^($each_table)$/,@tables));
    }
  }

  foreach my $table (@tables) {
    if($table_name && $db){
      next if($table !~ /$table_name/);
      log_msg("[INFO]Dumping table::$table from database::$db");
    }
    system("rm $DIR/$table.txt.gz") if($table_name);   #got to remove the old file first 
    my $FN = "$DIR/$table.txt";

    log_msg( " |- dumping $table" );
    my($M,$T)=$dbh->selectrow_array("show create table $table;" );
    $SQL .= "$T;\n\n";
    $dbh->do( "select * into outfile '$FN' FIELDS ESCAPED BY '\\\\' from $table" );
    log_msg( " `- zip $table (".(-s $FN).')' );
    system( "gzip -9 -f $FN" );
  }
  
  #only do this when dumping whole database
  if(!$db && !$table_name){
    open O,">$db_name.sql";
    print O $SQL;
    close O;
  }
  log_msg( "  Computing checksums" );
  system "gzip -9 -f $db_name.sql"  if(!$db && !$table_name);
  system "rm CHECKSUMS.gz" if($db && $table_name);
  system "sum *.sql.gz *.txt.gz > CHECKSUMS";
  system "gzip -9 -f CHECKSUMS";
  log_msg( "  finished" );
}

close LH;

sub log_msg {
  printf LH "%10.3f %s\n", time-$ST, join ' ', @_;
}

1;
