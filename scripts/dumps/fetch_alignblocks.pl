#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my $usage = "
fetch_alignblocks -host ecs1b.sanger.ac.uk 
            -user ensro
            -dbname ensembl_compara_10_1
            -chr_name \"22\"
            -chr_start 1
            -chr_end 100000
            -species1 \"Homo sapiens\"
            -assembly1 NCBI30
            -species2 \"Mus musculus\"
            -assembly2 MGSC3
            -conf_file Compara.conf

$0 [-help]
   -host compara_db_host_server
   -user username (default = 'ensro')
   -dbname compara_database_name
   -chr_name \"22\" 
   -chr_start 
   -chr_end 
   -species1 (e.g. \"Homo sapiens\") from which alignments are queried and chr_names refer to
   -assembly1 (e.g. NCBI30) assembly version of species1
   -species2 (e.g. \"Mus musculus\") to which alignments are queried
   -assembly2 (e.g. MGSC3) assembly version of species2
   -conf_file comparadb_configuration_file
              (see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example)

";


my ($host,$dbname,$dbuser,$chr_name,$chr_start,$chr_end,$species1,$assembly1,$species2,$assembly2);

my $conf_file;

my $help = 0;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'chr_name=s' => \$chr_name,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'species1=s' => \$species1,
	   'assembly1=s' => \$assembly1,
	   'species2=s' => \$species2,
	   'assembly2=s' => \$assembly2,
	   'conf_file=s' => \$conf_file);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Connecting to compara database

unless (defined $dbuser) {
  $dbuser = 'ensro';
}

unless ($chr_start) {
  warn "WARNING : setting chr_start=1\n";
  $chr_start = 1;
}
if ($chr_start <= 0) {
  warn "WARNING : chr_start <= 0, setting chr_start=1\n";
  $chr_start = 1;
}

if (defined $chr_end && $chr_end < $chr_start) {
  warn "chr_end $chr_end should be >= chr_start $chr_start
exit 2\n";
  exit 2;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -dbname => $dbname,
						      -conf_file => $conf_file);


my $species1_dbadaptor = $db->get_db_adaptor($species1,$assembly1);

my $sb_chradp = $species1_dbadaptor->get_ChromosomeAdaptor;
my $chr = $sb_chradp->fetch_by_chr_name($chr_name);

if ($chr_start > $chr->length) {
  warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 3\n";
  exit 3;
}
unless (defined $chr_end) {
  warn "WARNING : setting chr_end=chr_length ".$chr->length."\n";
  $chr_end = $chr->length;
}
if ($chr_end > $chr->length) {
  warn "WARNING : chr_end $chr_end larger than chr_length ".$chr->length."
setting chr_end=chr_length\n";
  $chr_end = $chr->length;
}

# futher checks on arguments

unless (defined $chr_start) {
  warn "WARNING : setting chr_start=1\n";
  $chr_start = 1;
}

if ($chr_start > $chr->length) {
  warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 3\n";
  exit 3;
}
unless (defined $chr_end) {
  warn "WARNING : setting chr_end=chr_length ".$chr->length."\n";
  $chr_end = $chr->length;
}
if ($chr_end > $chr->length) {
  warn "WARNING : chr_end $chr_end larger than chr_length ".$chr->length."
setting chr_end=chr_length\n";
  $chr_end = $chr->length;
}

my $dafad = $db->get_DnaAlignFeatureAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_species_region($species1,$assembly1,$species2,$assembly2,$chr_name,$chr_start,$chr_end)};

foreach my $ddaf (@DnaDnaAlignFeatures) {
  print $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->strand," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->cigar_string,"\n";
}

exit 0;
