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

my $ref_genome_db_id = 1;
my @other_genome_db_ids = qw(2 3);
my $method_link_id = 1;

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

# If needed command line args are missing print the usage string and quit
$srcDB and $destDB and $host and $user and $pass and $seq_region_file or die $usage;

my @seq_regions = @{do $seq_region_file};

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
  "mysql -p$pass -u $user -h $host -P port $destDB");

if($rc != 0) {
  $rc >>= 8;
  die "mysqldump and insert failed with return code: $rc";
}
$dbh->do("use $destDB");

$dbh->do("insert into source select * from $srcDB.source");
$dbh->do("insert into method_link select * from $srcDB.method_link");

$dbh->do("insert into genome_db select * from $srcDB.genome_db");
$dbh->do("update genome_db set locator=NULL");

$dbh->do("insert into meta select * from $srcDB.meta");
$array_ref = $dbh->selectcol_arrayref("select meta_value from meta where meta_key='max_alignment_length'");
my $max_alignment_length = $array_ref->[0];

foreach my $genome_db_id (@other_genome_db_ids) {
  $dbh->do("insert into genomic_align_genome select * from $srcDB.genomic_align_genome gag where gag.method_link_id=1 and (gag.consensus_genome_db_id=$ref_genome_db_id or gag.query_genome_db_id=$ref_genome_db_id) and (gag.consensus_genome_db_id=$genome_db_id or gag.query_genome_db_id=$genome_db_id)");
  
  my $array_ref = $dbh->selectall_arrayref("select * from genomic_align_genome gag where gag.method_link_id=$method_link_id and (gag.consensus_genome_db_id=$ref_genome_db_id or gag.query_genome_db_id=$ref_genome_db_id) and (gag.consensus_genome_db_id=$genome_db_id or gag.query_genome_db_id=$genome_db_id)");
  
  foreach my $seq_region (@seq_regions) {
    my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
    my $lower_bound = $seq_region_start - $max_alignment_length;

    # populate genomic_align_block table
    if ($array_ref->[0]->[0] == $ref_genome_db_id) {
      $dbh->do("insert into genomic_align_block select gab.* from $srcDB.genomic_align_block gab, $srcDB.dnafrag d1, $srcDB.dnafrag d2 where gab.method_link_id=$method_link_id and gab.consensus_dnafrag_id=d1.dnafrag_id and gab.query_dnafrag_id=d2.dnafrag_id and d1.genome_db_id=$ref_genome_db_id and d2.genome_db_id=$genome_db_id and d1.name=$seq_region_name and gab.consensus_start<=$seq_region_end and gab.consensus_end>=$seq_region_start and gab.consensus_start>=$lower_bound");
    } elsif ($array_ref->[0]->[1] == $ref_genome_db_id) {
      $dbh->do("insert into genomic_align_block select gab.* from $srcDB.genomic_align_block gab, $srcDB.dnafrag d1, $srcDB.dnafrag d2 where gab.method_link_id=$method_link_id and gab.query_dnafrag_id=d1.dnafrag_id and gab.consensus_dnafrag_id=d2.dnafrag_id and d1.genome_db_id=$ref_genome_db_id and d2.genome_db_id=$genome_db_id and d1.name=$seq_region_name and gab.query_start<=$seq_region_end and gab.query_end>=$seq_region_start and gab.query_start>=$lower_bound");
    }

    # populate homology table
    $dbh->do("insert into homology select h.* from $srcDB.homology h,$srcDB.homology_member hm1, $srcDB.member m1, $srcDB.homology_member hm2, $srcDB.member m2 where h.homology_id=hm1.homology_id and h.homology_id=hm2.homology_id and hm1.member_id=m1.member_id and hm2.member_id=m2.member_id and m1.genome_db_id=$ref_genome_db_id and m2.genome_db_id=$genome_db_id and m1.chr_name=$seq_region_name and m1.chr_start<$seq_region_end and m1.chr_end>$seq_region_start");

    # populate family table
    $dbh->do("insert ignore into family select f.* from $srcDB.family f, $srcDB.family_member fm, $srcDB.member m where f.family_id=fm.family_id and fm.member_id=m.member_id and m.genome_db_id=$ref_genome_db_id and m.chr_name=$seq_region_name and m.chr_start<$seq_region_end and m.chr_end>$seq_region_start");
  }
}


# populate dnafrag table
$dbh->do("insert ignore into dnafrag select d.* from genomic_align_block gab, $srcDB.dnafrag d where gab.consensus_dnafrag_id=d.dnafrag_id");
$dbh->do("insert ignore into dnafrag select d.* from genomic_align_block gab, $srcDB.dnafrag d where gab.query_dnafrag_id=d.dnafrag_id");

foreach my $genome_db_id (@other_genome_db_ids) {
  # populate synteny_region table
  $dbh->do("insert into synteny_region select s.* from $srcDB.synteny_region s, $srcDB.dnafrag_region dr1, dnafrag d1, $srcDB.dnafrag_region dr2, dnafrag d2 where s.synteny_region_id=dr1.synteny_region_id and s.synteny_region_id=dr2.synteny_region_id and dr1.dnafrag_id=d1.dnafrag_id and dr2.dnafrag_id=d2.dnafrag_id and d1.genome_db_id=$ref_genome_db_id and d2.genome_db_id=$genome_db_id");
}

# populate dnafrag_region tables
$dbh->do("insert into dnafrag_region select dr.* from synteny_region s, $srcDB.dnafrag_region dr where s.synteny_region_id=dr.synteny_region_id");

# populate homology_member table
$dbh->do("insert into homology_member select hm.* from homology h, $srcDB.homology_member hm where h.homology_id=hm.homology_id");

# populate family_member table
$dbh->do("insert into family_member select fm.* from family f, $srcDB.family_member fm where f.family_id=fm.family_id");

# populate member table
$dbh->do("insert into member select m.* from family_member fm, $srcDB.member m where fm.member_id=m.member_id");
$dbh->do("insert ignore into member select m.* from homology_member hm, $srcDB.member m where hm.member_id=m.member_id");
$dbh->do("insert ignore into member select m.* from homology_member hm, $srcDB.member m where hm.peptide_member_id=m.member_id");

# populate sequence table
$dbh->do("insert into sequence select s.* from member m, $srcDB.sequence s where m.sequence_id=s.sequence_id");

# populate taxon table
$dbh->do("insert ignore into taxon select t.* from member m, $srcDB.taxon t where m.taxon_id=t.taxon_id");
$dbh->do("insert ignore into taxon select t.* from genome_db g, $srcDB.taxon t where g.taxon_id=t.taxon_id");

# populate the method_link_species.....not it is needed with the current schema
# it will when moving to the multiple alignment enabled schema.

# Now output the mouse and rat seq_region file needed to create the corresponding core databases
foreach my $genome_db_id (@other_genome_db_ids) {
  my $array_ref = $dbh->selectcol_arrayref("select name from genome_db where genome_db_id=$genome_db_id");
  my $species_name = lc($array_ref->[0]);
  $species_name =~ s/\s+/_/g;
  my $file = $species_name . ".seq_region_file";

  open F, ">$file" or
    die "can not open $file\n";
  print F "[\n";
  
  $array_ref = $dbh->selectall_arrayref("select d.name,g.query_start,g.query_end from dnafrag d, genomic_align_block g where d.dnafrag_id=g.query_dnafrag_id and d.genome_db_id=$genome_db_id order by d.name, g.query_start,g.query_end");

  my ($last_name, $last_start,$last_end);
  foreach my $row (@{$array_ref}) {
    my ($name,$start,$end) = @{$row};
    unless (defined $last_name && defined $last_start && defined $last_end) {
      ($last_name, $last_start,$last_end) = ($name,$start,$end);
      next;
    }
    if ($name eq $last_name && $start - $last_end < 100000) {
      $last_end = $end;
    } elsif (($name eq $last_name && $start - $last_end >= 100000) ||
             $name ne $last_name) {
      print F "[$last_name, $last_start,$last_end],\n";
      ($last_name, $last_start,$last_end) = ($name,$start,$end);
    }
  }
  print F "[$last_name, $last_start,$last_end]\n]\n";

  close F;
}

$dbh->disconnect();

print "Test genome database $destDB created\n";

# cmd to dump .sql and .txt files
# /usr/local/ensembl/mysql/bin/mysqldump -hia64f -uensadmin -pensembl -P3306 --socket=/mysql/data_3306/mysql.sock -T ./ abel_core_test

exit 0;
