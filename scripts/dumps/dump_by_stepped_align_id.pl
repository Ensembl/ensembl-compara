#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $host   = 'ecs1b.sanger.ac.uk';
my $dbname = 'abel_compara_human_mouse';
my $dbuser = 'ensro';
my $output;

GetOptions('host:s' => \$host,
	   'dbname:s' => \$dbname,
	   'dbuser:s' => \$dbuser,
	   'o:s' => \$output);

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

open SQL, "$sql_file" || die "could not open $sql_file; $!\n";
my $sql_query = <SQL>;
close SQL;
chomp $sql_query;

my $ga = $db->get_GenomicAlignAdaptor();

foreach my $gid ( $ga->list_align_ids() ) {

  my $local_sql_query = $sql_query;
  $local_sql_query =~ s/<align_id>/$gid/g;

  my $sth = $db->prepare("$local_sql_query");
  unless ($sth->execute()) {
    $db->throw("Failed execution of a select query");
  }

  while (my @columns = $sth->fetchrow_array()) {
    print $output join("\t",@columns),"\n";
  }

}

close $output;
