#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $usage = "
$0 -host ecs2c -dbuser ensadmin -dbpass xxxx -dbname ensembl_compara_14_1
";

my $help = 0;
my ($host,$dbname,$dbuser,$dbpass);

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'dbname=s' => \$dbname);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
						     -dbname => $dbname,
						     -user => $dbuser,
						     -pass => $dbpass);

my $stored_max_alignment_length;
my $values = $db->get_MetaContainer->list_value_by_key("max_alignment_length");

if(@$values) {
  $stored_max_alignment_length = $values->[0];
  print STDERR "actual stored max_alignment_length value is : $stored_max_alignment_length\n";
} else {
  print STDERR "No stored max_alignment_length value available\n"; 
}

my $sth = $db->prepare("SELECT max(consensus_end-consensus_start+1) FROM genomic_align_block");
$sth->execute();
my ($cs_max) = $sth->fetchrow_array();
$sth = $db->prepare("SELECT max(query_end-query_start+1) FROM genomic_align_block");
$sth->execute();
my ($qy_max) = $sth->fetchrow_array();

my $max_alignment_length = $cs_max;
if ($max_alignment_length < $qy_max) {
  $max_alignment_length = $qy_max;
}

if (! defined $stored_max_alignment_length) {
  $db->get_MetaContainer->store_key_value("max_alignment_length",$max_alignment_length + 1);
   print STDERR "Stored max_alignment_length value $stored_max_alignment_length in meta table\n";
} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
  $db->get_MetaContainer->update_key_value("max_alignment_length",$max_alignment_length + 1);
  print STDERR "Updated max_alignment_length value ",$max_alignment_length + 1," in meta table\n";
} else {
  print STDERR "No update needed in meta table\n";
}

exit 0;
