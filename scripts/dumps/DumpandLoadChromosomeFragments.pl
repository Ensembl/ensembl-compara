#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::SeqIO;
use Bio::PrimarySeq;
use Getopt::Long;

my $usage = "
DumpandLoadChromosomeFragments.pl 
	    -assembly 	'NCBI35'
            -dbname 	ensembl_compara_22_1
            -overlap 	0
            -chunk_size 60000
            -masked 	0
            -phusion 	Hs
            -mask_restriction RepeatMaksingRestriction.conf
            -o 		output_filename ending
	    -reg_conf	Registry.conf
	    -group	no of files to group the scaffolds into (if needed)
	    -load 	1
	    -dump 	1
	    -all	1

$0 [-help]
   -dbname ensembl_compara db name or alias
   -assembly 	\"NCBI35\"
   -chunk_size bp size of the sequence fragments dumped (default = 60000)
   -overlap overlap between chunk fragments (default = 0)
   -masked status of the sequence 0 unmasked (default)
                                  1 masked
                                  2 soft-masked
   -phusion \"Hs\" tag put in the FASTA header >Hs22.1 
   -mask_restriction RepeatMaksingRestriction.conf 
                     Allow you to do hard and soft masking at the same time
                     depending on the repeat class or name. See RepeatMaksingRestriction.conf.example,
                     and the get_repeatmasked_seq method in Bio::EnsEMBL::Slice
   -o output_filename ending eg fa
   -group	100
   -load 0/1 if true load Dnafrags into db 
   -dump 0/1 if true dump Dnafrags into flatfiles 
   -all	0/1   if true then put all chunks into same file
   -reg_conf	Registry.conf file


";

$| = 1;

my $all;
my $group;
my $host = 'localhost';
my $dbname;
my $assembly;
my $chr_names = "all";
my $overlap = 0;
my $chunk_size = 60000;
my $masked = 0;
my $phusion;
my $output;
my $help = 0;
my $mask_restriction_file;
my $coordinate_system="chromosome";
my $load=0;
my $dump=0;
my $conf="/nfs/acari/cara/.Registry.conf";

GetOptions('help'	=> \$help,
	   'dbname=s'	=> \$dbname,
	   'assembly=s' => \$assembly,
	   'overlap=i'	=> \$overlap,
	   'chunk_size=i' => \$chunk_size,
	   'masked=i'	=> \$masked,
           'mask_restriction=s' => \$mask_restriction_file,
	   'phusion=s'	=> \$phusion,
	   'coord_system=s' => \$coordinate_system,
	   'o=s'	=> \$output,
	   'reg_conf=s' => \$conf,
	   'group=i'	=> \$group,
	   'load=i'	=> \$load,
	   'all=i'	=> \$all,
	   'dump=i'	=> \$dump);

if ($help) {
  print $usage;
  exit 0;
}
print "dump =$dump and load = $load \n\n";
if (defined $conf) {
  Bio::EnsEMBL::Registry->load_all($conf);
}
else {print " Need Registry file \n"; exit 2;}
print "Got them \n";
my $sliceadaptor = Bio::EnsEMBL::Registry->get_adaptor($assembly,'core','Slice') or die "can't get sliceadaptor for: $assembly,'core','Slice'\n";
print "Got sliceadaptor $sliceadaptor\n";
					     
my %not_default_masking_cases;
if (defined $mask_restriction_file) {
  %not_default_masking_cases = %{do $mask_restriction_file};
}
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB') or die "can't get genome_db_adaptor for $dbname,'compara','GenomeDB'\n";
my $genome_db_all = $genome_db_adaptor->fetch_all;
my $genome_db; 
print "no in genome_db: ".scalar(@$genome_db_all)."\n";
foreach my $gdb (@$genome_db_all){
#print "assembly=$assembly\t".$gdb->assembly."\n";
if ($gdb->assembly eq $assembly) { $genome_db = $gdb};
}


my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaFrag');

# include duplicate regions (such as pseudo autosomal regions)
my @chromosomes = @{$sliceadaptor->fetch_all('toplevel', undef, 0, 1)};
print "no of chromosomes: ".scalar @chromosomes ."\n"; 
if (scalar @chromosomes < 1 ) {
  warn "No chromosomes available for toplevel $assembly
exit 1\n";
  exit 1;
}

my $fh = \*STDOUT;
my $filename='';
my $count =0; my $file_no = 0;

CHR:foreach my $chr (@chromosomes) {
	if(($chr->seq_region_name =~/[M|m][T|t]/)){next CHR;}
	$count++;
	if ($group) {  if($count==$group) {$count = 0; $file_no++; }}
	if (($dump>0) && (defined $output)) {
		if ($all){
			$filename = "all.".$output;
			}
		elsif ($group){
			$filename=$file_no.".".$output;
			}
		else {
			$filename=$chr->seq_region_name.".".$output;
			}
			
		print STDERR "opening $filename\n";
  		open F, ">>$filename";
  		$fh = \*F;
		}    
 	
	if($dump>0) {
		print STDERR "printing slice ".$chr->name."...\n";
 		printout_by_overlapping_chunks($chr,$overlap,$chunk_size,$fh);
		}
	if($load>0){	
		print STDERR "loading dnafrag for ".$chr->name."...\n";
		my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  		$dnafrag->name($chr->seq_region_name); #ie just 22
  		$dnafrag->genome_db($genome_db);
  		$dnafrag->coord_system_name($chr->coord_system->name());
  		$dnafrag->length($chr->length);
  		$dnafrag_adaptor->store_if_needed($dnafrag);
	}
close $fh;


}


sub printout_by_overlapping_chunks {
  my ($slice,$overlap,$chunk_size,$fh) = @_;
  my $seq;

  if ($masked == 1) {

    print STDERR "getting masked sequence...\n";
    if (%not_default_masking_cases) {
      $seq = $slice->get_repeatmasked_seq(['RepeatMask', 'trf'],0,\%not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq;
    }
    $seq->name($slice->seq_region_name);
    print STDERR "...got masked sequence\n";

  } elsif ($masked == 2) {

    print STDERR "getting soft masked sequence...\n";
    if (%not_default_masking_cases) {
      $seq = $slice->get_repeatmasked_seq(['RepeatMask', 'trf'],1,\%not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq(['RepeatMask', 'trf'],1);
    }
    $seq->name($slice->seq_region_name);
    print STDERR "...got soft masked sequence\n";

  } else {

    print STDERR "getting unmasked sequence...\n";
    $seq = Bio::PrimarySeq->new( -id => $slice->seq_region_name, -seq => $slice->seq);
    print STDERR "...got unmasked sequence\n";

  }

  print STDERR "sequence length : ",$seq->length,"\n";
  print STDERR "printing out the sequences chunks...";

  for (my $i=1;$i<=$seq->length;$i=$i+$chunk_size-$overlap) {
    
    my $chunk;
    if ($i+$chunk_size-1 > $seq->length) {
      
      my $chr_start = $i+$slice->start-1;
      my $id;
      if (defined $phusion) {
	$id = $phusion.".".$coordinate_system.":".$slice->seq_region_name.".".$chr_start;
      } else {
	$id = $coordinate_system.":".$slice->seq_region_name.".".$chr_start.".".$slice->end;
      }
      $chunk = Bio::PrimarySeq->new (-seq => $seq->subseq($i,$seq->length),
				     -id  => $id,
				     -moltype => 'dna'
				    );
      
    } else {

      my $chr_start = $i+$slice->start-1;
      my $id;
      if (defined $phusion) {
	$id = $phusion.".".$coordinate_system.":".$slice->seq_region_name.".".$chr_start;
      } else {
	$id = $coordinate_system.":".$slice->seq_region_name.".".$chr_start.".".$chr_start+$chunk_size-1;
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
