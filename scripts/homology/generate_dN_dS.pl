#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;

$| = 1;

my $help = 0;
my $store = 0;
my $host;
my $dbname;
my $dbport;
my $dbuser = "ensro";
my $dbpass;
my $conf_file;
my $id_file;
my $dir_output = ".";

my $codeml_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/codeml";

if (-e "/proc/version") {
  # it is a linux machine
  $codeml_executable = "/nfs/acari/abel/bin/i386/codeml";
}

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbport=s' => \$dbport,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file,
           'id_file=s' => \$id_file,
           'dir=s' => \$dir_output);

my $db;

if (defined $conf_file) {
  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                    -port   => $dbport,
                                                    -user   => $dbuser,
                                                    -pass   => $dbpass,
                                                    -dbname => $dbname,
                                                    -conf_file => $conf_file);
} else {
  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                    -port   => $dbport,
                                                    -user   => $dbuser,
                                                    -pass   => $dbpass,
                                                    -dbname => $dbname);
}

my $ha = $db->get_HomologyAdaptor;

my $homologies;

unless (defined $id_file) {
  $homologies = $ha->fetch_all;
} else {
  open ID, $id_file ||
    die "Can not open $id_file, $!\n";
  while (my $line = <ID>) {
    chomp $line;
    if ($line =~ /^(\d+)$/) {
      my $homology_id = $1;
      my $homology = $ha->fetch_by_dbID($homology_id);
      if (defined $homology) {
        push @{$homologies}, $homology;
      } else {
        warn "homology_id $homology_id not defined\n";
      }
    } else {
      die "Expecting an integer for each line in $id_file but there is \"$line\"";  
    }
  }
  close ID;
}

my $tmp_out = "/tmp/codeml.".time().rand(1000);

open O, ">$tmp_out" ||
  die "Can not open /tmp/$tmp_out";


foreach my $homology (@{$homologies}) {

  my $rand = time().rand(1000);

  open F, ">/tmp/seq.$rand.phy" ||
    die "Can not open /tmp/seq.$rand.phy";
  my $sa = $homology->get_SimpleAlign("cdna");
  my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                    -fh => \*F,
                                    -format => "phylip",
                                    -idlength => 20);

  print $alignIO $sa;
  close F;
  
  print O $homology->dbID," ",$homology->description," ";
# need to retrieve the codeml.ctl original file so that we can use the original codeml, not 
# the one Llew modified with hard coded parameters
  unless (system("$codeml_executable < /tmp/seq.$rand.phy > /tmp/seq.$rand.codeml 2> /tmp/seq.$rand.codeml.err") == 0) {
    unlink glob("/tmp/*$rand*");
    warn "error in codeml, $!, for homology stable_id ". $homology->stable_id,"\n";
    print O "codeml FAILED\n";
    next;
  }
  my $no_result = 1;
  open CODEML, "/tmp/seq.$rand.codeml";
  while (my $line = <CODEML>) {
    next if ($line =~ /^$/);
    last if ($line =~ /^\s+N\s+S\s+dN\s+dS\s+dN\/dS\s+lnL$/);
#    CG10220-PA      ENSANGP00000021079      994.3   250.7   0.51651 6.69608 0.07714 -3037.747 
#                                            N       S       dN      dS      dN/dS   lnL
    if ($line =~ /^\S+\t\S+\t\d+(\.\d*)?\t\d+(\.\d*)?\t\d+(\.\d*)?\t\d+(\.\d*)?\t\d+(\.\d*)?\t-?\d+(\.\d*)?$/) {
      print O $line;
      $no_result = 0;
    }
  }
  close CODEML;
  unlink glob("/tmp/*$rand*");
  if ($no_result) {
    print O "codeml FAILED\n";
  }
  next;
}

my $final_out_file = $dir_output . "/" . $id_file . ".codeml";
unless (system("gzip -c $tmp_out > $final_out_file.gz") == 0) {
  unlink glob("$tmp_out");
  die "error in gzip -c , $tmp_out $!\n";
}

unlink glob("$tmp_out");

close O;
