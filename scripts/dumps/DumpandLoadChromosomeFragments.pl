#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::SeqIO;
use Bio::PrimarySeq;
use Getopt::Long;

my $usage = "
DumpandLoadChromosomeFragments.pl 
	    -host 	ecs1b.sanger.ac.uk 
            -dbuser 	ensadmin
	    -port 	3350
	    -pass	password
	    -species 	'Homo sapiens'
	    -assembly 	NCBI35
            -dbname 	ensembl_compara_22_1
            -overlap 	0
            -chunk_size 60000
            -masked 	0
            -phusion 	Hs
            -mask_restriction RepeatMaksingRestriction.conf
            -o 		output_filename
	    -load 	1

$0 [-help]
   -host compara mysql host
   -dbuser username (default = 'ensadmin')
   -dbname ensembl_compara db name
   -port 	3350
   -pass	password
   -species 	\"Homo sapiens\"
   -assembly 	NCBI35
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
   -o output_filename
   -load 0/1 if true load Dnafrags into db 
   -conf	Compara.conf file


";

$| = 1;

my $host = 'localhost';
my $dbname;
my $dbuser = 'ensadmin';
my $pass;
my $species;
my $assembly;
my $chr_names = "all";
my $overlap = 0;
my $chunk_size = 60000;
my $masked = 0;
my $phusion;
my $output;
my $port="";
my $help = 0;
my $mask_restriction_file;
my $coordinate_system="chromosome";
my $load=0;
my $conf="/nfs/acari/cara/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf";

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'port=i' => \$port,
	   'pass=s' =>\$pass,
	   'species=s' => \$species,
	   'assembly=s' => \$assembly,
	   'overlap=i' => \$overlap,
	   'chunk_size=i' => \$chunk_size,
	   'masked=i' => \$masked,
           'mask_restriction=s' => \$mask_restriction_file,
	   'phusion=s' => \$phusion,
	   'coord_system=s' => \$coordinate_system,
	   'o=s' => \$output,
	   'conf' =>\$conf,
	   'load=i' => \$load);

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

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-conf_file => $conf, 
					     -host => $host,
					     -user => $dbuser,
					     -dbname => $dbname,
					     -port => $port,
					     -pass => $pass);
my %not_default_masking_cases;
if (defined $mask_restriction_file) {
  %not_default_masking_cases = %{do $mask_restriction_file};
}

my $genome_adaptor=$db->get_db_adaptor($species, $assembly);
my $sliceadaptor = $genome_adaptor->get_SliceAdaptor;
my $genome_db_adaptor=$db->get_GenomeDBAdaptor;
my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($species, $assembly);




# include duplicate regions (such as pseudo autosomal regions)
my @chromosomes = @{$sliceadaptor->fetch_all('toplevel', undef, 0)};
my $dnafrag_adaptor = $db->get_DnaFragAdaptor();
 
if (scalar @chromosomes < 1 ) {
  warn "No chromosomes available for toplevel $species, $assembly
exit 1\n";
  exit 1;
}

my $fh = \*STDOUT;
my $filename='';

CHR:foreach my $chr (@chromosomes) {
	if(($chr->seq_region_name =~/MT/)){next CHR;}
	if (defined $output) {
	 	if ($phusion){$filename=$phusion."_".$chr->seq_region_name.".".$output;}
	 	else{$filename=$chr->seq_region_name.".".$output;}
		print STDERR "opening $filename\n";
  		open F, ">$filename";
  		$fh = \*F;
		}    
 	
	print STDERR "printing slice ".$chr->name."...\n";
 	printout_by_overlapping_chunks($chr,$overlap,$chunk_size,$fh);
	if($load){	
		print STDERR "loading dnafrag for ".$chr->name."...\n";
		my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  		$dnafrag->name($chr->seq_region_name); #ie just 22
  		$dnafrag->genomedb($genome_db);
  		$dnafrag->type($chr->coord_system->name());
  		$dnafrag->start(1);
  		$dnafrag->end($chr->length);
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
      $seq = $slice->get_repeatmasked_seq(undef,0,\%not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq;
    }
    $seq->name($slice->seq_region_name);
    print STDERR "...got masked sequence\n";

  } elsif ($masked == 2) {

    print STDERR "getting soft masked sequence...\n";
    if (%not_default_masking_cases) {
      $seq = $slice->get_repeatmasked_seq(undef,0,\%not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq(undef,1);
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
