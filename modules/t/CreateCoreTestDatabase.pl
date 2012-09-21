#!/usr/bin/env perl

# File name: CreateCoreTestDatabase.pl
#
# Given a source and destination database this script will create 
# a ensembl core database and populate it with data from a region defined in the seq_region_file
#


use strict;

use Getopt::Long;
use DBI;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my ($help, $srcDB, $destDB, $host, $user, $pass, $port, $seq_region_file, $dest_host, $dest_user, $dest_pass, $dest_port, $source_url, $dest_url);

GetOptions('help' => \$help,
	   'source_url=s' => \$source_url,
	   'destination_url=s' => \$dest_url,
           's=s' => \$srcDB,
	   'd=s' => \$destDB,
	   'h=s' => \$host,
	   'u=s' => \$user,
	   'p=s' => \$pass,
	   'port=i' => \$port,
	   'dest_h=s' => \$dest_host,
	   'dest_u=s' => \$dest_user,
	   'dest_p=s' => \$dest_pass,
	   'dest_port=i' => \$dest_port,
           'seq_region_file=s' => \$seq_region_file);

my $usage = "Usage:
CreateCoreTestDatabase.pl -s srcDB -d destDB -h host -u user -p pass [--port port] -dest_h dest_host -dest_u dest_user -dest_p dest_pass [--dest_port dest_port] --seq_region_file seq_region_file \n";

if ($help) {
  print $usage;
  exit 0;
}

unless($port) {
  $port = 3306;
}

unless($dest_port) {
  $dest_port = 3306;
}

# If needed command line args are missing print the usage string and quit
$srcDB and $destDB and $host and $user and $dest_host and $dest_user and $dest_pass and $seq_region_file or die $usage;

#Get seq_regions
my @seq_regions = @{do $seq_region_file};

my $from_dsn = "DBI:mysql:host=$host;port=$port";
my $to_dsn = "DBI:mysql:host=$dest_host;port=$dest_port";

#Need this to create the core database
my $to_dbh = DBI->connect( $to_dsn, $dest_user, $dest_pass, {RaiseError => 1})
  or die "Could not connect to database host : " . DBI->errstr;

my $from_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(
						-host => $host,
						-user => $user,
						-port => $port,
						-group => 'core',
						-dbname => $srcDB);

my $to_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(
						-host => $dest_host,
						-user => $dest_user,
						-pass => $dest_pass,
						-port => $dest_port,
						-group => 'core',
						-dbname => $destDB);

print "\nWARNING: If the $destDB database on $dest_host already exists the existing copy \n"
  . "will be destroyed. Proceed (y/n)? ";

my $key = lc(getc());

unless( $key =~ /y/ ) {
  $from_dba->dbc->disconnect();
  $to_dba->dbc->disconnect();
  print "Test Genome Creation Aborted\n";
  exit;
}

print "Proceeding with test genome database $destDB on $dest_host creation\n";  

# dropping any destDB database if there
my $array_ref = $to_dbh->selectall_arrayref("SHOW DATABASES LIKE '$destDB'");
if (scalar @{$array_ref}) {
  $to_dba->dbc->do("DROP DATABASE $destDB");
}
# creating destination database
$to_dbh->do( "CREATE DATABASE " . $destDB )
  or die "Could not create database $destDB: " . $to_dbh->errstr;

# Dump the source database table structure (w/o data) and use it to create
# the new database schema

# May have to eliminate the -p pass part... not sure

my $rc = 0xffff & system(
  "mysqldump -u $user -h $host -P $port --no-data $srcDB | " .
  "mysql -p$dest_pass -u $dest_user -h $dest_host -P $dest_port $destDB");

if($rc != 0) {
  $rc >>= 8;
  die "mysqldump and insert failed with return code: $rc";
}
$to_dba->dbc->do("use $destDB");

# populate coord_system table
my $query = "SELECT * FROM $srcDB.coord_system";
my $table_name = "coord_system";
copy_data_in_text_mode($from_dba, $to_dba, $table_name, $query);

#Store available coord_systems
my %coord_systems;
my $sql = "select coord_system_id, name, rank from coord_system";
my $sth = $to_dba->dbc->prepare($sql);
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
    $coord_systems{$row->{name}} = $row->{rank};
}
$sth->finish;

#$array_ref = $from_dba->db_handle->selectcol_arrayref("select coord_system_id from coord_system where rank=1");
#my $coord_system_id = $array_ref->[0];

my $slice_adaptor = $from_dba->get_adaptor("Slice");
# populate assembly and assembly_exception tables
my $all_seq_region_names = {};
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  #$all_seq_region_names->{$seq_region_name} = 1;

  #This query doesn't work with gorilla (e!68) because we cannot go from chromosome to contig but must go via supercontig
  #$query = "SELECT a.* FROM $srcDB.seq_region s,$srcDB.assembly a WHERE s.coord_system_id=$coord_system_id AND s.name='$seq_region_name' AND s.seq_region_id=a.asm_seq_region_id AND a.asm_start<$seq_region_end AND a.asm_end>$seq_region_start";

  #Make the assumption that the core API is OK and that the 3 levels of assembly are chromosome, supercontig and contig

  my $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $seq_region_start, $seq_region_end);

  my $supercontigs;
  my $seq_region_list;

  #May not always have supercontigs
  if ($coord_systems{'supercontig'}) {
      $supercontigs = $slice->project('supercontig');
      foreach my $supercontig (@$supercontigs) {
          my $supercontig_slice = $supercontig->[2];
          $seq_region_list .= $supercontig_slice->get_seq_region_id . ",";
      }
  }

  #Assume always have contigs
  my $contigs = $slice->project('contig');

  foreach my $contig (@$contigs) {
      my $contig_slice = $contig->[2];
      $seq_region_list .= $contig_slice->get_seq_region_id . ",";
  }
  chop $seq_region_list;

  $query = "SELECT a.* FROM $srcDB.seq_region s JOIN $srcDB.assembly a ON (s.seq_region_id = a.cmp_seq_region_id) WHERE seq_region_id IN ($seq_region_list)";

  copy_data_in_text_mode($from_dba, $to_dba, "assembly", $query);

  #convert seq_region_name to seq_region_id
  my $sql = "SELECT seq_region_id FROM seq_region WHERE name = \"$seq_region_name\"";
  my $sth = $from_dba->dbc->prepare($sql);
  $sth->execute();
  my ($seq_region_id) = $sth->fetchrow_arrayref->[0];
  $sth->finish;
  print "$seq_region_name seq_region_id $seq_region_id\n";
  $all_seq_region_names->{$seq_region_name} = $seq_region_id;
}

my ($asm_seq_region_ids,$asm_seq_region_ids_str)  = get_ids($to_dba,"asm_seq_region_id", "assembly") ;

my $all_seq_region_ids;
my ($cmp_seq_region_ids,$cmp_seq_region_ids_str)  = get_ids($to_dba,"cmp_seq_region_id", "assembly") ;

$query = "SELECT ax.* FROM assembly_exception ax WHERE ax.seq_region_id in ($asm_seq_region_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "assembly_exception", $query);

# populate attrib_type table
$query = "SELECT * FROM attrib_type";
copy_data_in_text_mode($from_dba, $to_dba, "attrib_type", $query);

# populate seq_region and seq_region_attrib tables
foreach my $id (@$asm_seq_region_ids) {
    push @$all_seq_region_ids, $id;
}
foreach my $id (@$cmp_seq_region_ids) {
    push @$all_seq_region_ids, $id;
}
my $all_seq_region_ids_str = join ",", @$all_seq_region_ids;

$query = "SELECT s.* from seq_region s where s.seq_region_id in ($all_seq_region_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "seq_region", $query);

$query = "SELECT sa.* FROM seq_region_attrib sa WHERE sa.seq_region_id in ($all_seq_region_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "seq_region_attrib", $query);

# populate dna table
$query = "SELECT d.* FROM dna d WHERE d.seq_region_id in ($all_seq_region_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "dna", $query);

# populate repeat_feature and repeat_consensus tables
# repeat_features are stored at sequence_level
$query = "SELECT rf.* FROM repeat_feature rf WHERE rf.seq_region_id in ($cmp_seq_region_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "repeat_feature", $query);

foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  my $seq_region_id = $all_seq_region_names->{$seq_region_name};

  $query = "SELECT rf.* FROM repeat_feature rf WHERE rf.seq_region_id=$seq_region_id AND rf.seq_region_start<$seq_region_end AND rf.seq_region_end>$seq_region_start";
  copy_data_in_text_mode($from_dba, $to_dba, "repeat_feature", $query);
}

my ($repeat_consensus_ids, $repeat_consensus_ids_str) = get_ids($to_dba, "repeat_consensus_id", "repeat_feature");
$query = "SELECT rc.* FROM repeat_consensus rc WHERE rc.repeat_consensus_id in ($repeat_consensus_ids_str)";
copy_data_in_text_mode($from_dba, $to_dba, "repeat_consensus", $query);


# populate transcript, transcript_attrib and transcript_stable_id tables
# transcripts are stored at top_level
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  my $seq_region_id = $all_seq_region_names->{$seq_region_name};

  $query = "SELECT t.* FROM transcript t WHERE t.seq_region_id=$seq_region_id AND t.seq_region_end<$seq_region_end AND t.seq_region_end>$seq_region_start";
  copy_data_in_text_mode($from_dba, $to_dba, "transcript", $query);
}

my ($transcript_ids, $transcript_ids_str) = get_ids($to_dba, "transcript_id", "transcript");
my ($gene_ids, $gene_ids_str) = get_ids($to_dba, "gene_id", "transcript");

if ($transcript_ids_str) {
    $query = "SELECT ta.* FROM transcript_attrib ta WHERE ta.transcript_id in ($transcript_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "transcript_attrib", $query);
}

# populate translation, translation_attrib and translation_stable_id tables
if ($transcript_ids_str) {
    $query = "SELECT tl.* FROM translation tl WHERE tl.transcript_id in ($transcript_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "translation", $query);
}

my ($translation_ids, $translation_ids_str) = get_ids($to_dba, "translation_id", "translation");

if ($translation_ids_str) {
    $query = "SELECT tla.* FROM translation_attrib tla WHERE tla.translation_id in ($translation_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "translation_attrib", $query);
}

# populate exon_transcript, exon and exon_stable_id tables
if ($transcript_ids_str) {
    $query = "SELECT et.* FROM exon_transcript et WHERE et.transcript_id in ($transcript_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "exon_transcript", $query);
}

my ($exon_ids, $exon_ids_str) = get_ids($to_dba, "exon_id", "exon_transcript");

if ($exon_ids_str) {
    $query = "SELECT e.* FROM exon e WHERE e.exon_id in ($exon_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "exon", $query);
}

# populate gene, gene_stable_id and alt_allele tables
if ($gene_ids_str) {
    $query = "SELECT g.* FROM gene g WHERE g.gene_id in ($gene_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "gene", $query);
}

if ($gene_ids_str) {
    $query = "SELECT alt.* FROM alt_allele alt WHERE alt.gene_id in ($gene_ids_str)";
    copy_data_in_text_mode($from_dba, $to_dba, "alt_allele", $query);
}

# populate meta and meta_coord table
$query = "SELECT * FROM meta";
copy_data_in_text_mode($from_dba, $to_dba, "meta", $query);

$query = "SELECT * FROM meta_coord";
copy_data_in_text_mode($from_dba, $to_dba, "meta_coord", $query);

print "Test genome database $destDB created\n";

sub copy_data_in_text_mode {
  my ($from_dba, $to_dba, $table_name, $query, $step) = @_;
   print "start copy_data_in_text_mode $table_name\n";

  my $user = $to_dba->dbc->username;
  my $pass = $to_dba->dbc->password;
  my $host = $to_dba->dbc->host;
  my $port = $to_dba->dbc->port;
  my $dbname = $to_dba->dbc->dbname;
  my $use_limit = 1;
  my $start = 0;

  if (!defined $step) {
      $step = 100000;
  }

  while (1) {
    my $start_time = time();
    my $end = $start + $step - 1;
    my $sth;
    print "$query start $start end $end\n";
    $sth = $from_dba->dbc->prepare($query." LIMIT $start, $step");

    $start += $step;
    $sth->execute();
    my $all_rows = $sth->fetchall_arrayref;
    $sth->finish;
    ## EXIT CONDITION
    return if (!@$all_rows);
    my $time=time(); 
    my $filename = "/tmp/$table_name.copy_data.$$.$time.txt";
    open(TEMP, ">$filename") or die "could not open the file '$filename' for writing";
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", map {defined($_)?$_:'\N'} @$this_row), "\n";
    }
    close(TEMP);
    #print "time " . ($start-$min_id) . " " . (time - $start_time) . "\n";

    system("mysqlimport -h$host -P$port -u$user ".($pass ? "-p$pass" : '')." -L -l -i $dbname $filename");

    unlink("$filename");
    #print "total time " . ($start-$min_id) . " " . (time - $start_time) . "\n";
  }
}

sub get_ids {
    my ($dba, $id, $table) = @_;
    my $ids;
    my $sql = "SELECT distinct($id) FROM $table";
    my $sth = $dba->dbc->prepare($sql);
    $sth->execute();

    while (my $row = $sth->fetchrow_arrayref) {
	push @$ids, $row->[0];
    }
    $sth->finish();

    return (undef, "") unless ($ids);
    my $ids_str = join ",", @$ids;

    return ($ids, $ids_str);
}

exit 0;
