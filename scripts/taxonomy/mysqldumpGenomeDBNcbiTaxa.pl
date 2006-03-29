#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

my $usage = "
This script will dump the INSERT INTO statements to load into ncbi_taxa_nodes and ncbi_taxa_names
tables the needed data for the taxon_ids in genome_db table of a compara database

$0 --host ensembldb.ensembl.org -port 3306 --user anonymous --dbname ensembl_compara_38

";

my ($help, $host, $port, $user, $dbname);

GetOptions('help'   => \$help,
           'host=s' => \$host,
           'port=i' => \$port,
           'user=s' => \$user,
           'dbname=s' => \$dbname);

if ($help) {
  print $usage;
  exit 0;
}

if (!defined $host || !defined $port || !defined $user || !defined $dbname) {
  print $usage;
  exit 1;
}

Bio::EnsEMBL::Registry->no_version_check(1);

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
                                                     -port => $port,
                                                     -user => $user,
                                                     -dbname => $dbname);

my $gdba = $db->get_GenomeDBAdaptor;
my $ncbi_ta = $db->get_NCBITaxonAdaptor;

my %taxon_ids;
foreach my $gdb (@{$gdba->fetch_all}) {
  my $taxon = $ncbi_ta->fetch_node_by_taxon_id($gdb->taxon_id);
  $taxon_ids{$taxon->ncbi_taxid} = 1;
  while (my $parent = $taxon->parent) {
    $taxon_ids{$parent->ncbi_taxid} = 1;
    $taxon = $parent;
  }
}

my $sql_ncbi_taxa_nodes = "select taxon_id, parent_id, rank, genbank_hidden_flag, left_index, right_index, root_id from ncbi_taxa_nodes where taxon_id = ?";
my $sth_ncbi_taxa_nodes = $db->dbc->prepare($sql_ncbi_taxa_nodes);

my $sql_ncbi_taxa_names = "select taxon_id, name, name_class from ncbi_taxa_names where taxon_id = ?";
my $sth_ncbi_taxa_names = $db->dbc->prepare($sql_ncbi_taxa_names);

foreach my $taxon_id(keys %taxon_ids) {
  $sth_ncbi_taxa_nodes->execute($taxon_id);
  while (my $aref = $sth_ncbi_taxa_nodes->fetchrow_arrayref) {
    my ($taxon_id, $parent_id, $rank, $genbank_hidden_flag, $left_index, $right_index, $root_id) = @{$aref};
    print "INSERT INTO ncbi_taxa_nodes VALUES ($taxon_id, $parent_id, '$rank', $genbank_hidden_flag, $left_index, $right_index, $root_id);\n";
  }
  $sth_ncbi_taxa_names->execute($taxon_id);
  while (my $aref = $sth_ncbi_taxa_names->fetchrow_arrayref) {
    my ($taxon_id, $name, $name_class) = @{$aref};
    $name =~ s/\'/\\\'/g;
    $name =~ s/\"/\\\"/g;
    print "INSERT INTO ncbi_taxa_names VALUES ($taxon_id, '$name', '$name_class');\n";
  }
}

$sth_ncbi_taxa_names->finish;
$sth_ncbi_taxa_nodes->finish;
