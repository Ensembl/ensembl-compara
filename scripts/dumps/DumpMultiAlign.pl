#!/usr/local/ensembl/bin/perl -w
# get a slice from the commandline arguments
# get genomicaligns from compara for that slice
# try to get slices for target regions
# pass them in the print option from GenomicAlign object

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::AlignIO;
use Bio::LocatableSeq;

# specify connection to compara
# specify species chromsome start end


# get species DBAdaptor from Compara
# get all the other species that are there in Compara
# get DBAdaptors for them.

unless ( @ARGV ) {
  usage();
  exit();
}

my ( $host, $user, $port, $dbname, $seq_region, $seq_region_start, $seq_region_end,$species, $conf_file );
my $pass = "";
my $alignment_type = "BLASTZ_NET";
my $output_format = "fasta";
my $coord_system = "chromosome";

GetOptions(
	   "host=s" => \$host,
	   "user=s" => \$user,
	   "pass=s" => \$pass,
	   "port=i" => \$port,
	   "dbname=s" => \$dbname,
	   "seq_region=s" => \$seq_region,
	   "seq_region_start=i" => \$seq_region_start,
	   "seq_region_end=i" => \$seq_region_end,
	   "alignment_type=s" => \$alignment_type,
           "output_format=s" => \$output_format,
           "coord_system=s" => \$coord_system,
	   "species=s" => \$species,
	   "conf_file=s" => \$conf_file
	  );

# change this to use supplied compara database

my $compara = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
                                                          -port => $port,
							  -user => $user,
							  -dbname => $dbname,
							  -pass => $pass,
							  -conf_file => $conf_file);

my $all_genome_dbs = $compara->get_GenomeDBAdaptor()->fetch_all();

# there is a fetch_all on genome_DB, but by time of writing this,
#  compara wasnt filled and configured properly

my ( $primary_species ) = grep { $_->name() eq $species } @$all_genome_dbs;
my ( @other_species ) = grep { $_->name() ne $species } @$all_genome_dbs;

my @wanted_other_species;

foreach my $other_species (@other_species) {
  my $name = $other_species->name;
  my $assembly = $other_species->assembly;
  if (defined $compara->get_db_adaptor($name,$assembly)) {
    push @wanted_other_species,$other_species;
  }
}

@other_species = @wanted_other_species;

my $primary_slice = $primary_species->db_adaptor()->get_SliceAdaptor()->
  fetch_by_region("toplevel",$seq_region, $seq_region_start, $seq_region_end);
my $primary_seq = $primary_slice->seq();
my @other_seq;


my $dnafrags = $compara->get_DnaFragAdaptor()->fetch_all_by_GenomeDB_region
  ( 
   $primary_species,
   $coord_system,
   $seq_region,
   $seq_region_start,
   $seq_region_end
  );

my $gaa = $compara->get_GenomicAlignAdaptor;

my @out = ();
my $count = 0;
my $alignments_found = 0;

for( my $i_species = 0; $i_species<=$#other_species; $i_species++ ) {
  my $qy_gdb = $other_species[$i_species];
  $other_seq[$i_species] = "." x length( $primary_seq );

  foreach my $df (@$dnafrags) {
    #caclulate coords relative to start of dnafrag
    my $df_start = $seq_region_start - $df->start + 1;
    my $df_end   = $seq_region_end   - $df->start + 1;
  
    #constrain coordinates so they are completely within the dna frag
    my $len = $df->end - $df->start + 1;
    $df_start = ($df_start < 1)  ? 1 : $df_start;
    $df_end   = ($df_end > $len) ? $len : $df_end;

    #fetch all alignments in the region we are interested in
    my $genomic_aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB($df,
							     $qy_gdb,
							     $df_start,
							     $df_end,
							     $alignment_type
							    );
    
    for my $align ( @$genomic_aligns ) {

      my ($fake,$aligned_string) = @{$align->alignment_strings("NO_SEQ","FIX_SEQ")};
      if( ! $aligned_string ) { next } else {$alignments_found = 1; }

      # now put it in the other_seq_array
      my ( $p_start, $p_end );
      $p_start = $align->consensus_start() + $align->consensus_dnafrag->start() - $primary_slice->start();
      $p_end = $align->consensus_end() + $align->consensus_dnafrag->start() - $primary_slice->start();

      # put the align string into result
      $count++;
      
      substr( $other_seq[$i_species], $p_start-1, length( $aligned_string ), $aligned_string );
    }
  }
}

if( ! $alignments_found ) {
  print STDERR "Sorry, no alignments found in the specified region.\n";
  exit;
} else {
  print STDERR "$count alignments done\n";
}

my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
                                  -format => $output_format,
                                  -idlength => 20);

my $sa = Bio::SimpleAlign->new();


my $seq = Bio::LocatableSeq->new(-SEQ    => $primary_seq,
                                 -START  => 1,
                                 -END    => length($primary_seq),
                                 -ID     => $primary_species->name(),
                                 -STRAND => 0);

$sa->add_seq($seq);

for( my $i_species = 0; $i_species<=$#other_species; $i_species++ ) {
  my $seq=$other_seq[$i_species];
  my $locseq = Bio::LocatableSeq->new(-SEQ    => $seq,
                                 -START  => 1,
                                 -END    => length($seq),
                                 -ID     => $other_species[$i_species]->name(),
                                 -STRAND => 0);
  $sa->add_seq($locseq);
}

print $alignIO $sa;

exit;


sub usage {
  print STDERR <<EOF

Usage: DumpMultiAlign.pl options
  where options should be 
  
  -host -h 
  -user -u 
  -pass -pa
  -port -po
  -dbname -d
  -conf_file filename
  to specify compara database connection
  
  -seq_region
  -seq_region_start
  -seq_region_end
  -alignment_type e.g. WGA (default WGA)
  -species -sp

  to specify the region you want to dump with alignments to other
  available species.

EOF
}
