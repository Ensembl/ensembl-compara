#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Getopt::Long;

#########################
##this should become the default version so that when we have everything as scaffold:ctg1234 or chromosome:22 these can be utilised 
####
#### NB not tested
################


my $usage = "\nUsage: $0 [options] axtFile|STDIN

 Insert into a compara database BLAT alignments

$0 -file BLAT_parsed_data_file -host ecs2d.internal.sanger.ac.uk -dbuser ensadmin -dbpass xxxx -dbname ensembl_compara_12_1 \
-conf_file /nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf
-alignment_type WGA_BLAT -cs_genome_db_id 1 -qy_genome_db_id 2 

Options:

 -file	BLAT_parsed_data_file
 -host        host for compara database
 -dbname      compara database name
 -port 		eg3353
 -dbuser      username for connection to \"compara_dbname\"
 -pass        passwd for connection to \"compara_dbname\"
 -cs_genome_db_id   genome_db_id of the consensus species (e.g. 1 for Homo_sapiens)
 -qy_genome_db_id   genome_db_id of the query species (e.g. 2 for Mus_musculus)
 -alignment_type type of alignment stored e.g.TRANSLATED_BLAT (default: WGA_BLAT) 
 -confi_file compara conf file

\n";


my $help = 0;

my ($file, $host, $dbname, $dbuser, $pass);
my ($cs_genome_db_id, $qy_genome_db_id, $conf_file, $cs_coord, $qy_coord);
my $port=3306;

my $alignment_type = 'TRANSLATED_BLAT';

GetOptions('h' => \$help,
	   'file=s' => \$file,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'pass=s' => \$pass,
	   'port=i' => \$port,
	   'cs_genome_db_id=s' => \$cs_genome_db_id,
	   'qy_genome_db_id=s' => \$qy_genome_db_id,
	   'alignment_type=s' => \$alignment_type,
	   'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

unless (defined $file &&
	defined $host &&
	defined $dbname &&
	defined $dbuser &&
	defined $pass &&
	defined $cs_genome_db_id &&
	defined $qy_genome_db_id &&
	defined $conf_file) {
  print "
!!! IMPORTANT : All following parameters should be defined !!!
  file
  host
  dbname
  dbuser
  pass
  cs_genome_db_id 
  qy_genome_db_id
  conf_file
  
";
  print $usage;
  exit 0;
}

#########The use of the coord_

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor ('-conf_file' => $conf_file,
						      '-host' => $host,
						      '-user' => $dbuser,
						      '-port' => $port,
						      '-dbname' => $dbname,
						      '-pass' => $pass);

my $stored_max_alignment_length;
my $values = $db->get_MetaContainer->list_value_by_key("max_alignment_length");

if(@$values) {
  $stored_max_alignment_length = $values->[0];
}

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id);
my $qy_genome_db= $gdb_adaptor->fetch_by_dbID($qy_genome_db_id);

my @genomicaligns;




my $dnafrag_adaptor = $db->get_DnaFragAdaptor;
my $galn_adaptor = $db->get_GenomicAlignAdaptor;

my $cs_dbadaptor= $db->get_db_adaptor($cs_genome_db->name,$cs_genome_db->assembly);
#my @cs_chromosomes = @{$cs_dbadaptor->get_ChromosomeAdaptor->fetch_all};
my @cs_chromosomes = @{$cs_dbadaptor->get_SliceAdaptor->fetch_all('toplevel') };
my %cs_chromosomes;

foreach my $chr (@cs_chromosomes) {
  $cs_chromosomes{$chr->seq_region_name} = $chr;
#  print STDERR $chr->seq_region_name." Target\n";
}


#print STDERR $qy_genome_db->name.", ".$qy_genome_db->assembly."\n";
my $qy_dbadaptor= $db->get_db_adaptor($qy_genome_db->name,$qy_genome_db->assembly);
my @qy_chromosomes = @{$qy_dbadaptor->get_SliceAdaptor->fetch_all('toplevel')};
my %qy_chromosomes;

foreach my $chr (@qy_chromosomes) {
#  $qy_chromosomes{$chr->chr_name} = $chr;
  $qy_chromosomes{$chr->seq_region_name} = $chr;
#  print STDERR $chr->seq_region_name." Query\n";
}
# Updating method_link_species if needed (maybe put that in GenomicAlignAdaptor store method)

my $sth_method_link = $db->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
$sth_method_link->execute($alignment_type);
my ($method_link_id) = $sth_method_link->fetchrow_array();

unless (defined $method_link_id) {
  warn "There is no type $alignment_type in the method_link table of compara db.
EXIT 1";
  exit 1;
}

my $sth_method_link_species = $db->prepare("
SELECT ml.method_link_id
FROM method_link_species mls1, method_link_species mls2, method_link ml
WHERE mls1.method_link_id = ml.method_link_id AND
      mls2.method_link_id = ml.method_link_id AND
      mls1.genome_db_id = ? AND
      mls2.genome_db_id = ? AND
      mls1.species_set = mls2.species_set AND
      ml.method_link_id = ?");

$sth_method_link_species->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
my ($already_stored) = $sth_method_link_species->fetchrow_array();

unless (defined $already_stored) {
  $sth_method_link_species = $db->prepare("SELECT max(species_set) FROM method_link_species where method_link_id = ?");
  $sth_method_link_species->execute($method_link_id);
  my ($max_species_set) = $sth_method_link_species->fetchrow_array();

  $max_species_set = 0 unless (defined $max_species_set);

  $sth_method_link_species = $db->prepare("INSERT INTO method_link_species (method_link_id,species_set,genome_db_id) VALUES (?,?,?)");
  $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$cs_genome_db_id);
  $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$qy_genome_db_id);
}


# Updating genomic_align_genome if needed (maybe put that in GenomicAlignAdaptor store method)
my $sth_genomic_align_genome = $db->prepare("SELECT method_link_id FROM genomic_align_genome WHERE consensus_genome_db_id = ? AND query_genome_db_id = ? AND method_link_id = ?");
$sth_genomic_align_genome->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
($already_stored) = $sth_genomic_align_genome->fetchrow_array();

unless (defined $already_stored) {
  $sth_genomic_align_genome = $db->prepare("INSERT INTO genomic_align_genome (consensus_genome_db_id,query_genome_db_id,method_link_id) VALUES (?,?,?)");
  $sth_genomic_align_genome->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
}



open (FILE, $file) or die "can't open $file: $!\n";


my $max_alignment_length = 0;

#my ($axt_number,$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score);
#my ($ref_seq,$qy_seq);
my @DnaDnaAlignFeatures;
#my %repeated_alignment;
my ($no, $Qsps, $Qchr_type, $Qchr, $prog, $typ, $Qstart, $Qend, $Qstrand, $Tsps, $Tchr_type, $Tchr, $Tstart, $Tend, $Tstrand, $score, $ident, $posit, $flip, $cigar); 
#NB NEED TO RECREATE CIGARS FROM THE LENGTHS OF THE ALIGNMENTS --SHOULD BE ok as NO GAPS

print STDERR "Reading BLAT--gff alignments in progress...\n";
LINE:while (my $line =<FILE>) {
#get rid of first line (or any other title lines if they were catted together)
	chomp $line;
	if ($line=~/prog/){
		next LINE;
		}
	else {
		($no, $Qsps, $Qchr, $prog, $typ, $Qstart, $Qend, $Qstrand, $Tsps, $Tchr, $Tstart, $Tend, $Tstrand, $score, $ident, $posit, $cigar)=split /\t/,$line;
		}

      $no=~/\d+\((\d+)\)/;
      my $group =$1;
      my $Qlength = $Qend - $Qstart+1;
      my $Tlength = $Tend - $Tstart+1;
      unless ($Qlength== $Tlength){
      	print STDERR "lengths not equal $Qlength != $Tlength\n";
	print STDERR "$line\n";
      	}
	 $cigar=$Qlength."M";

#Removed the monscore as the scores reported are for each member of a PSL line and therefore shouldn't be used to eliminate single hsps

#make strand -1 or 1 rather than - or +
if ($Tstrand eq '-'){ $Tstrand = '-1';}
else { $Tstrand = '1';}
if ($Qstrand eq '-'){ $Qstrand = '-1';}
else { $Qstrand = '1';}
  
  #print STDERR "making new DnaDna\n";  

    my $f = new Bio::EnsEMBL::DnaDnaAlignFeature(-cigar_string => $cigar);
    
    $f->seqname($Tchr);
    $f->start($Tstart);
    $f->end($Tend);
    $f->strand($Tstrand);
    $f->hseqname($Qchr);
    $f->hstart($Qstart);
    $f->hend($Qend);#This H stuff should really be the target as feature pairs bases itself on the query name 
    $f->hstrand($Qstrand); #This varies as consensus(target) remains +ive
    $f->score($score);
    $f->percent_id($ident);
    $f->group_id($group);
    
    push @DnaDnaAlignFeatures,$f ;

  
}



print STDERR "Reading BLAT alignments done\n";

print STDERR "Preparing data for storage for ". scalar @DnaDnaAlignFeatures . " features...\n";

foreach my $f (@DnaDnaAlignFeatures) {
my $flip =0;
if ($f->strand== "-1"){
#	print STDERR "reversing ".$f->seqname.", ".$f->start.", ".$f->end.", ".$f->hseqname.", ".$f->hstart.", ".$f->hend.", ".$f->hstrand.", ".$f->cigar_string."\n";
	$f->reverse_complement();
	$flip =1; 
#	print STDERR "reversed ".$f->seqname.", ".$f->start.", ".$f->end.", ".$f->hseqname.", ".$f->hstart.", ".$f->hend.", ".$f->hstrand.", ".$f->cigar_string."\n";
	}
	
  my ($cs_chr,$cs_start,$cs_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score,$percid,$group, $cigar) = ($f->seqname,$f->start,$f->end,$f->hseqname,$f->hstart,$f->hend,$f->hstrand,$f->score,$f->percent_id,$f->group_id, $f->cigar_string);

  my $cs_max_alignment_length = $cs_end - $cs_start + 1;
  $max_alignment_length = $cs_max_alignment_length if ($max_alignment_length < $cs_max_alignment_length);  
  my $qy_max_alignment_length = $qy_end - $qy_start + 1;
  $max_alignment_length = $qy_max_alignment_length if ($max_alignment_length < $qy_max_alignment_length);

  
  my $cs_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $cs_dnafrag->name($cs_chr); #ie just 22
  $cs_dnafrag->genomedb($cs_genome_db);
  $cs_dnafrag->type($cs_chromosomes{$cs_chr}->coord_system->name());
  $cs_dnafrag->start(1);
  $cs_dnafrag->end($cs_chromosomes{$cs_chr}->length);
  $dnafrag_adaptor->store_if_needed($cs_dnafrag);
  
  #print STDERR $cs_dnafrag->type ."CS_TYPE\n";
#print STDERR "cs_coord_type for $cs_chr ($qy_chr): ".$cs_dnafrag->type($cs_chromosomes{$cs_chr}->coord_system->name())."\n";
  my $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $qy_dnafrag->name($qy_chr);
  $qy_dnafrag->genomedb($qy_genome_db);
  $qy_dnafrag->type($qy_chromosomes{$qy_chr}->coord_system->name());
  $qy_dnafrag->start(1);
  $qy_dnafrag->end($qy_chromosomes{$qy_chr}->length);
  $dnafrag_adaptor->store_if_needed($qy_dnafrag);
#print STDERR "cs_coord_type for $qy_chr: ".$qy_dnafrag->type($qy_chromosomes{$qy_chr}->coord_system->name())."\n";
  
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align->consensus_dnafrag($cs_dnafrag);
  $genomic_align->consensus_start($cs_start);
  $genomic_align->consensus_end($cs_end);
  $genomic_align->query_dnafrag($qy_dnafrag);
  $genomic_align->query_start($qy_start);
  $genomic_align->query_end($qy_end);
  $genomic_align->query_strand($qy_strand);
  $genomic_align->alignment_type($alignment_type);
  $genomic_align->score($score);
  $percid = 0 unless (defined $percid);
  $genomic_align->perc_id($percid);
  $genomic_align->group_id($group);
  $genomic_align->level_id(0);
  $genomic_align->strands_reversed($flip);
  $genomic_align->cigar_line($cigar);

  $galn_adaptor->store([$genomic_align]);

  # think here to revert cigar_string if strand==-1 !!

}

if (! defined $stored_max_alignment_length) {
  $db->get_MetaContainer->store_key_value("max_alignment_length",$max_alignment_length + 1);
} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
  $db->get_MetaContainer->update_key_value("max_alignment_length",$max_alignment_length + 1);
}
close FILE;
print STDERR "Done\n";

sub identity {
  my ($ref_seq,$qy_seq) = @_;
  
  my $length = length($ref_seq);
  
  unless (length($qy_seq) == $length) {
    warn "reference sequence length ($length bp) and query sequence length (".length($qy_seq)." bp) should be identical
exit 1\n";
    exit 1;
  }
  
  my @ref_seq_array = split //, $ref_seq;
  my @qy_seq_array = split //, $qy_seq;
  my $number_identity = 0;

  for (my $i=0;$i<$length;$i++) {
    if (lc $ref_seq_array[$i] eq lc $qy_seq_array[$i]) {
      $number_identity++;
    }
  }
  return int($number_identity/$length*100);
}

