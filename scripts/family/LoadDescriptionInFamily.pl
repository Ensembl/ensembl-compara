#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;
$| = 1;

my $usage = "
Usage: $0 options input_file

Options:
-host 
-dbname family dbname
-dbuser
-dbpass


\n";

my $help = 0;
my ($host,$dbname,$dbuser,$dbpass);

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass);

if ($help || scalar @ARGV != 1) {
  print $usage;
  exit 0;
}

my ($file) = @ARGV;

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => $host,
									 -user   => $dbuser,
									 -pass   => $dbpass,
									 -dbname => $dbname);

my $sth = $family_db->prepare("UPDATE family set description = ?, annotation_confidence_score =? where family_id = ?");

my $FH = IO::File->new();
$FH->open($file) || die "Could not open alignment file [$file], $!\n;";

while (my $line = <$FH>) {
  if ($line =~ /^(\d+)\t(.*)\t(\d+)$/) {
    my ($family_id,$description,$score) = ($1,$2,$3);
    if (defined $family_id &&
	defined $description &&
	defined $score) {
      $sth->execute($description,$score,$family_id);
      print STDERR "family_id $family_id description updated\n";
    } else {
      die "Not all argument defined
$line\n";
    }
  } else {
    die "wrong input format
$line\n";
  }
}

$FH->close;

exit 0;
