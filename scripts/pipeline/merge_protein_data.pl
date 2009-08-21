#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Cwd;

my $cwd = getcwd;

my $help = 0;
my $nobackup = 0;
my ($source_db, $destination_db, $host, $port, $user, $pass, $socket);

GetOptions('help' => \$help,
           'nobackup' => \$nobackup,
           'src_db=s' => \$source_db,
           'dest_db=s' => \$destination_db,
           'host=s' => \$host,
           'port=i' => \$port,
           'user=s' => \$user,
           'pass=s' => \$pass,
           'socket=s' => \$socket);


my $usage = "
This script needs to be run as mysqlens user on the MySQL server machine where
both source and destination databases are. Furthermore the working directory must
be /mysql/data_3306/tmp. Merging can only work if all tables are MyISAM (NOT InnoDB).

./merge_protein_data.pl

--src_db string   source MYSQL database name
--dest_db string  destination MYSQL database name
--host string     MySQL hostname
--port integer    MySQL port
--user string     MySQL server username
--pass string     MySQL server password
--socket string   mysql socket i.e. /mysql/data_3306/mysql.sock

[--nobackup]      unless specify, a database mysqldump of the source db
                  is done and stored in the local /mysql/data_3306/tmp directory

";

if ($help) {
  print $usage;
  exit 0;
}

unless ($cwd eq "/mysql/data_3306/tmp") {
  warn("
 Run this script in /mysql/data_3306/tmp directory
 EXIT 1\n\n");
  exit 1;
}

my @tables_to_merge = qw(
member
sequence
family
family_member
homology
protein_tree_node
protein_tree_member
protein_tree_tag
super_protein_tree_node
super_protein_tree_member
super_protein_tree_tag
protein_tree_stable_id
mapping_session
stable_id_history
sitewise_aln
homology_member);


open F, "mysql -h$host -u$user -p$pass -N -e 'show tables like \"peptide_align_feature%\"' $source_db |";

while (<F>) {
  chomp;
  push @tables_to_merge, $_;
}

close F;

# First do a backup in case something goes wrong.

unless ($nobackup) {
  my $back_up_dir = "/mysql/data_3306/tmp/$source_db";

  unless(-d $back_up_dir) {
    mkdir $back_up_dir;
  }

  foreach my $table (@tables_to_merge) {
    unless (system("mysqldump -h$host -u$user -p$pass -d  $source_db $table > $back_up_dir/$table.sql") == 0) {
      warn("
 Cannot back up $table table creation statement, $!
 EXIT 2\n\n");
      exit 2;
    };
    system("rm -f $back_up_dir/$table.txt.gz");
    unless (system("mysql -h$host -u$user -p$pass -S $socket -N -e 'select count(*) from $table' $source_db | while read i; do for ((j=0;j <= i;j=j+1000000));do mysql -h$host -u$user -p$pass -S $socket -N -e \"select * from $table limit \$j,1000000\" $source_db | gzip -c >> $back_up_dir/$table.txt.gz ;done ;done ") == 0) {
      warn("
 Cannot back up $table table data, $!
 EXIT 3\n\n");
      exit 3;
    }
  }
}

my $mysql_databases_directory = "/mysql/data_3306/databases";

foreach my $table (@tables_to_merge) {
  unless (system("mysql -h$host -u$user -p$pass -e \"DROP TABLE IF EXISTS \\\`$table\\\`\" $destination_db") == 0) {
    warn("
 Cannot drop $table table in $destination_db database, $!
 EXIT 6\n\n");
    exit 6;
  }
  unless (system("ln /mysql/data_3306/databases/$source_db/$table.* /mysql/data_3306/databases/$destination_db") == 0) {
    warn("
 Cannot create a hard link for /mysql/data_3306/databases/$source_db/$table.* tables, $!
 EXIT 7\n\n");
    exit 7;
  }
  unless (system("mysql -h$host -u$user -p$pass -e \"DROP TABLE IF EXISTS \\\`$table\\\`\" $source_db") == 0) {
    warn("
 Cannot drop $table tables in $source_db database, $!
 EXIT 8\n\n");
    exit 8;
  }
}
