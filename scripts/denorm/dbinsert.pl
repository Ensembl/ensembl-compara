#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Getopt::Long;

my $usage = "\n$0 [options] matches_result_file|STDIN

 Insert into a feature table in \"feature_dbname\", matches as feature pairs.

Format of matches_result_file or STDIN:

 contig_name1\\tstart1\\tend1\\tstrand1\\tcontig_name2\\tstart2\\tend2\\tstrand2\\tany_comment\\n

 all contig_name1 entries should belong to one unique species. Same for all contig_name2 entries.

Options:

 -species_reference   1 or 2 (default=1) species to be used as reference.

 -core_host           host for species reference core database
 -core_dbname         species reference core database name
 -core_dbuser         username for connection to \"core_dbname\" (default=ensro)

 -feature_host        host for feature pairs database
 -feature_dbname      feature pairs database name
 -feature_dbuser      username for connection to \"feature_dbname\"
 -feature_pass        passwd for connection to \"feature_dbname\"
\n";


my $help = 0;
my $core_host   = 'ecs1d';
my $core_dbname = 'homo_sapiens_core_130';
#my $core_dbname = 'mus_musculus_core_1_3';
my $core_dbuser = 'ensro';

my $feature_host = 'ecs1d';
my $feature_dbname = 'human_mouse_1_3_20020204';
#my $feature_dbname = 'mouse_human_1_3_20020204';
my $feature_dbuser = 'ensadmin';
my $feature_pass   = 'ensembl';

my $species_reference = 2;

&GetOptions('h' => \$help,
	    'core_host:s' => \$core_host,
	    'core_dbname:s' => \$core_dbname,
	    'core_dbuser:s' => \$core_dbuser,
	    'feature_host' => \$feature_host,
	    'feature_dbname' => \$feature_dbname,
	    'feature_dbuser:s' => \$feature_dbuser,
	    'feature_pass:s' => \$feature_pass,
	    'species_reference:i' => \$species_reference);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor ('-host' => $core_host,
					     '-user' => $core_dbuser,
					     '-dbname' => $core_dbname );

my $sth = $db->prepare("select id,internal_id from contig");

unless ($sth->execute()) {
  $db->throw("Failed execution of a select query");
}

my %contig_name2internal_id;

while (my ($id,$internal_id) = $sth->fetchrow_array()) {
  $contig_name2internal_id{$id} = $internal_id;
}

$db = new Bio::EnsEMBL::DBSQL::DBAdaptor ('-host' => $feature_host,
					  '-user' => $feature_dbuser,
					  '-pass' => $feature_pass,
					  '-dbname' => $feature_dbname );


while (<>) {
  my ($contig1,$start1,$end1,$strand1,$contig2,$start2,$end2,$strand2) = split;
  print "$contig1,$start1,$end1,$strand1,$contig2,$start2,$end2,$strand2\n";
  my $internal_id = $contig_name2internal_id{"contig".$species_reference};
  my $sth;
  if ($species_reference == 1) {
    my $internal_id = $contig_name2internal_id{$contig1};
    $sth = $db->prepare("insert into feature (contig,seq_start,seq_end,score,strand,analysis,name,hstart,hend,hid) values ($internal_id,$start1,$end1,100,$strand1,1,\"exonerate\",$start2,$end2,\"$contig2\");");
  } elsif ($species_reference == 2) {
    my $internal_id = $contig_name2internal_id{$contig2};
    $sth = $db->prepare("insert into feature (contig,seq_start,seq_end,score,strand,analysis,name,hstart,hend,hid) values ($internal_id,$start2,$end2,100,$strand2,1,\"exonerate\",$start1,$end1,\"$contig1\");");
  }
  unless ($sth->execute()) {
    $db->throw("Failed execution of an insert");
  }
}
