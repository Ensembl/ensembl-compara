#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
Usage: $0 [options] SQL_query_file

Dump from compara database, following the SQL query in SQL_query_file
which must contain one and only one 'align_id=?' statement.

 -help show this menu
 -h    compara database hostname
 -d    compara database name
 -u    database user name (default: ensro)
 -o    output file name

";

my $help = 0;
my $host;#   = 'ecs1b.sanger.ac.uk';
my $dbname;# = 'abel_compara_humanNCBI28_mouse';
my $dbuser = 'ensro';
my $output;

GetOptions('help' => \$help,
	   'h=s' => \$host,
	   'd=s' => \$dbname,
	   'u=s' => \$dbuser,
	   'o:s' => \$output);

die $usage if ($help);
if (! defined $host) {
  warn "\n Must specify a host with -h\n";
  die $usage;
} elsif (! defined $dbname) {
  warn "\n Must specify a database with -d\n";
  die $usage;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
						     -dbname => $dbname,
						     -user => $dbuser);

die "\nSpecifie a file containing your SQL query\n\n" unless (scalar @ARGV);

my $sql_file = shift @ARGV;

if (! defined $output) {
  $output = \*STDOUT;
} elsif (defined $output && $output ne "") {
  $output .= ".gz";
  open OUTPUT, "| gzip -c > $output" || die "Could not open gzip -c pipe; $!\n";
  $output = \*OUTPUT;
} else {
  $output = $sql_file.".gz";
  open OUTPUT, "| gzip -c > $output" || die "Could not open gzip -c pipe; $!\n";
  $output = \*OUTPUT;
}

print STDERR "Opening and reading SQL file...";

open SQL, "$sql_file" || die "could not open $sql_file; $!\n";
my $sql_query;
while (defined (my $line = <SQL>)) {
  if ($line =~ /^\#.*$/) {
    next;
  } else {
    chomp $line;
    $sql_query = $line;
    last;
  }
}
close SQL;

print STDERR "Done\n";

my $ga = $db->get_GenomicAlignAdaptor();

print STDERR "Preparing SQL query...";

my $sth = $db->prepare("$sql_query");

print STDERR "Done\n";
print STDERR "Getting list of align_ids and print in STDOUT...";

foreach my $gid ($ga->list_align_ids()) {

  unless ($sth->execute($gid)) {
    $db->throw("Failed execution of a select query");
  }
  
  while (my @columns = $sth->fetchrow_array()) {
    print $output join("\t",@columns),"\n";
  }
  
}

print STDERR "Done\n";

close $output;
