#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;


my $usage = "

$0 -host ecs2.internal.sanger.ac.uk -dbuser ecs2dadmin -dbpass xxxx -dbname ensembl_compara_13_1 \
-conf_file /nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf
-genome_db_id1 1 genome_db_id2 2

";

my $help = 0;
my ($host,$dbname,$dbuser,$dbpass,$conf_file);
my ($genome_db_id1,$genome_db_id2);

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'dbname=s' => \$dbname,
	   'conf_file=s' => \$conf_file,
	   'genome_db_id1=i' => \$genome_db_id1,
	   'genome_db_id2=i' => \$genome_db_id2);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-conf_file => $conf_file,
						     -host => $host,
						     -dbname => $dbname,
						     -user => $dbuser,
						     -pass => $dbpass);

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $genome_db1 = $gdb_adaptor->fetch_by_dbID($genome_db_id1);
my $genome_db2 = $gdb_adaptor->fetch_by_dbID($genome_db_id2);


my $dnafrag_adaptor = $db->get_DnaFragAdaptor;

my $dbadaptor1 = $db->get_db_adaptor($genome_db1->name,$genome_db1->assembly);
my @chromosomes1 = @{$dbadaptor1->get_ChromosomeAdaptor->fetch_all};
my %chromosomes1;

foreach my $chr (@chromosomes1) {
  $chromosomes1{$chr->chr_name} = $chr;
}

my $dbadaptor2 = $db->get_db_adaptor($genome_db2->name,$genome_db2->assembly);
my @chromosomes2 = @{$dbadaptor2->get_ChromosomeAdaptor->fetch_all};
my %chromosomes2;

foreach my $chr (@chromosomes2) {
  $chromosomes2{$chr->chr_name} = $chr;
}

my $sth_synteny_region = $db->prepare("insert into synteny_region (rel_orientation) values (?)");
my $sth_dnafrag_region = $db->prepare("insert into dnafrag_region (synteny_region_id,dnafrag_id,seq_start,seq_end) values (?,?,?,?)");

my $line_number = 1;

while (defined (my $line = <>) ) {
  chomp $line;
  if ($line =~ /^(\S+)\t.*\t.*\t(\d+)\t(\d+)\t.*\t(-1|1)\t.*\t(\S+)\t(\d+)\t(\d+)$/) {
    my ($chr1,$start1,$end1,$rel,$chr2,$start2,$end2) = ($1,$2,$3,$4,$5,$6,$7);
    
    my $dnafrag1 = new Bio::EnsEMBL::Compara::DnaFrag;
    $dnafrag1->name($chr1);
    $dnafrag1->genomedb($genome_db1);
    $dnafrag1->type("Chromosome");
    $dnafrag1->start(1);
    $dnafrag1->end($chromosomes1{$chr1}->length);
    $dnafrag_adaptor->store_if_needed($dnafrag1);
    
    my $dnafrag2 = new Bio::EnsEMBL::Compara::DnaFrag;
    $dnafrag2->name($chr2);
    $dnafrag2->genomedb($genome_db2);
    $dnafrag2->type("Chromosome");
    $dnafrag2->start(1);
    $dnafrag2->end($chromosomes2{$chr2}->length);
    $dnafrag_adaptor->store_if_needed($dnafrag2);
  
    $sth_synteny_region->execute($rel);
    my $synteny_region_id = $sth_synteny_region->{'mysql_insertid'};
    $sth_dnafrag_region->execute($synteny_region_id,$dnafrag1->dbID,$start1,$end1);
    $sth_dnafrag_region->execute($synteny_region_id,$dnafrag2->dbID,$start2,$end2);
    print STDERR "synteny region line number $line_number loaded\n";
    $line_number++;
  } else {
    warn "The input file has a wrong format,
EXIT 1\n";
    exit 1;
  }

}
