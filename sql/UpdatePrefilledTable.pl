#!/usr/local/ensembl/bin/perl -w

#
# updates the external db tables on all of the core databases on a given host
#


use strict;

use Getopt::Long;
use DBI;
use IO::File;

my ( $host, $user, $pass, $port, $dbname, $table_name, $file);

GetOptions( "host=s", \$host,
	    "user=s", \$user,
	    "pass=s", \$pass,
	    "port=i", \$port,
	    "table=s", \$table_name,
	    "file=s", \$file,
            "dbname=s", \$dbname,
	  );

#host, user, pass, table, file and dbname are required
usage() if(!$host || !$user || !$pass || !$table_name || !$file || !$dbname);

$port ||= 3306;

my $dsn = "DBI:mysql:host=$host;port=$port";

my $db = DBI->connect( $dsn, $user, $pass, {RaiseError => 1} );

#
# read all of the new external_db entries from the file
#

my $fh = IO::File->new();
$fh->open($file) or die("could not open input file $file");

my @instances;
my @column_names;

while (<$fh>) {
  next if (/^$/);
  chomp;
  my @values = split(/\t/);
  unless (scalar @column_names) {
    @column_names = @values;
    next;
  }
  my %instance;
  for (my $i = 0; $i <= $#column_names; $i++) {
    my $column_name = $column_names[$i];
    $instance{$column_name} = $values[$i];
  }

  push @instances, \%instance;
}

$fh->close();

print STDERR "updating $dbname\n";
$db->do("use $dbname");
my $sql = "DELETE FROM $table_name";
my $sth = $db->prepare($sql);
$sth->execute();
$sth->finish();

$sql = "INSERT INTO $table_name (";
$sql .= join ",",@column_names;
$sql .= ") VALUES (";
$sql .= join ",",split " ",'? ' x scalar @column_names;
$sql .= ")";

$sth = $db->prepare($sql);

foreach my $instance (@instances) {
  $sth->execute(map {$instance->{$_}} @column_names);
}

$sth->finish();

print STDERR "updates complete\n";


sub usage {
  print STDERR <<EOF

             Usage: UpdatePrefilledTable.pl options
 Where options are: -host hostname 
                    -user username 
                    -pass password 
                    -port port_of_server optional
                    -file the path of the file containing the insert statements
                          of the entries of the external_db table
                    -dbname db
                          the name of the database to update.
                    -table table_name
                          the name of the table to update.

 E.g.:

 UpdatePrefilledTable.pl -host ecs2c -file genome_db.txt -table genome_db-user ensadmin -pass secret -dbname ensembl_compara_14_1 

EOF
;
  exit;
}
