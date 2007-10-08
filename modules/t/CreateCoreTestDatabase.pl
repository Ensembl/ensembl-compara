#!/usr/local/ensembl/bin/perl -w

# File name: CreateCoreTestDatabase.pl
#
# Given a source and destination database this script will create 
# a ensembl core database and perform 2Mbases of test data insertion 
#


use strict;

use Getopt::Long;
use DBI;

my ($help, $srcDB, $destDB, $host, $user, $pass, $port, $seq_region_file);

GetOptions('help' => \$help,
           's=s' => \$srcDB,
	   'd=s' => \$destDB,
	   'h=s' => \$host,
	   'u=s' => \$user,
	   'p=s' => \$pass,
	   'port=i' => \$port,
           'seq_region_file=s' => \$seq_region_file);

my $usage = "Usage:
CreateCoreTestDatabase.pl -s srcDB -d destDB -h host -u user -p pass [--port port]\n";

if ($help) {
  print $usage;
  exit 0;
}

unless($port) {
  $port = 3306;
}

my @seq_regions = @{do $seq_region_file};


# If needed command line args are missing print the usage string and quit
$srcDB and $destDB and $host and $user and $pass and $seq_region_file or die $usage;

my $dsn = "DBI:mysql:host=$host;port=$port";

# Connect to the mySQL host
my $dbh = DBI->connect( $dsn, $user, $pass, {RaiseError => 1})
  or die "Could not connect to database host : " . DBI->errstr;

print "\nWARNING: If the $destDB database already exists the existing copy \n"
  . "will be destroyed. Proceed (y/n)? ";

my $key = lc(getc());

unless( $key =~ /y/ ) {
  $dbh->disconnect();
  print "Test Genome Creation Aborted\n";
  exit;
}

print "Proceeding with test genome database $destDB creation\n";  

# dropping any destDB database if there
my $array_ref = $dbh->selectall_arrayref("SHOW DATABASES LIKE '$destDB'");
if (scalar @{$array_ref}) {
  $dbh->do("DROP DATABASE $destDB");
}
# creating destination database
$dbh->do( "CREATE DATABASE " . $destDB )
  or die "Could not create database $destDB: " . $dbh->errstr;

# Dump the source database table structure (w/o data) and use it to create
# the new database schema

# May have to eliminate the -p pass part... not sure

my $rc = 0xffff & system(
  "mysqldump -p$pass -u $user -h $host -P $port --no-data $srcDB | " .
  "mysql -p$pass -u $user -h $host -P $port $destDB");

if($rc != 0) {
  $rc >>= 8;
  die "mysqldump and insert failed with return code: $rc";
}
$dbh->do("use $destDB");

# populate coord_system table
$dbh->do("insert into coord_system select * from $srcDB.coord_system");
$array_ref = $dbh->selectcol_arrayref("select coord_system_id from coord_system where rank=1");
my $coord_system_id = $array_ref->[0];

# populate assembly and assembly_exception tables
my $all_seq_region_names = {};
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  $all_seq_region_names->{$seq_region_name} = 1;
  $dbh->do("insert into assembly select a.* from $srcDB.seq_region s,$srcDB.assembly a where s.coord_system_id=$coord_system_id and s.name='$seq_region_name' and s.seq_region_id=a.asm_seq_region_id and a.asm_start<$seq_region_end and a.asm_end>$seq_region_start");
}
$dbh->do("insert ignore into assembly_exception select ax.* from $srcDB.assembly_exception ax,assembly a where ax.seq_region_id=a.asm_seq_region_id");

# populate attrib_type table
$dbh->do("insert into attrib_type select * from $srcDB.attrib_type");

# populate seq_region and seq_region_attrib tables
$dbh->do("insert ignore into seq_region select s.* from assembly a,$srcDB.seq_region s where a.asm_seq_region_id=s.seq_region_id");
$dbh->do("insert ignore into seq_region select s.* from assembly a,$srcDB.seq_region s where a.cmp_seq_region_id=s.seq_region_id");
$dbh->do("insert into seq_region_attrib select sa.* from $srcDB.seq_region_attrib sa, seq_region s where s.seq_region_id=sa.seq_region_id");

# populate dna table
$dbh->do("insert into dna select d.* from $srcDB.dna d,seq_region s where s.seq_region_id=d.seq_region_id");

# populate repeat_feature and repeat_consensus tables
# repeat_features are stored at sequence_level
$dbh->do("insert into repeat_feature select rf.* from seq_region s, $srcDB.repeat_feature rf where s.seq_region_id=rf.seq_region_id and s.name not in (\"".join("\", \"", keys(%$all_seq_region_names))."\")");
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  $dbh->do("insert into repeat_feature select rf.* from seq_region s, $srcDB.repeat_feature rf where s.seq_region_id=rf.seq_region_id and s.name='$seq_region_name' and rf.seq_region_start<$seq_region_end and rf.seq_region_end>$seq_region_start");
}
$dbh->do("insert ignore into repeat_consensus select rc.* from repeat_feature rf, $srcDB.repeat_consensus rc where rf.repeat_consensus_id=rc.repeat_consensus_id");

# populate transcript, transcript_attrib and transcript_stable_id tables
# transcripts are stored at top_level
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  $dbh->do("insert into transcript select t.* from seq_region s, $srcDB.transcript t where s.seq_region_id=t.seq_region_id and s.coord_system_id=$coord_system_id and s.name='$seq_region_name' and t.seq_region_end<$seq_region_end and t.seq_region_end>$seq_region_start;");
}
$dbh->do("insert into transcript_attrib select ta.* from transcript t, $srcDB.transcript_attrib ta where t.transcript_id=ta.transcript_id");
$dbh->do ("insert into transcript_stable_id select ts.* from transcript t, $srcDB.transcript_stable_id ts where t.transcript_id=ts.transcript_id");

# populate translation, translation_attrib and translation_stable_id tables
$dbh->do("insert into translation select tl.* from transcript t, $srcDB.translation tl where t.transcript_id=tl.transcript_id");
$dbh->do("insert into translation_attrib select tla.* from translation tl, $srcDB.translation_attrib tla where tl.translation_id=tla.translation_id");
$dbh->do ("insert into translation_stable_id select tls.* from translation tl, $srcDB.translation_stable_id tls where tl.translation_id=tls.translation_id");

# populate exon_transcript, exon and exon_stable_id tables
$dbh->do("insert into exon_transcript select et.* from transcript t, $srcDB.exon_transcript et where t.transcript_id=et.transcript_id");
$dbh->do("insert ignore into exon select e.* from exon_transcript et, $srcDB.exon e where et.exon_id=e.exon_id");
$dbh->do("insert into exon_stable_id select es.* from exon e, $srcDB.exon_stable_id es where e.exon_id=es.exon_id");

# populate gene, gene_stable_id and alt_allele tables
$dbh->do("insert ignore into gene select g.* from transcript t, $srcDB.gene g where t.gene_id=g.gene_id");
$dbh->do("insert into gene_stable_id select gs.* from gene g, $srcDB.gene_stable_id gs where g.gene_id=gs.gene_id");
$dbh->do("insert into alt_allele select alt.* from gene g, $srcDB.alt_allele alt where g.gene_id=alt.gene_id");
# populate meta and meta_coord table
$dbh->do("insert into meta select * from $srcDB.meta");
$dbh->do("insert into meta_coord select * from $srcDB.meta_coord");

# populate analysis table
# I don't if this one is needed for test runs
#$dbh->do("insert into analysis select * from $srcDB.analysis");

$dbh->disconnect();

print "Test genome database $destDB created\n";

# cmd to dump .sql and .txt files
# /usr/local/ensembl/mysql/bin/mysqldump -hia64f -uensadmin -pensembl -P3306 --socket=/mysql/data_3306/mysql.sock -T ./ abel_core_test

exit 0;
