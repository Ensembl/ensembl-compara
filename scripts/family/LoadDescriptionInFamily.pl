#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
$0
  [--help]                    this menu
-descfile <file_name>
-host <host_name>
-port <port_number>
-user <user_name>
-pass <password>
-database <database_name>

\n";

my $help = 0;
my $db_conf             = {};
my $descfile;

GetOptions('help' => \$help,
        'descfile=s'   => \$descfile,
        'host=s'       => \$db_conf->{'-host'},
        'port=i'       => \$db_conf->{'-port'},
        'user=s'       => \$db_conf->{'-user'},
        'pass=s'       => \$db_conf->{'-pass'},
        'database=s'   => \$db_conf->{'-dbname'},
);

if ($help || !($descfile && $db_conf->{'-host'} && $db_conf->{'-user'} && $db_conf->{'-dbname'}) ) {
  print $usage;
  exit ($help ? 0 : 1);
}

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$db_conf);
my $dbc         = $compara_dba->dbc();

my $sth = $dbc->prepare("UPDATE family set description = ?, description_score =? where family_id = ?");

open(DESCFILE, $descfile) || die "Could not open descriptions file [$descfile], $!\n;";
while (my $line = <DESCFILE>) {
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
close DESCFILE;
$sth->finish;

$sth = $dbc->prepare("UPDATE family set description='UNKNOWN' where description is NULL");
$sth->execute;
$sth->finish;

