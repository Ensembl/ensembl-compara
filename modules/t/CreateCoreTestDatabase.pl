#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# File name: CreateCoreTestDatabase.pl
#
# Given a source and destination database this script will create 
# a ensembl core database and populate it with data from a region defined in the seq_region_file
#


use strict;
use warnings;

use Getopt::Long;
use DBI;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);
use Bio::EnsEMBL::Compara::Utils::RunCommand;

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

my $from_dbc = $from_dba->dbc;
my $to_dbc = $to_dba->dbc;

print "\nWARNING: If the $destDB database on $dest_host already exists the existing copy \n"
  . "will be destroyed. Proceed (y/n)? ";

my $key = lc(getc());

unless( $key =~ /y/ ) {
  $from_dbc->disconnect();
  $to_dbc->disconnect();
  print "Test Genome Creation Aborted\n";
  exit;
}

print "Proceeding with test genome database $destDB on $dest_host creation\n";  

# dropping any destDB database if there
my $array_ref = $to_dbh->selectall_arrayref("SHOW DATABASES LIKE '$destDB'");
if (scalar @{$array_ref}) {
  $to_dbc->do("DROP DATABASE $destDB");
}
# creating destination database
$to_dbh->do( "CREATE DATABASE " . $destDB )
  or die "Could not create database $destDB: " . $to_dbh->errstr;

# Dump the source database table structure (w/o data) and use it to create
# the new database schema

# May have to eliminate the -p pass part... not sure

my $cmd = (
  "mysqldump -u $user -h $host -P $port --no-data $srcDB | " .
  "mysql -p$dest_pass -u $dest_user -h $dest_host -P $dest_port $destDB");
Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1, use_bash_pipefail => 1 } );

$to_dbc->do("use $destDB");

# populate coord_system table
copy_table($from_dbc, $to_dbc, 'coord_system');

#Store available coord_systems
my %coord_systems;
my $sql = "select coord_system_id, name, rank from coord_system";
my $sth = $to_dbc->prepare($sql);
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

  # Used to be this query, but I think it can be expressed simpler
  #my $query = "SELECT a.* FROM $srcDB.seq_region s JOIN $srcDB.assembly a ON (s.seq_region_id = a.cmp_seq_region_id) WHERE seq_region_id IN ($seq_region_list)";
  $filter = "cmp_seq_region_id IN ($seq_region_list)";
  copy_table($from_dbc, $to_dbc, "assembly", $filter);

  #convert seq_region_name to seq_region_id
  my $sql = "SELECT seq_region_id FROM seq_region WHERE name = \"$seq_region_name\"";
  my $sth = $from_dbc->prepare($sql);
  $sth->execute();
  my ($seq_region_id) = $sth->fetchrow_arrayref->[0];
  $sth->finish;
  print "$seq_region_name seq_region_id $seq_region_id\n";
  $all_seq_region_names->{$seq_region_name} = $seq_region_id;
}

my ($asm_seq_region_ids,$asm_seq_region_ids_str)  = get_ids($to_dbc,"asm_seq_region_id", "assembly") ;

my $all_seq_region_ids;
my ($cmp_seq_region_ids,$cmp_seq_region_ids_str)  = get_ids($to_dbc,"cmp_seq_region_id", "assembly") ;

my $filter = "seq_region_id in ($asm_seq_region_ids_str)";
copy_table($from_dbc, $to_dbc, "assembly_exception", $filter);

# populate attrib_type table
copy_table($from_dbc, $to_dbc, "attrib_type");

# populate seq_region and seq_region_attrib tables
foreach my $id (@$asm_seq_region_ids) {
    push @$all_seq_region_ids, $id;
}
foreach my $id (@$cmp_seq_region_ids) {
    push @$all_seq_region_ids, $id;
}
my $all_seq_region_ids_str = join ",", @$all_seq_region_ids;

$filter = "seq_region_id in ($all_seq_region_ids_str)";
copy_table($from_dbc, $to_dbc, "seq_region", $filter);
copy_table($from_dbc, $to_dbc, "seq_region_attrib", $filter);
copy_table($from_dbc, $to_dbc, "dna", $filter);

# populate repeat_feature and repeat_consensus tables
# repeat_features are stored at sequence_level
$filter = "seq_region_id in ($cmp_seq_region_ids_str)";
copy_table($from_dbc, $to_dbc, "repeat_feature", $filter);

foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  my $seq_region_id = $all_seq_region_names->{$seq_region_name};

  $filter = "seq_region_id=$seq_region_id AND seq_region_start<$seq_region_end AND seq_region_end>$seq_region_start";
  copy_table($from_dbc, $to_dbc, "repeat_feature", $filter);
}

my ($repeat_consensus_ids, $repeat_consensus_ids_str) = get_ids($to_dbc, "repeat_consensus_id", "repeat_feature");
$filter = "repeat_consensus_id in ($repeat_consensus_ids_str)";
copy_table($from_dbc, $to_dbc, "repeat_consensus", $filter);


# populate transcript, transcript_attrib and transcript_stable_id tables
# transcripts are stored at top_level
foreach my $seq_region (@seq_regions) {
  my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
  my $seq_region_id = $all_seq_region_names->{$seq_region_name};

  $filter = "seq_region_id=$seq_region_id AND seq_region_end<$seq_region_end AND seq_region_end>$seq_region_start";
  copy_table($from_dbc, $to_dbc, "transcript", $filter);
}

my ($transcript_ids, $transcript_ids_str) = get_ids($to_dbc, "transcript_id", "transcript");
my ($gene_ids, $gene_ids_str) = get_ids($to_dbc, "gene_id", "transcript");

if ($transcript_ids_str) {
    $filter = "transcript_id in ($transcript_ids_str)";
    copy_table($from_dbc, $to_dbc, "transcript_attrib", $filter);
    copy_table($from_dbc, $to_dbc, "translation", $filter);
    copy_table($from_dbc, $to_dbc, "exon_transcript", $filter);
}

my ($translation_ids, $translation_ids_str) = get_ids($to_dbc, "translation_id", "translation");

if ($translation_ids_str) {
    $filter = "translation_id in ($translation_ids_str)";
    copy_table($from_dbc, $to_dbc, "translation_attrib", $filter);
}

my ($exon_ids, $exon_ids_str) = get_ids($to_dbc, "exon_id", "exon_transcript");

if ($exon_ids_str) {
    $filter = "exon_id in ($exon_ids_str)";
    copy_table($from_dbc, $to_dbc, "exon", $filter);
}

# populate gene, gene_stable_id and alt_allele tables
if ($gene_ids_str) {
    $filter = "gene_id in ($gene_ids_str)";
    copy_table($from_dbc, $to_dbc, "gene", $filter);
    copy_table($from_dbc, $to_dbc, "alt_allele", $filter);
}

# populate meta and meta_coord table
copy_table($from_dbc, $to_dbc, "meta");

copy_table($from_dbc, $to_dbc, "meta_coord");

print "Test genome database $destDB created\n";


sub get_ids {
    my ($dbc, $id, $table) = @_;
    my $ids;
    my $sql = "SELECT distinct($id) FROM $table";
    my $sth = $dbc->prepare($sql);
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
