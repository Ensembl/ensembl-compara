#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ($host,$dbname,$dbuser,$newhost,$newdbname,$newdbuser,$newdbpass);

my $ref_genome_db_id = 1;
my $ref_dnafrag_type = "VirtualContig";

GetOptions('host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'newhost=s' => \$newhost,
	   'newdbname=s' => \$newdbname,
	   'newdbuser=s' => \$newdbuser,
	   'newdbpass=s' => \$newdbpass,
	   'ref_genome_db_id' => \$ref_genome_db_id,
	   'ref_dnafrag_type' => \$ref_dnafrag_type);

# Connecting to compara database

unless (defined $dbuser) {
  $dbuser = 'ensro';
}


$|=1;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -dbname => $dbname);

my $newdb = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $newhost,
							 -user => $newdbuser,
							 -dbname => $newdbname,
							 -pass => $newdbpass);

my $sth = $db->prepare("select * from genome_db");
$sth->execute;

while (defined (my $rowhash = $sth->fetchrow_hashref)) {
  my $sth2 = $newdb->prepare("insert into genome_db (genome_db_id,name,locator) values (?,?,?)");
  $sth2->execute($rowhash->{genome_db_id},$rowhash->{name},$rowhash->{locator});

}


$sth = $db->prepare("select * from dnafrag");
$sth->execute;

while (defined (my $rowhash = $sth->fetchrow_hashref)) {
  my $sth2 = $newdb->prepare("insert into dnafrag (name,genome_db_id,dnafrag_type) values (?,?,?)");
  $sth2->execute($rowhash->{name},$rowhash->{genome_db_id},$rowhash->{dnafrag_type});
}

$sth = $db->prepare("select * from align");
$sth->execute;

my %align_id2dnafrag_id;

while (defined (my $rowhash = $sth->fetchrow_hashref)) {
  my $sth2 = $newdb->prepare("insert into align (align_id,score,align_name) values (?,?,?)");
  $sth2->execute($rowhash->{align_id},$rowhash->{score},$rowhash->{align_name});
  my $sth3 = $newdb->prepare("insert into dnafrag (name,genome_db_id,dnafrag_type) values (?,?,?)");
  $sth3->execute($rowhash->{align_name},$ref_genome_db_id ,$ref_dnafrag_type);
  $align_id2dnafrag_id{$rowhash->{align_id}} = $sth3->{'mysql_insertid'};
}

$sth = $db->prepare("select * from align_row");
$sth->execute;

while (defined (my $rowhash = $sth->fetchrow_hashref)) {
  my $sth2 = $newdb->prepare("insert into align_row (align_row_id,align_id) values (?,?)");
  $sth2->execute($rowhash->{align_row_id},$rowhash->{align_id});
}


$sth = $db->prepare("select * from genomic_align_block");
$sth->execute;

while (defined (my $rowhash = $sth->fetchrow_hashref)) {

  my $sth2 = $newdb->prepare("insert into genomic_align_block (align_id,align_start,align_end,align_row_id,dnafrag_id,raw_start,raw_end,raw_strand,score,perc_id,cigar_line) values (?,?,?,?,?,?,?,?,?,?,?)");

  $sth2->execute($rowhash->{align_id},$rowhash->{align_start},$rowhash->{align_end},$rowhash->{align_row_id},$align_id2dnafrag_id{$rowhash->{align_id}},$rowhash->{align_start},$rowhash->{align_end},1,$rowhash->{score},$rowhash->{perc_id},$rowhash->{cigar_line});

  my $cigar_string = $rowhash->{cigar_line};
  $cigar_string =~ s/I/x/g;
  $cigar_string =~ s/D/I/g;
  $cigar_string =~ s/x/D/g;

  $sth2->execute($rowhash->{align_id},$rowhash->{align_start},$rowhash->{align_end},$rowhash->{align_row_id},$rowhash->{dnafrag_id},$rowhash->{raw_start},$rowhash->{raw_end},$rowhash->{raw_strand},$rowhash->{score},$rowhash->{perc_id},$cigar_string);
}

