#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::AlignIO;
use Getopt::Long;


my $usage = "
$0
  [--help]                        this menu
   --src_dbname string            (e.g. compara23) one of the compara source database Bio::EnsEMBL::Registry aliases
  [--dest_dbname string]          (e.g. compara23) one of the compara destination database Bio::EnsEMBL::Registry aliases
                                  if not specified it will be set to src_dbname
   --seq_region string            (e.g. 22)
  [--seq_region_start integer]    (e.g. 50000000)
  [--seq_region_end integer]      (e.g. 50500000)
   --qy string                    (e.g. human) the query species (i.e. a Bio::EnsEMBL::Registry alias)
                                  from which alignments are queried and seq_region refer to
   --tg string                    (e.g. mouse) the target species (i.e. a Bio::EnsEMBL::Registry alias)
                                  to which alignments are queried
  [--src_method_link_type string] (e.g. BLASTZ_NET) type of alignment queried (default: BLASTZ_NET)
  [--dest_method_link_type string](e.g. BLASTZ_NET_TIGHT) type of alignment to store (default: BLASTZ_NET_TIGHT)
  [--reg_conf filepath]           the Bio::EnsEMBL::Registry configuration file. If none given, 
                                  the one set in ENSEMBL_REGISTRY will be used if defined, if not
                                  ~/.ensembl_init will be used.
  [--matrix filepath]             matrix file to be used in the subsetAxt rescoring process (default: 
                                  /nfs/acari/abel/src/ensembl_main/ensembl-compara/scripts/hcr/tight.mat)
                                  A    C    G    T
                                  100 -200  -100 -200
                                  -200  100 -200  -100
                                  -100 -200  100 -200
                                  -200  -100 -200   100
                                  O = 2000, E = 50
  [--threshold integer]           score below which the rescored alignment is not keeped (default: 3400)

\n";


my ($src_dbname, $dest_dbname);
my ($seq_region,$seq_region_start,$seq_region_end);
my ($qy_species,$tg_species);
my $help = 0;
my $src_method_link_type = "BLASTZ_NET";
my $dest_method_link_type = "BLASTZ_NET_TIGHT";
my $method_link_id = 2;
my $matrix = "/nfs/acari/abel/src/ensembl_main/ensembl-compara/scripts/hcr/tight.mat";
my $threshold = 3400;
my $reg_conf;
my $limit_number = 10000;
my $limit_index_start = 0;

GetOptions('help' => \$help,
	   'src_dbname=s' => \$src_dbname,
	   'dest_dbname=s' => \$dest_dbname,
	   'seq_region=s' => \$seq_region,
	   'seq_region_start=i' => \$seq_region_start,
	   'seq_region_end=i' => \$seq_region_end,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species,
	   'src_method_link_type=s' => \$src_method_link_type,
	   'dest_method_link_type=s' => \$dest_method_link_type,
	   'matrix=s' => \$matrix,
	   'threshold=i' => \$threshold,
           'limit_number=i' => \$limit_number,
           'limit_index_start=i' => \$limit_index_start,
           'reg_conf=s' => \$reg_conf);

$|=1;

unless (defined $dest_dbname) {
  $dest_dbname = $src_dbname;
}

if ($help) {
  print $usage;
  exit 0;
}

my $subsetAxt_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/subsetAxt";

if (-e "/proc/version") {
  # it is a linux machine
  $subsetAxt_executable = "/nfs/acari/abel/bin/i386/subsetAxt";
}

exit 1 unless (-e $subsetAxt_executable);

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
if (defined $reg_conf) {
Bio::EnsEMBL::Registry->load_all($reg_conf);
}
else {print " Need Registry file \n"; exit 2;}

my $qy_sa = Bio::EnsEMBL::Registry->get_adaptor($qy_species,'core','Slice');
throw "Cannot get adaptor for ($qy_species,'core','Slice')" if (!$qy_sa);

my $tg_sa = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','Slice');
throw "Cannot get adaptor for ($tg_species,'core','Slice')" if (!$tg_sa);

my $dest_dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($src_dbname,'compara')->dbc;

my $gaba = Bio::EnsEMBL::Registry->get_adaptor($src_dbname,'compara','GenomicAlignBlock');
my $gdba = Bio::EnsEMBL::Registry->get_adaptor($src_dbname,'compara','GenomeDB');
my $dfa = Bio::EnsEMBL::Registry->get_adaptor($src_dbname,'compara','DnaFrag');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($src_dbname,'compara','MethodLinkSpeciesSet');

my $qy_slice = $qy_sa->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);
my $qy_binomial = Bio::EnsEMBL::Registry->get_adaptor($qy_species,'core','MetaContainer')->get_Species->binomial;
my $qy_gdb = $gdba->fetch_by_name_assembly($qy_binomial);
my ($qy_dnafrag) = @{$dfa->fetch_all_by_GenomeDB_region($qy_gdb,$qy_slice->coord_system->name,$qy_slice->seq_region_name)};

my %tg_slices;
my %tg_dnafrags;
my $tg_binomial = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','MetaContainer')->get_Species->binomial;
my $tg_gdb = $gdba->fetch_by_name_assembly($tg_binomial);

my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($src_method_link_type, [$qy_gdb->dbID, $tg_gdb->dbID]);
my %repeated_alignment;

my $dest_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
$dest_mlss->species_set([$tg_gdb, $qy_gdb]);
$dest_mlss->method_link_type($dest_method_link_type);

while (1)  {
  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $qy_dnafrag, undef, undef, $limit_number, $limit_index_start);

  last unless (scalar @$gabs);
  print STDERR "Preparing to rescore ",scalar @$gabs," gabs\n";
  my $axtFile = generateAxt($gabs);
  my $rescored_axtFile = subsetAxt($subsetAxt_executable,$axtFile, $matrix, $threshold);
  my $nb_gab = storeAxt($rescored_axtFile, $dest_dbname, $dest_mlss);
  
  print STDERR "Nb of gab loaded: $nb_gab\n";

  unlink $axtFile;
  unlink $rescored_axtFile;

  $limit_index_start += $limit_number;
}

sub generateAxt {
  my $gabs = shift;

  my $index = 0;
  my $rand = $$."_".time()."_".rand(1000);
  my $file_prefix = "/tmp/$rand";

  open F, ">>$file_prefix.in";

  foreach my $gab (@{$gabs}) {
    my $header = "$index ";
    my $aligned_sequences = "";

    if ($gab->reference_genomic_align->dnafrag_strand < 0) {
      $gab->reverse_complement;
    }

    my $ga = $gab->reference_genomic_align;
    $header .= $ga->dnafrag->name . " ";
    $header .= $ga->dnafrag_start . " ";
    $header .= $ga->dnafrag_end . " ";
    $aligned_sequences .= $ga->aligned_sequence . "\n";

    $ga = $gab->get_all_non_reference_genomic_aligns->[0];
    my ($hstrand, $hstart, $hend);
    if ($ga->dnafrag_strand < 0)  {
      $hstrand = "-";
      $hstart = $ga->dnafrag->length - $ga->dnafrag_end + 1;
      $hend = $ga->dnafrag->length - $ga->dnafrag_start + 1;
    } else {
      $hstrand = "+";
      $hstart = $ga->dnafrag_start;
      $hend = $ga->dnafrag_end;
    }
    $header .= $ga->dnafrag->name . " ";
    $header .= $hstart . " ";
    $header .= $hend . " ";
    $header .= $hstrand . " ";
    $aligned_sequences .= $ga->aligned_sequence . "\n";
#print STDERR $ga->dbID."\n$header\n";    
    $header .= $gab->score . "\n";
#print STDERR "and after\n$header\n";    

    print F $header;
    print F $aligned_sequences;
    print F "\n";
    $index++;
  }
  close F;
  return "$file_prefix.in"
}

sub subsetAxt {
  my ($subsetAxt_executable, $axtFile, $matrix, $threshold) = @_;

 

  unless (system("$subsetAxt_executable $axtFile $axtFile.out $matrix $threshold") == 0) {
    unlink "$axtFile.out";
    return 0;
  } else {
    return "$axtFile.out";
  }
}

sub storeAxt {
  my ($axtfile, $dbname, $method_link_species_set) = @_;

  my $gaba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomicAlignBlock');
  my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet');

  open AXT, $axtfile;
  
  $mlssa->store($method_link_species_set);
  print STDERR "method_link_species_set_id: ",$method_link_species_set->dbID,"\n";
  my $nb_of_gab_loaded = 0;

  my ($axt_number,$qy_chr,$qy_start,$qy_end,$tg_chr,$tg_start,$tg_end,$tg_strand,$score, $qy_seq, $tg_seq, $tg_slice);

  while (my $line = <AXT>) {
    if ($line =~ /^\d+\s+\S+\s+\d+\s+\d+\s+\S+\s+\d+\s+\d+\s+[\+\-]\s+\-?\d+$/) {
      chomp $line;
      ($axt_number,$qy_chr,$qy_start,$qy_end,$tg_chr,$tg_start,$tg_end,$tg_strand,$score) = split /\s/, $line;
      
      if (defined $repeated_alignment{$qy_chr."_".$qy_start."_".$qy_end."_".$tg_chr."_".$tg_start."_".$tg_end}) {
        print STDERR "Repeated alignment: $line\n";
        while ($line =<AXT>) {
          last if ($line =~ /^$/);
        }
        next;
      }
      $repeated_alignment{$qy_chr."_".$qy_start."_".$qy_end."_".$tg_chr."_".$tg_start."_".$tg_end} = 1;
      
      unless (defined $tg_slices{$tg_chr}) {
        $tg_slices{$tg_chr} = $tg_sa->fetch_by_region('toplevel',$tg_chr);
      }
      $tg_slice = $tg_slices{$tg_chr};

      if ($tg_strand eq "+") {
        $tg_strand = 1;
      }
      if ($tg_strand eq "-") {
        $tg_strand = -1;
        my $length = $tg_end - $tg_start;
        
        $tg_start = $tg_slice->seq_region_length - $tg_end + 1;
        $tg_end = $tg_start + $length;
      }
    }
    
    if ($line =~ /^[a-zA-Z-]+$/ && defined $qy_seq) {
      chomp $line;
      $tg_seq = $line;
      unless ($tg_seq =~ /^[acgtnACGTN-]+$/) {
        warn "tg_seq not acgtn only in axt_number $axt_number\n";
      }
    } elsif ($line =~ /^[a-zA-Z-]+$/) {
      chomp $line;
      $qy_seq = $line;
      unless ($qy_seq =~ /^[acgtnACGTN-]+$/) {
        warn "qy_seq not acgtn only in axt_number $axt_number\n";
      }
    }
    
    if ($line =~ /^$/) {
      
      my $identity = identity($qy_seq,$tg_seq);
      unless (length($qy_seq) == length($qy_seq)) {
        warn "qy_seq and tg_seq lenght are different in axt_number $axt_number\n";
        undef $qy_seq;
        undef $tg_seq;
        undef $tg_slice;
        next;
      }
      my $length = length($qy_seq);
      
      unless (defined $tg_dnafrags{$tg_chr}) {
        $tg_dnafrags{$tg_chr} = $dfa->fetch_all_by_GenomeDB_region($tg_gdb,$tg_slice->coord_system->name,$tg_slice->seq_region_name)->[0];
      }
      my $tg_dnafrag = $tg_dnafrags{$tg_chr};

      my $qga = new Bio::EnsEMBL::Compara::GenomicAlign;
      $qga->dnafrag($qy_dnafrag);
      $qga->dnafrag_start($qy_start);
      $qga->dnafrag_end($qy_end);
      $qga->dnafrag_strand(1);
      $qga->aligned_sequence($qy_seq);
      $qga->level_id(0);

      my $tga = new Bio::EnsEMBL::Compara::GenomicAlign;
      $tga->dnafrag($tg_dnafrag);
      $tga->dnafrag_start($tg_start);
      $tga->dnafrag_end($tg_end);
      $tga->dnafrag_strand($tg_strand);
      $tga->aligned_sequence($tg_seq);
      $tga->level_id(0);
      
      my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
      $gab->method_link_species_set($method_link_species_set);
      $gab->score($score);
      $gab->perc_id($identity);
      $gab->length($length);
      $gab->genomic_align_array([$tga, $qga]);
      
      $gaba->store($gab);

      $nb_of_gab_loaded++;

      undef $qy_seq;
      undef $tg_seq;
      undef $tg_slice;
    }
  }
  close AXT;
  return $nb_of_gab_loaded;
}

sub identity {
  my ($seq,$hseq) = @_;
  
  my $length = length($seq);
  
  unless (length($hseq) == $length) {
    warn "reference sequence length ($length bp) and query sequence length (".length($hseq)." bp) should be identical
exit 1\n";
    exit 1;
  }
  
  my @seq_array = split //, $seq;
  my @hseq_array = split //, $hseq;
  my $number_identity = 0;

  for (my $i=0;$i<$length;$i++) {
    if (lc $seq_array[$i] eq lc $hseq_array[$i]) {
      $number_identity++;
    }
  }
  return int($number_identity/$length*100);
}

exit 0;

