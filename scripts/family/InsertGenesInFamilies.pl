#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
Usage: $0 options

Options:
-host 
-dbname
-dbuser
-dbpass
-conf_file

\n";

my $help = 0;
my $store = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $conf_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname,
                                                     -conf_file => $conf_file);

my $genome_dbs = $db->get_GenomeDBAdaptor->fetch_all;
my %genome_db;
foreach my $gdb (@{$genome_dbs}) {
  $genome_db{$gdb->taxon_id} = $gdb;
}

my $fa = $db->get_FamilyAdaptor;
my $ma = $db->get_MemberAdaptor;
my %already_stored;

foreach my $family_id (@{$fa->list_internal_ids}) {
  my $family = $fa->fetch_by_dbID($family_id);
  print STDERR "family: ", $family->stable_id,"\n";
  my $members_attributes = $family->get_Member_Attribute_by_source('ENSEMBLPEP');
  foreach my $member_attribute (@{$members_attributes}) {
    my ($member, $attribute) = @{$member_attribute};
    print STDERR "peptide: ", $member->stable_id,"\n";
    my $gdb = $genome_db{$member->taxon_id};
    my $ga = $gdb->db_adaptor->get_GeneAdaptor;
    my $gene = $ga->fetch_by_translation_stable_id($member->stable_id);

    next if (defined $already_stored{$gene->stable_id . "_" .$family->stable_id});

    print STDERR "gene family: ", $gene->stable_id," ",$family->stable_id,"\n";
    my $gene_member = $ma->fetch_by_source_stable_id('ENSEMBLGENE',$gene->stable_id);
    
    unless (defined $gene_member) {
      $gene = $gene->transform('toplevel');
      unless (defined $gene) {
        warn "gene->transform method failed\n";
      }
      $gene_member = new Bio::EnsEMBL::Compara::Member;
      $gene_member->stable_id($gene->stable_id);
      $gene_member->taxon_id($member->taxon_id);
      $gene_member->description("NULL");
      $gene_member->genome_db_id($gdb->dbID);
      $gene_member->chr_name($gene->seq_region_name);
      $gene_member->chr_start($gene->seq_region_start);
      $gene_member->chr_end($gene->seq_region_end);
      $gene_member->sequence("NULL");
      $gene_member->source_name("ENSEMBLGENE");
    }

    my $gene_attribute = new Bio::EnsEMBL::Compara::Attribute;
    $gene_attribute->cigar_line("NULL");

    $fa->store_relation([ $gene_member,$gene_attribute ],$family);
    $already_stored{$gene_member->stable_id . "_" .$family->stable_id} = 1;
  }
}
