#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;

use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -dbname ensembl_compara_database
   -port eg 3352 (default)
";

my $host = "127.0.0.1";
my $dbname = "ensembl_compara_javi_22_1";
my $dbuser = 'ensro';
my $dbpass;
my $help = 0;
my $port=3352;

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'port=i'  => \$port
           );

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Connecting to compara database

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -pass => $dbpass,
						      -port => $port,
						      -dbname => $dbname);

my $gdba = $db->get_GenomeDBAdaptor();
my $mlssa = $db->get_MethodLinkSpeciesSetAdaptor();

my $mlss;

print "Test fetch_all\n";
  $mlss = $mlssa->fetch_all;
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_by_dbID(1)\n";
  $mlss = $mlssa->fetch_by_dbID(1);
  if (defined($mlss)){
    print " + ", $mlss->dbID, " - ", $mlss->method_link_type, " (", $mlss->method_link_id, ") is: ";
    print join(" - ", map {$_->name} @{$mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_by_dbID(0) [SHOULD BE NULL]\n";
  $mlss = $mlssa->fetch_by_dbID(0);
  if (defined($mlss)){
    print " + ", $mlss->dbID, " - ", $mlss->method_link_type, " (", $mlss->method_link_id, ") is: ";
    print join(" - ", map {$_->name} @{$mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_all_by_method_link(1)\n";
  $mlss = $mlssa->fetch_all_by_method_link(1);
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_all_by_method_link(\"BLASTZ_NET\")\n";
  $mlss = $mlssa->fetch_all_by_method_link("BLASTZ_NET");
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_all_by_method_link_id(1)\n";
  $mlss = $mlssa->fetch_all_by_method_link_id(1);
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_all_by_method_link_type(\"BLASTZ_NET\")\n";
  $mlss = $mlssa->fetch_all_by_method_link_type("BLASTZ_NET");
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_all_by_genome_db_id method(1)\n";
  $mlss = $mlssa->fetch_all_by_genome_db_id(1);
  foreach my $this_mlss (sort {$a->dbID <=> $b->dbID } @$mlss) {
    print " + ", $this_mlss->dbID, " - ", $this_mlss->method_link_type, " (", $this_mlss->method_link_id,
        ") is: ", join(" - ", map {$_->name} @{$this_mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_by_method_link_and_genome_db_ids(\"BLASTZ_NET\", [1, 2])\n";
  $mlss = $mlssa->fetch_by_method_link_and_genome_db_ids("BLASTZ_NET", [1, 2]);
  if (defined($mlss)){
    print " + ", $mlss->dbID, " - ", $mlss->method_link_type, " (", $mlss->method_link_id, ") is: ";
    print join(" - ", map {$_->name} @{$mlss->species_set}), "\n";
  }
  print "\n";

print "Test fetch_by_method_link_and_genome_db_ids(\"BLASTZ_NET\", [1]) [SHOULD BE NULL]\n";
  $mlss = $mlssa->fetch_by_method_link_and_genome_db_ids("BLASTZ_NET", [1]);
  if (defined($mlss)){
    print " + ", $mlss->dbID, " - ", $mlss->method_link_type, " (", $mlss->method_link_id, ") is: ";
    print join(" - ", map {$_->name} @{$mlss->species_set}), "\n";
  }
  print "\n";

print "Test store method (dbID=1)\n";
  $mlss = $mlssa->fetch_by_dbID(1);
  $mlss = $mlssa->store($mlss);
  if (defined($mlss)){
    print " + ", $mlss->dbID, " - ", $mlss->method_link_type, " (", $mlss->method_link_id, ") is: ";
    print join(" - ", map {$_->name} @{$mlss->species_set}), "\n";
  }
  print "\n";

exit 0;
