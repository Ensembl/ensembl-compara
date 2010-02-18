#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
$0
  [--help]                    this menu
-host <host_name>
-port <port_number>
-user <user_name>
-pass <password>
-dbname <database_name>

\n";

my $help = 0;
my $db_conf             = {};

GetOptions('help' => \$help,
        'host=s'       => \$db_conf->{'-host'},
        'port=i'       => \$db_conf->{'-port'},
        'user=s'       => \$db_conf->{'-user'},
        'pass=s'       => \$db_conf->{'-pass'},
        'dbname=s'     => \$db_conf->{'-dbname'},
);

if ($help || scalar @ARGV != 1) {
  print $usage;
  exit 0;
}

my ($file) = @ARGV;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$db_conf);
my $dbc         = $compara_dba->dbc();

my $sth = $dbc->prepare("UPDATE family set description = ?, description_score =? where family_id = ?");

open(FILE, $file) || die "Could not open alignment file [$file], $!\n;";
while (my $line = <FILE>) {
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
close FILE;
$sth->finish;

$sth = $dbc->prepare("UPDATE family set description='UNKNOWN' where description is NULL");
$sth->execute;
$sth->finish;

