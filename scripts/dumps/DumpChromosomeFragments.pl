#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;
use Bio::PrimarySeq;
use Getopt::Long;

my $usage = "
DumpChromosomeFragments.pl -host ecs1b.sanger.ac.uk 
            -dbuser ensro
            -dbname homo_sapiens_core_10_30
            -chr_names \"22\"
            -chr_start 1
            -chr_end 1000000
            -overlap 0
            -chunk_size 60000
            -masked 0
            -phusion Hs
            -o output_filename

$0 [-help]
   -host core_db_host_server
   -user username (default = 'ensro')
   -dbname core_database_name
   -chr_names \"20,21,22\" (default = \"all\")
   -chr_start position on chromosome from dump start (default = 1)
   -chr_end position on chromosome to dump end (default = chromosome length)
   -chunk_size bp size of the sequence fragments dumped (default = 60000)
   -overlap overlap between chunk fragments (default = 0)
   -masked status of the sequence 0 unmasked (default)
                                  1 masked
                                  2 soft-masked
   -phusion \"Hs\" tag put in the FASTA header >Hs22.1 
   -o output_filename


";

$| = 1;

my $host = 'localhost';
my $dbname;
my $dbuser = 'ensro';
my $chr_names = "all";
my $chr_start;
my $chr_end;
my $overlap = 0;
my $chunk_size = 60000;
my $masked = 0;
my $phusion;
my $output;
my $port="";
my $help = 0;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'port=i' => \$port,
	   'chr_names=s' => \$chr_names,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'overlap=i' => \$overlap,
	   'chunk_size=i' => \$chunk_size,
	   'masked=i' => \$masked,
	   'phusion=s' => \$phusion,
	   'o=s' => \$output);

if ($help) {
  print $usage;
  exit 0;
}

# Some checks on arguments

unless ($dbname) {
  warn "dbname must be specified
exit 1\n";
  exit 1;
}

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
					     -user => $dbuser,
					     -dbname => $dbname,
					     -port => $port);

my $ChromosomeAdaptor = $db->get_ChromosomeAdaptor;
my $SliceAdaptor = $db->get_SliceAdaptor;

my $chromosomes;

if (defined $chr_names and $chr_names ne "all") {
  my @chr_names = split /,/, $chr_names;
  foreach my $chr_name (@chr_names) {
    push @{$chromosomes}, $ChromosomeAdaptor->fetch_by_chr_name($chr_name);
  }
} else {
  $chromosomes = $ChromosomeAdaptor->fetch_all;
}
 
if (scalar @{$chromosomes} > 1 && 
    (defined $chr_start || defined $chr_end)) {
  warn "When more than one chr_name is specified chr_start and chr_end must not be specified
exit 1\n";
  exit 1;
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
  
my $fh = \*STDOUT;
if (defined $output) {
  open F, ">$output";
  $fh = \*F;
}    

foreach my $chr (@{$chromosomes}) {
  print STDERR "fetching slice...\n";
 
  # futher checks on arguments

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
  
  my $slice;
  if ($chr_start && $chr_end) {
    $slice = $SliceAdaptor->fetch_by_chr_start_end($chr->chr_name,$chr_start,$chr_end);
  } else {
    $slice = $SliceAdaptor->fetch_by_chr_name($chr->chr_name);
  }
  
  print STDERR "..fetched slice for chromosome ",$slice->chr_name," from position ",$slice->chr_start," to position ",$slice->chr_end,"\n";

  printout_by_overlapping_chunks($slice,$overlap,$chunk_size,$fh);
  
  $chr_end = undef;
}

close $fh;

sub printout_by_overlapping_chunks {
  my ($slice,$overlap,$chunk_size,$fh) = @_;
  my $seq;

  if ($masked == 1) {

    print STDERR "getting masked sequence...\n";
    $seq = $slice->get_repeatmasked_seq;
    $seq->id($slice->chr_name);
    print STDERR "...got masked sequence\n";

  } elsif ($masked == 2) {

    print STDERR "getting soft masked sequence...\n";
    $seq = $slice->get_repeatmasked_seq(undef,1);
    $seq->id($slice->chr_name);
    print STDERR "...got soft masked sequence\n";

  } else {

    print STDERR "getting unmasked sequence...\n";
    $seq = Bio::PrimarySeq->new( -id => $slice->chr_name, -seq => $slice->seq);
    print STDERR "...got unmasked sequence\n";

  }

  print STDERR "sequence length : ",$seq->length,"\n";
  print STDERR "printing out the sequences chunks...";

  for (my $i=1;$i<=$seq->length;$i=$i+$chunk_size-$overlap) {
    
    my $chunk;
    if ($i+$chunk_size-1 > $seq->length) {
      
      my $chr_start = $i+$slice->chr_start-1;
      my $id;
      if (defined $phusion) {
	$id = join ".", ($phusion.$seq->id,$chr_start);
      } else {
	$id = join ".", ($seq->id,$chr_start,$slice->chr_end);
      }
      $chunk = Bio::PrimarySeq->new (-seq => $seq->subseq($i,$seq->length),
				     -id  => $id,
				     -moltype => 'dna'
				    );
      
    } else {

      my $chr_start = $i+$slice->chr_start-1;
      my $id;
      if (defined $phusion) {
	$id = join ".", ($phusion.$seq->id,$chr_start);
      } else {
	$id = join ".", ($seq->id,$chr_start,$chr_start+$chunk_size-1);
      }
      $chunk = Bio::PrimarySeq->new (-seq => $seq->subseq($i,$i+$chunk_size-1),
				     -id  => $id,
				     -moltype => 'dna'
				    );
    }
    my $output_seq = Bio::SeqIO->new( -fh => $fh, -format => 'Fasta');
    $output_seq->write_seq($chunk);
  }
  print STDERR "Done\n";
}
