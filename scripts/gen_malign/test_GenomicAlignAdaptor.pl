#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::GenomicAlign; 
use Bio::EnsEMBL::Compara::GenomicAlignBlock; 
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -dbname ensembl_compara_database
   -port eg 3352 (default)
   -conf_file compara_conf_file
              see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
";

my $host = "127.0.0.1";
my $dbname = "ensembl_compara_javi_22_1";
my $dbuser = 'ensro';
my $dbpass;
my $conf_file = "Compara.conf";
my $help = 0;
my $port = 3352;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'port=i'  => \$port,
	   'conf_file=s' => \$conf_file,
           );

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -pass => $dbpass,
						      -port => $port,
						      -dbname => $dbname,
						      -conf_file => $conf_file);
my $dbh = $db->db_handle();


my $genomic_align;
my $genomic_align_adaptor = $db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $db->get_DnaFragAdaptor();

my $dbID = 1;
my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
$genomic_align_block->dbID(1);
my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet();
$method_link_species_set->dbID(1);
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID(22);
my $dnafrag_start = 100001;
my $dnafrag_end = 100050;
my $dnafrag_strand = -1;
my $level_id = 1;
my $cigar_line = "23M4G27M";

print "Test Bio::EnsEMBL::Compara::GenomicAlign new(void) method:";
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
  print " OK!\n";

print "Test Bio::EnsEMBL::Compara::GenomicAlign new(ALL) method:";
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block,
      -method_link_species_set => $method_link_species_set,
      -dnafrag => $dnafrag,
      -dnafrag_start => $dnafrag_start,
      -dnafrag_end => $dnafrag_end,
      -dnafrag_strand => $dnafrag_strand,
      -level_id => $level_id,
      -cigar_line => $cigar_line
      );
  print " ";
  if ($genomic_align->adaptor eq $genomic_align_adaptor) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->dbID == $dbID) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->genomic_align_block == $genomic_align_block) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->method_link_species_set == $method_link_species_set) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->dnafrag == $dnafrag) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->dnafrag_start == $dnafrag_start) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->dnafrag_end == $dnafrag_end) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->dnafrag_strand == $dnafrag_strand) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->level_id == $level_id) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->cigar_line eq $cigar_line) {print "."} else {die "ERROR!\n"}
  print " OK!\n";

print "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlign original_sequence method:\n";
  my $original_sequence = $genomic_align->original_sequence;
  if ($original_sequence) {print "  $original_sequence\n"} else {die "ERROR!\n"}

print "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlign aligned_sequence method:\n";
  my $aligned_sequence = $genomic_align->aligned_sequence;
  if ($aligned_sequence) {print "  $aligned_sequence\n"} else {die "ERROR!\n"}
  
print "Test Bio::EnsEMBL::Compara::GenomicAlign cigar_line method:";
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block,
      -method_link_species_set => $method_link_species_set,
      -dnafrag => $dnafrag,
      -dnafrag_start => $dnafrag_start,
      -dnafrag_end => $dnafrag_end,
      -dnafrag_strand => $dnafrag_strand,
      -level_id => $level_id,
      -aligned_sequence => $aligned_sequence
      );
  if ($genomic_align->cigar_line eq $cigar_line) {print "."} else {die "ERROR!\n"}
  print " OK!\n";



print "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor store(void) method:";
  $genomic_align->dbID("NULL");
  $genomic_align_adaptor->store([$genomic_align]);
  print " OK!\n";


my $consensus_dnafrag = 51;
my $consensus_start = 1501;
my $consensus_end = 1701;
my $query_dnafrag = 52;
my $query_start = 2501;
my $query_end = 2701;
my $query_strand = 1;
my $alignment_type = "BLASTZ_NET";
my $score = 95;
my $perc_id = 67;

print "Test Bio::EnsEMBL::Comapara::GenomicAlign new(OLD_PARAM) method:";
  verbose(0);
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -consensus_dnafrag => $consensus_dnafrag,
      -consensus_start => $consensus_start,
      -consensus_end => $consensus_end,
      -query_dnafrag => $query_dnafrag,
      -query_start => $query_start,
      -query_end => $query_end,
      -query_strand => $query_strand,
      -alignment_type => $alignment_type,
      -score => $score,
      -perc_id => $perc_id
      );
  $genomic_align->{'_rootI_verbose'} = -1;
  print " ";
  if ($genomic_align->consensus_dnafrag == $consensus_dnafrag) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->consensus_start == $consensus_start) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->consensus_end == $consensus_end) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->query_dnafrag == $query_dnafrag) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->query_start == $query_start) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->query_end == $query_end) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->query_strand == $query_strand) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->alignment_type eq $alignment_type) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->score == $score) {print "."} else {die "ERROR!\n"}
  if ($genomic_align->perc_id == $perc_id) {print "."} else {die "ERROR!\n"}
  print " OK!\n";

print "\nAll tests OK.\n";

exit 0;
