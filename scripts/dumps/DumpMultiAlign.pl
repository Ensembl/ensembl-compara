#!/usr/local/ensembl/bin/perl -w
# get a slice from the commandline arguments
# get genomicaligns from compara for that slice
# try to get slices for target regions
# pass them in the print option from GenomicAlign object

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

# specify connection to compara
# specify species chromsome start end


# get species DBAdaptor from Compara
# get all the other species that are there in Compara
# get DBAdaptors for them.

unless ( @ARGV ) {
  usage();
  exit();
}

my ( $host, $user, $pass, $port, $dbname, $chromosome, $start, $end,
     $species, $conf_file );


GetOptions(
	   "host=s", \$host,
	   "user=s", \$user,
	   "pass=s", \$pass,
	   "port=i", \$port,
	   "dbname=s", \$dbname,
	   "chromosome=s", \$chromosome,
	   "start=i", \$start,
	   "end=i", \$end,
	   "species=s", \$species,
	   "conf_file=s", \$conf_file
	  );

# change this to use supplied compara database


my $compara = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
  (
   -host => $host,
   -user => $user,
   -dbname => $dbname,
   -pass => $pass,
   -conf_file => $conf_file
  );

# # the following you dont need if you have a  config file for the 
# # compara database (it will attach the ensembl database automatically then)

# my $human_db = Bio::EnsEMBL::DBSQL::DBAdaptor->new
#   (
#    -host => 'ecs2d.internal.sanger.ac.uk',
#    -user => 'ensro',
#    -dbname => 'homo_sapiens_core_10_30'
#   );

# # add the dba to the compara database
# $compara->add_db_adaptor( $human_db );


# my $rat_db = Bio::EnsEMBL::DBSQL::DBAdaptor->new
#   (
#    -host => 'ecs2d.internal.sanger.ac.uk',
#    -user => 'ensro',
#    -dbname => 'rattus_norvegicus_core_9_01'
#   );

# # add the dba to the compara database
# $compara->add_db_adaptor( $rat_db );

# my $mouse_db = Bio::EnsEMBL::DBSQL::DBAdaptor->new
#   (
#    -host => 'ecs2d.internal.sanger.ac.uk',
#    -user => 'ensro',
#    -dbname => 'mus_musculus_core_10_3'
#   );

# # add the dba to the compara database
# $compara->add_db_adaptor( $mouse_db );

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
  fetch_by_chr_start_end( $chromosome, $start, $end );

my $primary_seq = $primary_slice->seq();
my @other_seq;


my $dnafrags = $compara->get_DnaFragAdaptor()->fetch_all_by_GenomeDB_region
  ( 
   $primary_species,
   "Chromosome",
   $chromosome,
   $start,
   $end
  );

my $gaa = $compara->get_GenomicAlignAdaptor;

my @out = ();
my $count = 0;
my $alignments_found = 0;

for( my $i_species = 0; $i_species<=$#other_species; $i_species++ ) {
  my $qy_gdb = $other_species[$i_species];
  $other_seq[$i_species] = "~" x length( $primary_seq );

  foreach my $df (@$dnafrags) {
    #caclulate coords relative to start of dnafrag
    my $df_start = $start - $df->start + 1;
    my $df_end   = $end   - $df->start + 1;
  
    #constrain coordinates so they are completely within the dna frag
    my $len = $df->end - $df->start + 1;
    $df_start = ($df_start < 1)  ? 1 : $df_start;
    $df_end   = ($df_end > $len) ? $len : $df_end;

    #fetch all alignments in the region we are interested in
    my $genomic_aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB($df,
							     $qy_gdb,
							     $df_start,
							     $df_end 
							    );
    
    for my $align ( @$genomic_aligns ) {

      my $cfrag = $align->consensus_dnafrag();
      my $qfrag = $align->query_dnafrag();

  
      my $aligned_string = $align->sequence_align_string
	( 
	 $cfrag->contig(), $qfrag->contig(),
	  "QUERY", "FIX_CONSENSUS" 
	);
      if( ! $aligned_string ) { next } else {$alignments_found = 1; }

      # now put it in the other_seq_array
      my ( $p_start, $p_end );
      $p_start = $align->consensus_start() + $cfrag->start() - $primary_slice->chr_start();
      $p_end = $align->consensus_end() + $cfrag->start() - $primary_slice->chr_start();

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

# printing the results
#
# This code prints 60 bases on top of each other
#
#for( my $i=0; $i<length( $primary_seq ); $i+=60 ){
#  print "$i - ",($i+59),"\n";
#  print substr( $primary_seq, $i, 60 ),"\n";
#  for( my $j=0; $j<=$#other_seq; $j++ ) {
#   print substr( $other_seq[$j], $i, 60 ),"\n";
#  }
#  print "\n"
#}

#
# print a fasta with species name as sequence name
#

print ">".$primary_species->name()."\n";
for( my $i=0; $i<length( $primary_seq ); $i+=60 ){
  print substr( $primary_seq, $i, 60 ),"\n";
}
for( my $i_species = 0; $i_species<=$#other_species; $i_species++ ) {
  print ">".$other_species[$i_species]->name()."\n";
  my $seq=$other_seq[$i_species];
  for( my $i=0; $i<length( $seq ); $i+=60 ){
    print substr( $seq, $i, 60 ),"\n";
  }
}

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
  
  -chromosome -c 
  -start -st
  -end -e 
  -species -sp

  to specify the region you want to dump with alignments to other
  available species.

EOF
}
