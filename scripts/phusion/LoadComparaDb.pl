#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;

my $usage = "\nUsage: $0 [options] File|STDIN

$0 -dbname ensembl_compara_12_1 \
-conf_file /nfs/acari/cara/.Registry.conf -file filename
-alignment_type PHUSION_BLASTN -cs_genome_db_id 1 -qy_genome_db_id 2 -qy_tag Mm -load tab

Options:

 -file	filename
 -dbname      compara database name
 -conf_file	/nfs/acari/cara/.Registry.conf
 -cs_genome_db_id   genome_db_id of the consensus species (e.g. 1 for Homo_sapiens)
 -qy_genome_db_id   genome_db_id of the query species (e.g. 2 for Mus_musculus)
 -alignment_type type of alignment stored e.g.PHUSION_BLASTN (default: PHUSION_BLASTN)
 -qy_tag corresponds to the prefix used in the name of the query DNA dumps
 -tab	0 or 1 (1)tab delimited files or (0)use DBAdaptor and load line by line (default)
\n";

my $help = 0;
my ($dbname, $conf_file, $tab, $file);
my $cs_genome_db_id;
my $qy_genome_db_id;
my $qy_tag;
my $alignment_type = 'PHUSION_BLASTN';
my $cs_coord_type; 
my $qy_coord_type;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'conf_file=s' => \$conf_file,
	   'file=s' => \$file,
	   'cs_genome_db_id=i' => \$cs_genome_db_id,
	   'qy_genome_db_id=i' => \$qy_genome_db_id,
	   'tab=i'		=> \$tab,
	   'alignment_type=s' => \$alignment_type,
	   'qy_tag=s' => \$qy_tag);

if ($help) {
  print $usage;
  exit 0;
}
my ($GAB, $GA, $GAG);
if ($tab){
	$GAB=$file.".GAB";
	$GAG=$file.".GAG";
	$GA=$file.".GA";
	open (GAB, ">$GAB") or die "can't open $GAB:$!\n";
	open (GAG, ">$GAG") or die "can't open $GAG:$!\n";
	open (GA, ">$GA") or die "can't open $GA:$!\n";
	}

if (defined $conf_file) {
  Bio::EnsEMBL::Registry->load_all($conf_file);
}
else {
	print " Need Registry file \n"; exit 2;
	}

my $db = "Bio::EnsEMBL::Registry";

my $comparadb=$db->get_DBAdaptor($dbname, 'compara') or die "no comparadbadaptor:$dbname, 'compara' \n";

my $stored_max_alignment_length;
my $meta_con = $db->get_adaptor($dbname, 'compara', 'MetaContainer') or die "no metadbadaptor:$dbname, 'compara','MetaContainer' \n";
my $values=$meta_con->list_value_by_key("max_alignment_length");

if(@$values) {
  $stored_max_alignment_length = $values->[0];
}

my $gdb_adaptor = $db->get_adaptor($dbname, 'compara', 'GenomeDB') or die "no Genomedbadaptor:$dbname, 'compara' \n";
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id) or die "no dbId in :$dbname, '$cs_genome_db_id' \n";
my $qy_genome_db= $gdb_adaptor->fetch_by_dbID($qy_genome_db_id) or die "no dbId in :$dbname, '$qy_genome_db_id' \n";

my @genomicaligns;


####adapters needed: MethodLinkSpeciesSet, GenomicAlignBlock(for 2 GA, and one GenomicAlignBlock), GenomicAlignGroup for 2, DnaFrag, SliceX2(core)

my $mlss_adaptor = $db->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');
my $galnb_adaptor = $db->get_adaptor($dbname, 'compara', 'GenomicAlignBlock');
my $galn_group_adaptor = $db->get_adaptor($dbname, 'compara', 'GenomicAlignGroup');

my $consensus_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $query_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup ();

my $dnafrag_adaptor = $db->get_adaptor($dbname, 'compara', 'DnaFrag');
my $cs_sliceadaptor= $db->get_adaptor($cs_genome_db->name, 'core', 'Slice');
my @cs_chromosomes = @{$cs_sliceadaptor->fetch_all('toplevel')};
my %cs_chromosomes;

foreach my $chr (@cs_chromosomes) {
  $cs_chromosomes{$chr->seq_region_name} = $chr;
#  print STDERR $chr->seq_region_name." Target\n";
}


#print STDERR $qy_genome_db->name.", ".$qy_genome_db->assembly."\n";
my $qy_sliceadaptor= $db->get_adaptor($qy_genome_db->name,'core', 'Slice');
my @qy_chromosomes = @{$qy_sliceadaptor->fetch_all('toplevel')};
my %qy_chromosomes;

foreach my $chr (@qy_chromosomes) {
#  $qy_chromosomes{$chr->chr_name} = $chr;
  $qy_chromosomes{$chr->seq_region_name} = $chr;
#  print STDERR $chr->seq_region_name." Query\n";
}
# note the use of "->dbc->prepare" for these direct sql queries
my $sth_method_link = $comparadb->dbc->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
$sth_method_link->execute($alignment_type);
my ($method_link_id) = $sth_method_link->fetchrow_array();

unless (defined $method_link_id) {
  warn "There is no type $alignment_type in the method_link table of compara db.
EXIT 1";
  exit 1;
}

#Set the group type -- ie which organism based on eg grouped_on_genome_db_id_1_with_2
my $group_type="on_GDBid_".$cs_genome_db_id."_with_".$qy_genome_db_id;


my $sth_method_link_species = $comparadb->dbc->prepare("
SELECT ml.method_link_id
FROM method_link_species_set mls1, method_link_species_set mls2, method_link ml
WHERE mls1.method_link_id = ml.method_link_id AND
      mls2.method_link_id = ml.method_link_id AND
      mls1.genome_db_id = ? AND
      mls2.genome_db_id = ? AND
      mls1.method_link_species_set_id = mls2.method_link_species_set_id AND
      ml.method_link_id = ?");

$sth_method_link_species->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
my ($already_stored) = $sth_method_link_species->fetchrow_array();

my ($species_set_id, $max_species_set, $GAB_id, $qy_GA_id, $cs_GA_id, $method_link_species_set);



if (defined $already_stored){
	print "Method_link_species_set already_stored for $cs_genome_db_id, $qy_genome_db_id, $method_link_id.\n";
	#Need to get a method_link_species_set object;
  	$method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($alignment_type, [$cs_genome_db_id, $qy_genome_db_id]);
	$species_set_id=$method_link_species_set->dbID;
	}
else{
	#Make and store the method_link_species_set object
  $sth_method_link_species = $comparadb->dbc->prepare("SELECT max(method_link_species_set_id) FROM method_link_species_set");#NB nolonger depends on the method_link_id
  $sth_method_link_species->execute();
   ($max_species_set) = $sth_method_link_species->fetchrow_array();

  $max_species_set = 0 unless (defined $max_species_set); #ie if table empty 
  $species_set_id = $max_species_set+1;
  
	$method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet();
	#SET VALUES
  $method_link_species_set->dbID($species_set_id);
  $method_link_species_set->adaptor($mlss_adaptor);
  $method_link_species_set->method_link_type($alignment_type);
  $method_link_species_set->species_set([$cs_genome_db, $qy_genome_db]);
  $mlss_adaptor->store($method_link_species_set);


#NB no genomic_align_genome any more 
}

##set genomic_align_block_id and genomic_align_id from method_link_
$GAB_id=$species_set_id*10000000000;
$qy_GA_id=$GAB_id;
$cs_GA_id=$qy_GA_id+1;
#print "$species_set_id\n$GAB_id\n$qy_GA_id\n$cs_GA_id\n";
open (FILE, $file) or die "can't open $file: $!\n";

my $level =0;

my $max_alignment_length = 0;

my $prev_cs_chr= 'a'; my $prev_qy_chr= 'a';	
 my ($cs_dnafrag, $qy_dnafrag, $cs_dnafrag_id, $qy_dnafrag_id);
my ($d1,$query_coords,$d3,$d4,$cs_chr,$cs_start,$cs_end,$cs_strand, $qy_strand, $d9, $score, $percid, $cigar);

while (defined (my $line = <FILE>) ) {
  chomp $line;
  ($d1,$query_coords,$d3,$d4,$cs_chr,$cs_start,$cs_end,$qy_strand,$d9,$score,$percid,$cigar) = split /\t/,$line;
  
  
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
  
# set consensus strand -- always 1 Also set group and level which are unknown ie 0
  $cs_strand = 1;
my  $group=0;
my  $level =0;
  if (defined $cigar) {
    $cigar =~ s/D/X/g;
    $cigar =~ s/I/D/g;
    $cigar =~ s/X/I/g;
  } else {
    warn "The following line has no cigarline:
$line\n";
    $cigar = "";
  }
	my ($cs_cigar, $qy_cigar, $length)=parse_old_cigar_line($cigar);
  
unless ($cs_chr eq  $prev_cs_chr){ 
  
  $cs_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
  $cs_dnafrag->name($cs_chr); #ie just 22
  $cs_dnafrag->genome_db($cs_genome_db);
  $cs_dnafrag->coord_system_name($cs_chromosomes{$cs_chr}->coord_system->name());
  $cs_dnafrag->length($cs_chromosomes{$cs_chr}->length);
  $cs_dnafrag_id=$dnafrag_adaptor->is_already_stored($cs_dnafrag); ###returns the dnafrag_id
  
  unless($cs_dnafrag_id){
  		$dnafrag_adaptor->store($cs_dnafrag);
  	}
}
unless ($qy_chr eq  $prev_qy_chr){ #print STDERR $cs_dnafrag->type ."CS_TYPE\n";
#print STDERR "cs_coord_type for $cs_chr ($qy_chr): ".$cs_dnafrag->type($cs_chromosomes{$cs_chr}->coord_system->name())."\n";
  $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $qy_dnafrag->name($qy_chr);
  $qy_dnafrag->genome_db($qy_genome_db);
  $qy_dnafrag->coord_system_name($qy_chromosomes{$qy_chr}->coord_system->name());
  $qy_dnafrag->length($qy_chromosomes{$qy_chr}->length);
  $qy_dnafrag_id=$dnafrag_adaptor->is_already_stored($qy_dnafrag);
  unless($qy_dnafrag_id){
  		$dnafrag_adaptor->store($qy_dnafrag);
  	}
}
if ($tab>0){

	print GAB "$GAB_id\t$species_set_id\t$score\t$percid\t$length\n";  
	print GA  "$qy_GA_id\t$GAB_id\t$species_set_id\t$qy_dnafrag_id\t$qy_start\t$qy_end\t$qy_strand\t$qy_cigar\t$level\n"; #No level yet 
	print GA  "$cs_GA_id\t$GAB_id\t$species_set_id\t$cs_dnafrag_id\t$cs_start\t$cs_end\t$cs_strand\t$cs_cigar\t$level\n";
	print GAG "$group\t$group_type\t$qy_GA_id\n"; #possability of two differnet groupings for the two species
	print GAG "$group\t$group_type\t$cs_GA_id\n";
	}
else{
#clear everything first
	$query_genomic_align->dbID(0);
  	$query_genomic_align->genomic_align_block_id(0);
  	$query_genomic_align->method_link_species_set_id(0);
  	$query_genomic_align->dnafrag_id(0);
  	$consensus_genomic_align->dbID(0);
  	$consensus_genomic_align->genomic_align_block_id(0);
  	$consensus_genomic_align->method_link_species_set_id(0);
  	$consensus_genomic_align->dnafrag_id(0);
  	$genomic_align_block->dbID(0);
  	$genomic_align_block->dbID($GAB_id);

#first the query_genomic_align 

	$query_genomic_align->dbID($qy_GA_id);
  	$query_genomic_align->genomic_align_block_id($GAB_id);	
  	$query_genomic_align->method_link_species_set($method_link_species_set);
  	$query_genomic_align->dnafrag($qy_dnafrag);
  	$query_genomic_align->dnafrag_start($qy_start);
  	$query_genomic_align->dnafrag_end($qy_end);
  	$query_genomic_align->dnafrag_strand($qy_strand);
  	$query_genomic_align->cigar_line($qy_cigar);
  	$query_genomic_align->level_id($level);

#2nd: consensus_genomic_align 
  	$consensus_genomic_align->dbID($cs_GA_id);
  	$consensus_genomic_align->genomic_align_block_id($GAB_id);	
  	$consensus_genomic_align->method_link_species_set($method_link_species_set);
  	$consensus_genomic_align->dnafrag($cs_dnafrag);
  	$consensus_genomic_align->dnafrag_start($cs_start);
  	$consensus_genomic_align->dnafrag_end($cs_end);
  	$consensus_genomic_align->dnafrag_strand($cs_strand);
  	$consensus_genomic_align->cigar_line($cs_cigar);
  	$consensus_genomic_align->level_id($level);

#3rd genomic_align_block --  
  	$genomic_align_block->method_link_species_set($method_link_species_set);
  	$genomic_align_block->score($score);
  	$genomic_align_block->length($length);
  	$genomic_align_block->perc_id($percid);
  	$genomic_align_block->genomic_align_array([$consensus_genomic_align, $query_genomic_align]);

#4th genomic_align_group 
  	$genomic_align_group->dbID($group);
  	$genomic_align_group->type($group_type);
  	$genomic_align_group->genomic_align_array([$consensus_genomic_align, $query_genomic_align]);

  ## Store genomic_align_block (this stores genomic_aligns as well)
  	$galnb_adaptor->store($genomic_align_block);

  ## Store genomic_align_group
  	$galn_group_adaptor->store($genomic_align_group);



   }
  $prev_cs_chr=$cs_chr;
  $prev_qy_chr=$qy_chr;
  
  $GAB_id=$GAB_id+2;
  $qy_GA_id=$qy_GA_id+2;
  $cs_GA_id=$cs_GA_id+2;
  
}



######Again only store if not creating tab file-- otherwise store in 
if ($tab){
	print STDERR "max alignment length = ".($max_alignment_length + 1)."\n";
	}
else{
	if (! defined $stored_max_alignment_length) {
  		$meta_con->store_key_value("max_alignment_length",$max_alignment_length + 1);
	} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
 	 $meta_con->update_key_value("max_alignment_length",$max_alignment_length + 1);
	}
}
close FILE; if ($tab){close GAB; close GA; close GAG;}
print STDERR "Done\n";


##############################################################################
##############################################################################
##############################################################################
##  PARSE OLD CIGAR LINE
=head2 parse_old_cigar_line
 Arg [1]    : string $old_cigar_line
   Example    : 
   Description: 
   Returntype : 
   Exceptions : 
     
=cut
     
     
###############################################################################
sub parse_old_cigar_line {
  my ($old_cigar_line) = @_;
  my ($consensus_cigar_line, $query_cigar_line, $length);
  
  my @pieces = split(/(\d*[DIMG])/, $old_cigar_line);
  
  #   print join("<- ->", @pieces);
  
  my $consensus_matches_counter = 0;
  my $query_matches_counter = 0;
  foreach my $piece ( @pieces ) {
  next if ($piece !~ /^(\d*)([MDI])$/);
  	my $num = ($1 or 1);
	my $type = $2;
	
	if( $type eq "M" ) {
	$consensus_matches_counter += $num;
	$query_matches_counter += $num;
	
	} elsif( $type eq "D" ) {
   	$consensus_cigar_line .= (($consensus_matches_counter == 1) ? "" : $consensus_matches_counter)."M";
   	$consensus_matches_counter = 0;
   	$consensus_cigar_line .= (($num == 1) ? "" : $num)."G";
   	$query_matches_counter += $num;
	
	} elsif( $type eq "I" ) {
	$consensus_matches_counter += $num;
	$query_cigar_line .= (($query_matches_counter == 1) ? "" : $query_matches_counter)."M";
	$query_matches_counter = 0;
	$query_cigar_line .= (($num == 1) ? "" : $num)."G";
	}
  $length += $num;
   }
$consensus_cigar_line .= (($consensus_matches_counter == 1) ? "" : $consensus_matches_counter)."M"
if ($consensus_matches_counter);
$query_cigar_line .= (($query_matches_counter == 1) ? "" : $query_matches_counter)."M"
if ($query_matches_counter);

#   print join("\n", $old_cigar_line, $consensus_cigar_line, $query_cigar_line, $length);

return ($consensus_cigar_line, $query_cigar_line, $length);
}




