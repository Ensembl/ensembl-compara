#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $usage = "
$0 -dbname compara23 [-reg_conf registry.conf_file]\n
";

my $help = 0;
my $dbname;
my $reg_conf;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
           'reg_conf=s' => \$reg_conf);

if ($help) {
  print $usage;
  exit 0;
}

Bio::EnsEMBL::Registry->load_all($reg_conf);

my $stored_max_alignment_length;
my $mc = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MetaContainer');
my $values = $mc->list_value_by_key("max_alignment_length");

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;

if(@$values) {
  $stored_max_alignment_length = $values->[0];
  print STDERR "actual stored max_alignment_length value is : $stored_max_alignment_length\n";
} else {
  print STDERR "No stored max_alignment_length value available\n"; 
}

my $sth = $dbc->prepare("SELECT max(consensus_end-consensus_start+1) FROM genomic_align_block");
$sth->execute();
my ($cs_max) = $sth->fetchrow_array();
$sth = $dbc->prepare("SELECT max(query_end-query_start+1) FROM genomic_align_block");
$sth->execute();
my ($qy_max) = $sth->fetchrow_array();

my $max_alignment_length = $cs_max;
if ($max_alignment_length < $qy_max) {
  $max_alignment_length = $qy_max;
}

if (! defined $stored_max_alignment_length) {
  $mc->store_key_value("max_alignment_length",$max_alignment_length + 1);
   print STDERR "Stored max_alignment_length value ",$max_alignment_length + 1," in meta table\n";
} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
  $mc->update_key_value("max_alignment_length",$max_alignment_length + 1);
  print STDERR "Updated max_alignment_length value ",$max_alignment_length + 1," in meta table\n";
} else {
  print STDERR "No update needed in meta table\n";
}

exit 0;
