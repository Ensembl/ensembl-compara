#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;

my $usage = "\nUsage: $0 [options] File|STDIN

$0 -host ecs2d.sanger.ac.uk -dbuser ensadmin -dbpass xxxx -port 3352 -dbname ensembl_compara_12_1 \
-conf_file /nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf
-alignment_type WGA -cs_genome_db_id 1 -qy_genome_db_id 2 -qy_tag Mm -alignment_type WGA

Options:

 -host        host for compara database
 -dbname      compara database name
 -dbuser      username for connection to \"compara_dbname\"
 -pass        passwd for connection to \"compara_dbname\"
 -port		port no for compara db
 -cs_genome_db_id   genome_db_id of the consensus species (e.g. 1 for Homo_sapiens)
 -qy_genome_db_id   genome_db_id of the query species (e.g. 2 for Mus_musculus)
 -alignment_type type of alignment stored e.g.PHUSION_BLASTN (default: PHUSION_BLASTN)
 -qy_tag corresponds to the prefix used in the name of the query DNA dumps
\n";

my $help = 0;
my ($host,$dbname,$dbuser,$dbpass,$conf_file);
my $cs_genome_db_id;
my $qy_genome_db_id;
my $qy_tag;
my $alignment_type = 'PHUSION_BLASTN';
my $cs_coord_type; 
my $qy_coord_type;
my $port= 3352;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'dbname=s' => \$dbname,
	   'conf_file=s' => \$conf_file,
	   'cs_genome_db_id=i' => \$cs_genome_db_id,
	   'qy_genome_db_id=i' => \$qy_genome_db_id,
	   'alignment_type=s' => \$alignment_type,
	   'port=i' => \$port,
	   'qy_tag=s' => \$qy_tag);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-conf_file => $conf_file,
						     -host => $host,
						     -dbname => $dbname,
						     -port => $port,
						     -user => $dbuser,
						     -pass => $dbpass);

my $stored_max_alignment_length;
my $values = $db->get_MetaContainer->list_value_by_key("max_alignment_length");

if(@$values) {
  $stored_max_alignment_length = $values->[0];
}

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id);
my $qy_genome_db = $gdb_adaptor->fetch_by_dbID($qy_genome_db_id);

my @genomicaligns;

my $dnafrag_adaptor = $db->get_DnaFragAdaptor;
my $galn_adaptor = $db->get_GenomicAlignAdaptor;

my $cs_dbadaptor= $db->get_db_adaptor($cs_genome_db->name,$cs_genome_db->assembly);
#my @cs_chromosomes = @{$cs_dbadaptor->get_ChromosomeAdaptor->fetch_all};
my @cs_chromosomes = @{$cs_dbadaptor->get_SliceAdaptor->fetch_all('toplevel')};
my %cs_chromosomes;

foreach my $chr (@cs_chromosomes) {
  $cs_chromosomes{$chr->seq_region_name} = $chr;
}

my $qy_dbadaptor= $db->get_db_adaptor($qy_genome_db->name,$qy_genome_db->assembly);
my @qy_chromosomes = @{$qy_dbadaptor->get_SliceAdaptor->fetch_all('toplevel')};
my %qy_chromosomes;

foreach my $chr (@qy_chromosomes) {
  $qy_chromosomes{$chr->seq_region_name} = $chr;
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

my $max_alignment_length = 0;

while (defined (my $line = <>) ) {
  chomp $line;
  my ($d1,$query_coords,$d3,$d4,$cs_chr,$cs_start,$cs_end,$qy_strand,$d9,$score,$percid,$cigar) = split /\t/,$line;
  
  ($cs_coord_type, $cs_chr) =split /:/, $cs_chr;#####All names should now bw of the form chromosome:2 or scaffold:NA34567 etc
  
  my ($qy_chr,$qy_start,$qy_end);
  if ($query_coords =~ /^$qy_tag(\S+)\.(\d+):(\d+)-(\d+)$/) {###########################This will need to be changed
    ($qy_chr,$qy_start,$qy_end) = ($1,$2+$3-1,$2+$4-1);
  }
  ($qy_coord_type, $qy_chr)=split /:/, $qy_chr;#####All names should now bw of the form chromosome:2 or scaffold:NA34567 etc
  
  my $cs_max_alignment_length = $cs_end - $cs_start + 1;
  $max_alignment_length = $cs_max_alignment_length if ($max_alignment_length < $cs_max_alignment_length);  
  my $qy_max_alignment_length = $qy_end - $qy_start + 1;
  $max_alignment_length = $qy_max_alignment_length if ($max_alignment_length < $qy_max_alignment_length);  

  if ($qy_strand eq "+") {
    $qy_strand = 1;
  } elsif ($qy_strand eq "-") {
    $qy_strand = -1;
  }
  
  my $cs_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $cs_dnafrag->name($cs_chr);
  $cs_dnafrag->genomedb($cs_genome_db);
  $cs_dnafrag->type($cs_coord_type);
  $cs_dnafrag->start(1);
  $cs_dnafrag->end($cs_chromosomes{$cs_chr}->length);
  $dnafrag_adaptor->store_if_needed($cs_dnafrag);

  my $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $qy_dnafrag->name($qy_chr);
  $qy_dnafrag->genomedb($qy_genome_db);
  $qy_dnafrag->type($qy_coord_type);
  $qy_dnafrag->start(1);
  $qy_dnafrag->end($qy_chromosomes{$qy_chr}->length);
  $dnafrag_adaptor->store_if_needed($qy_dnafrag);
  
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
  $genomic_align->perc_id($percid);
  $genomic_align->group_id(0);
  $genomic_align->level_id(0);
  $genomic_align->strands_reversed(0);

  if (defined $cigar) {
    $cigar =~ s/D/X/g;
    $cigar =~ s/I/D/g;
    $cigar =~ s/X/I/g;
  } else {
    warn "The following line has no cigarline:
$line\n";
    $cigar = "";
  }
  $genomic_align->cigar_line($cigar);

  $galn_adaptor->store([$genomic_align]);
}

if (! defined $stored_max_alignment_length) {
  $db->get_MetaContainer->store_key_value("max_alignment_length",$max_alignment_length + 1);
} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
  $db->get_MetaContainer->update_key_value("max_alignment_length",$max_alignment_length + 1);
}
