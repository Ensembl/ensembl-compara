#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::Registry;

$| = 1;

my $usage = "
$0
  [--help]                    this menu
   --dbname string            (e.g. compara25) one of the compara destination database Bio::EnsEMBL::Registry aliases
  [--reg_conf filepath]       the Bio::EnsEMBL::Registry configuration file. If none given, 
                              the one set in ENSEMBL_REGISTRY will be used if defined, if not
                              ~/.ensembl_init will be used.
\n";

my $help = 0;
my ($dbname,$reg_conf);

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'reg_conf=s' => \$reg_conf);

if ($help || scalar @ARGV != 1) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

my ($file) = @ARGV;

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;
my $sth = $dbc->prepare("UPDATE family set description = ?, description_score =? where family_id = ?");

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
$sth->finish;

exit 0;
