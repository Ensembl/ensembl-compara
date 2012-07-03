#!/usr/bin/perl

# This table will serve both for cafe and as a general table of families descriptions.
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
# select * from method_link_species_set where method_link_species_set_id = 40074;
# select * from species_set where species_set_id = 33880;
my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $host = "127.0.0.1";
my $port = "2914";
my $user = "ensadmin";
my $pass = "ensembl";
my $dbname = "lg4_ensembl_compara_64";
my $url;
my $mlss = 40076;
my $exclude_lcg = 0;
my $registry_file;
my $compara_url;

GetOptions(
	   "h|help" => \$help,
	   "url=s" => \$url,
	   "compara_url=s" => \$compara_url,
	   "conf|registry=s" => \$registry_file,
	   "mlss:i" => \$mlss,
	   "lcg" => \$exclude_lcg,
	   "db" => \$dbname,
	   "host" => \$host,
	  );

if ($help) {
  print <<'EOH';
db2cafe_table.pl -- Get a table compatible for cafe with family frequencies (by genome db)

Options
    [-h|--help]                   Prints this document and exits

 [DB Connection]
    --url <string>           Database url location of the form,
                             mysql://username[:password]\@host[:port]/[release_version]
                             you can also set the connection through the host/port/pass/user/db options (below)
    --compara_url <string>   Compara URL
    --[conf|registry]        Registry file
    --host <string>          Host server
    --port <integer>         Server port
    --pass <string>          Server password
    --user <string>          Server user
    --db <string>            Database name

 [Other options]
    --mlss <integer>         Method link species set in the compara database
    --lcg                    Use this option to filter out low-coverage genomes

EOH
exit(0);

}

if ($registry_file) {
  die unless (-e $registry_file);
  $reg->load_all($registry_file);
} elsif ($url) {
  $reg->load_registry_from_url($url);
} elsif (!$compara_url) {
  $reg->load_all();
}

$reg->no_version_check(1);

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} elsif ($host) {
  $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
							     -host => $host,
							     -port => $port,
							     -user => $user,
							     -dbname => $dbname,
							     -verbose => 1,
							     -pass => $pass
							    );
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

# Get all the adaptors
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $tree_adaptor = $compara_dba->get_GeneTreeAdaptor();
my $genomeDB_Adaptor = $compara_dba->get_GenomeDBAdaptor();

# Get all the species for the mlss:
my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($mlss);
my $species_set = $method_link_species_set->species_set_obj->genome_dbs();

my @sps_set = @$species_set;
if ($exclude_lcg) {
  my $lcg = low_coverage_genomes();

  @sps_set = grep {! is_in($_->taxon_id, $lcg)} @$species_set;
}

my @species_names = map {(split /_/, $_->name)[0]} @sps_set;

# Get the number of members per family
my $all_trees = $tree_adaptor->fetch_all(-tree_type => 'tree', -member_type => 'ncrna', -clusterset_id => 'default');
my $sth = $tree_adaptor->prepare('SELECT genome_db_id FROM gene_tree_node JOIN gene_tree_member USING (node_id) JOIN member USING (member_id) WHERE root_id = ?');
print "FAMILYDESC\tFAMILY\t", join("\t", @species_names), "\n";
for my $tree (@$all_trees) {
  my $root_id = $tree->root_id();
  my $model_name = $tree->stable_id() || $tree->get_tagvalue('model_name') || $tree->root_id();
  $sth->execute($root_id);

  my %species;
  while (my $row = $sth->fetchrow_arrayref) {
    $species{$row->[0]}++;
  }

  my @flds = ($model_name, $root_id, map {$species{$_->dbID} || 0} @sps_set);
  print join ("\t", @flds), "\n";
}



sub low_coverage_genomes {
  my $sql1 = "select species_set_id from species_set_tag where value = 'low-coverage'";
  my $sth1 = $compara_dba->dbc->prepare($sql1);
  $sth1->execute();
  my $ssid_row = $sth1->fetchrow_hashref;
  my $ssid = $ssid_row->{species_set_id};
  my $sql2 = "select genome_db_id from species_set where species_set_id = $ssid";
  my $sth2 = $compara_dba->dbc->prepare($sql2);
  $sth2->execute();
  my $genomeDB_ids = $sth2->fetchall_arrayref;
  my @db_ids = map {$_->[0]} @$genomeDB_ids;
  my @taxon_ids = map {get_taxon_id_from_dbID($_)} @db_ids;
  return \@taxon_ids;
}

sub is_in {
  my ($item, $arref) = @_;
  for my $el (@$arref) {
    if ($item eq $el) {
      return 1
    }
  }
  return 0
}

sub get_taxon_id_from_dbID {
  my ($dbID) = @_;
  my $genomeDB = $genomeDB_Adaptor->fetch_by_dbID($dbID);
  return $genomeDB->taxon_id();
}
