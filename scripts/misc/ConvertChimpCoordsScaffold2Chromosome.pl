#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;

$| = 1;

my $help = 0;
my $host;
my $port;
my $dbname;
my $dbuser = "ensro";
my $dbpass;
my $conf_file;
my $dest_host;
my $dest_port;
my $dest_dbname;
my $dest_dbuser;
my $dest_dbpass;

my $species1 = "Homo sapiens";
my $assembly1 = "NCBI34";
my $species2 = "Pan troglodytes";
my $assembly2 = "CHIMP1";
my $alignment_type = "BLASTZ_RECIP_NET";

GetOptions('host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'conf_file=s' => \$conf_file,
           'dest_host=s' => \$dest_host,
	   'dest_port=i' => \$dest_port,
	   'dest_dbname=s' => \$dest_dbname,
	   'dest_dbuser=s' => \$dest_dbuser,
           'dest_dbpass=s' => \$dest_dbpass);


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname,
                                                     -conf_file => $conf_file);

my $converted_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $dest_host,
                                                               -port   => $dest_port,
                                                               -user   => $dest_dbuser,
                                                               -pass   => $dest_dbpass,
                                                               -dbname => $dest_dbname);

my $chimp_agp_file = "/nfs/acari/abel/src/ensembl_main/ensembl-compara/scripts/misc/all.agp";

open AGP, $chimp_agp_file ||
  die "$!\n";

my %scaffold2chr;

while (<AGP>) {
  next unless (/\tscaffold_\d+\t/);
  chomp;
  my ($chr,$chr_start,$chr_end,undef,undef,$scaffold,$start,$end,$strand) = split /\t/;
  $chr =~ s/^ptr//;
  $strand = 1 if ($strand eq "+");
  $strand = -1 if ($strand eq "-");
#  print "$chr $chr_start $chr_end $scaffold $start $end $strand\n";
  $scaffold2chr{$scaffold} = [$chr,$chr_start,$chr_end,$strand];
}

close AGP;

my $gdb1 = $db->get_GenomeDBAdaptor->fetch_by_name_assembly($species1,$assembly1);
my $gdb2 = $db->get_GenomeDBAdaptor->fetch_by_name_assembly($species2,$assembly2);

my $dfa = $db->get_DnaFragAdaptor;
my $gaa = $db->get_GenomicAlignAdaptor;
my $converted_dfa = $converted_db->get_DnaFragAdaptor;
my $converted_gaa = $converted_db->get_GenomicAlignAdaptor;

my %chr2dnafrag;

foreach my $slice (@{$gdb2->db_adaptor->get_SliceAdaptor->fetch_all('toplevel')}) {
#  print $slice->seq_region_name," ",$slice->start," ",$slice->end," ",$slice->coord_system->name,"\n";
  my $df = Bio::EnsEMBL::Compara::DnaFrag->new_fast
    ({
      'name' => $slice->seq_region_name,
      'type' => $slice->coord_system->name,
      'start' => $slice->start,
      'end' => $slice->end,
      'genomedb' => $gdb2
     });
  $converted_dfa->store_if_needed($df);
  $chr2dnafrag{$slice->seq_region_name} = $df;
}


foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($gdb1)}) {
  my @gas;
  foreach my $ga (@{$gaa->fetch_all_by_DnaFrag_GenomeDB($df, $gdb2, $df->start, $df->end, $alignment_type)}) {
    my ($scaffold_chr_name, $scaffold_chr_start,$scaffold_chr_end, $strand) = @{$scaffold2chr{$ga->query_dnafrag->name}};
    my $new_query_dnafrag = $chr2dnafrag{$scaffold_chr_name};
    my $new_query_start;
    my $new_query_end;
    my $new_query_strand;
    my $length = $ga->query_end - $ga->query_start;
    if ($strand > 0) {
      $new_query_start = $ga->query_start + $scaffold_chr_start - 1;
      $new_query_end = $new_query_start + $length;
      $new_query_strand = $ga->query_strand;
    } elsif ($strand < 0) {
      $new_query_start = $scaffold_chr_end - $ga->query_end + 1;
      $new_query_end = $new_query_start + $length;
      $new_query_strand = $ga->query_strand * $strand;
    }
    print STDERR $new_query_dnafrag->name," ",$new_query_start," ",$new_query_end," ",$new_query_strand,"\n---\n";
    $ga->query_dnafrag($new_query_dnafrag);
    $ga->query_start($new_query_start);
    $ga->query_end($new_query_end);
    $ga->query_strand($new_query_strand);
    push @gas, $ga;
#    exit;
  }
  $converted_gaa->store(\@gas);
  print STDERR scalar @gas," loaded\n";
}

