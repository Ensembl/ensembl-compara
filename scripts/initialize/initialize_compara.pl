#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignBlockSet;
use Bio::EnsEMBL::Compara::AlignBlock;

my $host = 'ecs1d.sanger.ac.uk';
my $dbname = 'homo_sapiens_core_4_28';
my $dbuser = 'ensro';
my $dbpass = "";

&GetOptions('h=s' => \$host,
	    'd=s' => \$dbname,
	    'u=s' => \$dbuser);

$| = 1;

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
					     -user => $dbuser,
					     -dbname => $dbname);

#my $sth = $db->prepare("select id,length from contig limit 10;");
my $sth = $db->prepare("select c.id,c.length from contig c,static_golden_path s where s.raw_id=c.internal_id and s.chr_name=\"22\";");
unless ($sth->execute()) {
  $db->throw("Failed execution of a select query");
}

$host = 'ecs1b.sanger.ac.uk';
$dbname = 'abel_test2';
$dbuser = 'ensadmin';
$dbpass = 'ensembl';

$db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
						  -dbname => $dbname,
						  -user => $dbuser,
						  -pass => $dbpass);

my $species = "Homo_sapiens";

my $gadb = $db->get_GenomeDBAdaptor();
my $gdb = $gadb->fetch_by_species_tag($species);
my $galnad = $db->get_GenomicAlignAdaptor();

my $current_align_row_id = 1;

while (my ($id,$length) = $sth->fetchrow_array()) {
  my $aln = Bio::EnsEMBL::Compara::GenomicAlign->new();
 
  my $sth = $db->prepare("insert into align (align_name) values ('$id')");
  $sth->execute;
  $aln->dbID($sth->{'mysql_insertid'});
  my $align_id = $aln->dbID;

  my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new();
  $dnafrag->name($id);
  $dnafrag->genomedb($gdb);
  $dnafrag->type('RawContig');
  
  my $abs = Bio::EnsEMBL::Compara::AlignBlockSet->new();
  

  my $ab = Bio::EnsEMBL::Compara::AlignBlock->new();
  $ab->align_start(1);
  $ab->align_end($length);
  $ab->start(1);
  $ab->end($length);
  $ab->strand(1);
#  $ab->score(???);
  $ab->perc_id(100);
  $ab->cigar_string($length."M");
  $ab->dnafrag($dnafrag);
  
  $abs->add_AlignBlock($ab);

  $aln->add_AlignBlockSet($current_align_row_id,$abs);
  $current_align_row_id++;
  
  $galnad->store($aln,$align_id);
}
