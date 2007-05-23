#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception;
use Getopt::Long;

#########################
##this should become the default version so that when we have everything as scaffold:ctg1234 or chromosome:22 these can be utilised 
####
#### NB not tested
################


my $usage = "\nUsage: $0 [options] axtFile|STDIN

 Insert BLAT alignments into compara db or into tab delimited files for import

$0 -file BLAT_parsed_data_file -dbname ensembl_compara_12_1 \
-conf_file /nfs/acari/cara/.Registry.conf
-alignment_type WGA_BLAT -cs_genome_db_id 1 -qy_genome_db_id 2 -load tab

Options:

 -file  BLAT_parsed_data_file \(for whole genome\)
 -dbname      compara database name or alias
 -cs_genome_db_id   genome_db_id of the consensus species (e.g. 1 for Homo_sapiens)
 -qy_genome_db_id   genome_db_id of the query species (e.g. 2 for Mus_musculus)
 -alignment_type type of alignment stored e.g.TRANSLATED_BLAT (default: TRANSLATED_BLAT) 
 -conf_file registry conf file
 -tab  0 or 1 (1)tab delimited files or (0)use DBAdaptor and load line by line (default)

\n";


my $help = 0;

my ($file, $host, $dbname, $dbuser, $pass, $tab, $DNA, $GAB, $GA, $GAG);
my ($cs_genome_db_id, $qy_genome_db_id, $conf_file, $cs_coord, $qy_coord);
my $port=3306;

my $alignment_type = 'TRANSLATED_BLAT';

GetOptions('h'       => \$help,
     'file=s'     => \$file,
     'dbname=s'     => \$dbname,
     'cs_genome_db_id=s'   => \$cs_genome_db_id,
     'qy_genome_db_id=s'   => \$qy_genome_db_id,
     'alignment_type=s'   => \$alignment_type,
     'tab=i'    => \$tab,
     'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

unless (defined $file &&
  defined $dbname &&
  defined $cs_genome_db_id &&
  defined $qy_genome_db_id) {
  print "
!!! IMPORTANT : All following parameters should be defined !!!
  file (whole genome)
  dbname
  cs_genome_db_id 
  qy_genome_db_id
";
  print $usage;
  exit 0;
}

#########The use of the coord_

if ($tab){
  $GAB="genomic_align_block.".$file;
  $GA="genomic_align.".$file;
  open (GAB, ">$GAB") or die "can't open $GAB:$!\n";
  open (GA, ">$GA") or die "can't open $GA:$!\n";
  }

#if (defined $conf_file) {
  Bio::EnsEMBL::Registry->load_all($conf_file);
#}
#else {
#  print " Need Registry file \n"; exit 2;
#  }

my $db = "Bio::EnsEMBL::Registry";

my $comparadb=$db->get_DBAdaptor($dbname, 'compara') or die "no comparadbadaptor:$dbname, 'compara' \n";

my $meta_con = $db->get_adaptor($dbname, 'compara', 'MetaContainer') or die "no metadbadaptor:$dbname, 'compara','MetaContainer' \n";

my $gdb_adaptor = $db->get_adaptor($dbname, 'compara', 'GenomeDB') or die "no Genomedbadaptor:$dbname, 'compara' \n";
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id) or die "no dbId in :$dbname, '$cs_genome_db_id' \n";
my $qy_genome_db = $gdb_adaptor->fetch_by_dbID($qy_genome_db_id) or die "no dbId in :$dbname, '$qy_genome_db_id' \n";

my @genomicaligns;


####adapters needed: MethodLinkSpeciesSet, GenomicAlignBlock(for 2 GA, and one GenomicAlignBlock), DnaFrag, SliceX2(core)

my $mlss_adaptor = $db->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');
my $galnb_adaptor = $db->get_adaptor($dbname, 'compara', 'GenomicAlignBlock');

my $consensus_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $query_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();

my $dnafrag_adaptor = $db->get_adaptor($dbname, 'compara', 'DnaFrag');
##my $cs_sliceadaptor= $db->get_adaptor($cs_genome_db->name, 'core', 'Slice');
##my @cs_chromosomes = @{$cs_sliceadaptor->fetch_all('toplevel')};
##my %cs_chromosomes;
##
##foreach my $chr (@cs_chromosomes) {
##  $cs_chromosomes{$chr->seq_region_name} = $chr;
###  print STDERR $chr->seq_region_name." Target\n";
##}


#print STDERR $qy_genome_db->name.", ".$qy_genome_db->assembly."\n";
##my $qy_sliceadaptor= $db->get_adaptor($qy_genome_db->name,'core', 'Slice');
##my @qy_chromosomes = @{$qy_sliceadaptor->fetch_all('toplevel')};
##my %qy_chromosomes;
##
##foreach my $chr (@qy_chromosomes) {
###  $qy_chromosomes{$chr->chr_name} = $chr;
##  $qy_chromosomes{$chr->seq_region_name} = $chr;
###  print STDERR $chr->seq_region_name." Query\n";
##}


# note the use of "->dbc->prepare" for these direct sql queries
##my $sth_method_link = $comparadb->dbc->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
##$sth_method_link->execute($alignment_type);
##my ($method_link_id) = $sth_method_link->fetchrow_array();
my $method_link_id = $mlss_adaptor->get_method_link_id_from_method_link_type($alignment_type);

unless (defined $method_link_id) {
  warn "There is no type $alignment_type in the method_link table of compara db.
EXIT 1";
  exit 1;
}

my $sth_method_link_species = $comparadb->dbc->prepare("
  SELECT
    MAX(method_link_species_set_id)+1
  FROM method_link_species_set
  WHERE method_link_species_set_id < 10000
  ");

$sth_method_link_species->execute();
my ($method_link_species_set_id) = $sth_method_link_species->fetchrow_array();

my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -dbId => $method_link_species_set_id,
        -adaptor => $mlss_adaptor,
        -method_link_type => $alignment_type,
        -species_set => [$cs_genome_db, $qy_genome_db],
    );
$mlss_adaptor->store($method_link_species_set);

##set genomic_align_block_id and genomic_align_id from method_link_
$method_link_species_set_id = $method_link_species_set->dbID;
my $GAB_id = $method_link_species_set_id * 10000000000;
my $qy_GA_id = $GAB_id;
my $cs_GA_id = $qy_GA_id+1;

open (FILE, $file) or die "can't open $file: $!\n";

my $level =0;

my $max_alignment_length = 0;

my ($cs_chr,$cs_start,$cs_end, $cs_strand, $qy_chr, $qy_start, $qy_end, $qy_strand, $score, $percid, $group, $cigar, $qy_cigar, $cs_cigar, $length);
my ($no, $qy_sps, $Qchr_type, $prog, $typ, $cs_sps, $Tchr_type, $posit); 

print STDERR "Reading BLAT--gff alignments in progress...\n";

$group = $GAB_id; ## Start with $GAB_id to follow the same numbering convention
my $previous_group = 0;
my $prev_cs_chr = ''; my $prev_qy_chr = '';  
my ($cs_dnafrag, $qy_dnafrag, $cs_dnafrag_id, $qy_dnafrag_id);

LINE:while (my $line =<FILE>) {
#get rid of first line (or any other title lines if they were catted together)
  chomp $line;
  next LINE if ($line=~/prog/);

  ($no, $qy_sps, $qy_chr, $prog, $typ, $qy_start, $qy_end, $qy_strand, $cs_sps, $cs_chr,
      $cs_start, $cs_end, $cs_strand, $score, $percid, $posit, $cigar) = split /\t/,$line;

  ## Assign group_id according to the previous qy_chr, cs_chr and group_id
  $no=~/\d+\((\d+)\)/;
  my $this_group = $1;
  if ($prev_qy_chr ne $qy_chr or $prev_cs_chr ne $cs_chr or $previous_group != $this_group) {
    $group++;
    $previous_group = $this_group;
  }
      
  ## Get cigar_lines
  my $qy_length = $qy_end - $qy_start + 1;
  my $cs_length = $cs_end - $cs_start + 1;
  if ($alignment_type =~/TRANSLATED_BLAT/) {
    $qy_cigar=$qy_length."M"; # tBLAT generates ungapped alignments only
    $cs_cigar=$qy_cigar;
    $length=$qy_length;
    unless ($qy_length == $cs_length){
      print STDERR "lengths not equal $qy_length != $cs_length\n";
      print STDERR "$line\n";
    }
  } else {
    ($cs_cigar, $qy_cigar, $length) = parse_old_cigar_line($cigar);
  }

  ## make strand -1 or 1 rather than - or +
  $cs_strand = ($cs_strand eq '-')?"-1":"1";
  $qy_strand = ($qy_strand eq '-')?"-1":"1";

  ## Get max_alignment_length
  $max_alignment_length = $cs_length if ($max_alignment_length < $cs_length);  
  $max_alignment_length = $qy_length if ($max_alignment_length < $qy_length);

  ## Get the dnafrag_ids from the DB
  unless ($cs_chr eq  $prev_cs_chr) {
    $cs_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
            $cs_genome_db, $cs_chr);
    throw("Cannot find Dnafrag for ".$cs_genome_db->name.".".$cs_chr." (consensus)") if (!$cs_dnafrag);
    $cs_dnafrag_id = $cs_dnafrag->dbID;
  }
  unless ($qy_chr eq  $prev_qy_chr) {
    $qy_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($qy_genome_db, $qy_chr);
    throw("Cannot find Dnafrag for ".$qy_genome_db->name.".".$qy_chr." (query)") if (!$qy_dnafrag);
    $qy_dnafrag_id = $qy_dnafrag->dbID;
  }

  ######################################################################################################################
  ###
  ###    print tab file OR store in DB
  ###
  ######################################################################################################################
  ## GAB  = genomic_align_block_id, method_link_species_set_id, score, perc_id, length
  ## GA   = genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
  ##       dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, level_id
  ##       X 2
  ######################################################################################################################
  
  if ($tab>0){
    print GAB "$GAB_id\t$method_link_species_set_id\t$score\t$percid\t$length\t$group\n";  
    print GA  "$qy_GA_id\t$GAB_id\t$method_link_species_set_id\t$qy_dnafrag_id\t",
        "$qy_start\t$qy_end\t$qy_strand\t$qy_cigar\t$level\n";
    print GA  "$cs_GA_id\t$GAB_id\t$method_link_species_set_id\t$cs_dnafrag_id\t",
        "$cs_start\t$cs_end\t$cs_strand\t$cs_cigar\t$level\n";
  } else {
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
    $genomic_align_block->group_id($group);

    ## Store genomic_align_block (this stores genomic_aligns as well)
    $galnb_adaptor->store($genomic_align_block);

  }
  $prev_cs_chr=$cs_chr;
  $prev_qy_chr=$qy_chr;
  
  $GAB_id=$GAB_id+2;
  $qy_GA_id=$qy_GA_id+2;
  $cs_GA_id=$cs_GA_id+2;

}



######Again only store if not creating tab file-- otherwise store in DB
if ($tab) {
  open (META, ">meta.$file") or die "can't open meta.$file:$!\n";
  my $all_meta_ids = get_all_meta_ids($meta_con, "max_align_".$method_link_species_set->dbID);
  if (!@$all_meta_ids) {
    print META "NULL\tmax_align_".$method_link_species_set->dbID."\t", ($max_alignment_length + 1), "\n";
  } else {
    foreach my $meta_id (@$all_meta_ids) {
      print META "$meta_id\tmax_align_".$method_link_species_set->dbID."\t", ($max_alignment_length + 1), "\n";
    }
  }
  close META;
  close GAB;
  close GA;
} else {
  ## New max_alignment_length is method_link_species_set-specific!
  if (@{$meta_con->list_value_by_key("max_align_".$method_link_species_set->dbID)}) {
    $meta_con->update_key_value("max_align_".$method_link_species_set->dbID, $max_alignment_length + 1);

  } else {
    $meta_con->store_key_value("max_align_".$method_link_species_set->dbID, $max_alignment_length + 1);
  }
}
close FILE;
print STDERR "Done\n";


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


=head2 get_all_meta_ids

  Arg [1]    : string $meta_key
  Example    : 
  Description: 
  Returntype : listref of ints
  Exceptions : 
     
=cut

sub get_all_meta_ids {
  my ($meta_container_adaptor, $meta_key) = @_;
  my $meta_ids = [];

  my $sth = $meta_container_adaptor->prepare(
      "SELECT meta_id FROM meta WHERE meta_key = ? ORDER BY meta_id");
  $sth->execute($meta_key);
  while (my $arrRef = $sth->fetchrow_arrayref()) {
    push(@$meta_ids, $arrRef->[0]);
  }

  return $meta_ids;
}
