#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
Usage: $0 options

i.e.

$0 

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-conf_file

\n";

my $help = 0;
my $store = 0;
my $host;
my $dbname;
my $dbuser;
my $dbpass;
my $conf_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => $host,
									 -user   => $dbuser,
									 -pass   => $dbpass,
									 -dbname => $dbname,
									 -conf_file => $conf_file);

my $external_name = "ENSEMBLGENE";

my $sth = $family_db->prepare("select external_db_id from external_db where name = ?");
$sth->execute($external_name);
my ($external_db_id) = $sth->fetchrow_array();

unless (defined $external_db_id) {
  $sth = $family_db->prepare("insert into external_db (name) values (?)");
  $sth->execute($external_name);
  $external_db_id = $sth->{'mysql_insertid'};
}

my %GeneAdaptors;
my $FamilyAdaptor = $family_db->get_FamilyAdaptor;
my $FamilyMemberAdaptor = $family_db->get_FamilyMemberAdaptor;
my $GenomeDBAdaptor = $family_db->get_GenomeDBAdaptor;

my $family_ids = $FamilyAdaptor->list_familyIds;

foreach my $family_id (@{$family_ids}) {
  my %gene_already_stored;
  my $family = $FamilyAdaptor->fetch_by_dbID($family_id);
  my $members = $family->get_members_by_dbname('ENSEMBLPEP');
  next unless (scalar @{$members});
  foreach my $member (@{$members}) {
    my $ga = fetch_GeneAdaptor_by_taxon($member->taxon_id);
    my $gene = $ga->fetch_by_Peptide_id($member->stable_id);

    next if (defined $gene_already_stored{$gene->stable_id});
    
    my $fm = new Bio::EnsEMBL::ExternalData::Family::FamilyMember;
    $fm->stable_id($gene->stable_id);
    $fm->taxon_id($member->taxon_id);
    $fm->external_db_id($external_db_id);
    $FamilyMemberAdaptor->store($family_id,$fm);
    $gene_already_stored{$gene->stable_id} = 1;
    print STDERR "Stored ",$gene->stable_id," in family $family_id\n";
  }
}

sub fetch_GeneAdaptor_by_taxon {
  my ($taxon_id) = @_;
  unless (defined $GeneAdaptors{$taxon_id}) {
    my $genome_db = $GenomeDBAdaptor->fetch_by_taxon_id($taxon_id);
    $GeneAdaptors{$taxon_id} = $genome_db->db_adaptor->get_GeneAdaptor;
  }
  return $GeneAdaptors{$taxon_id};
}
