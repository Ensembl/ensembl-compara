#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;

my $usage = "
$0
  [--help]                      this menu
   --dbname string              (e.g. compara23) one of the compara database Bio::EnsEMBL::Registry aliases
   --seq_region string          (e.g. 22)
   --seq_region_start integer   (e.g. 50000000)
   --seq_region_end integer     (e.g. 50500000)
   --qy string                  (e.g. human) the query species (i.e. a Bio::EnsEMBL::Registry alias)
                                from which alignments are queried and seq_region refer to
   --tg string                  (e.g. mouse) the target sepcies (i.e. a Bio::EnsEMBL::Registry alias)
                                to which alignments are queried
  [--alignment_type string]     (e.g. TRANSLATED_BLAT) type of alignment stored (default: BLASTZ_NET)
  [--tsl]                       print out a translated alignment
  [--oo]                        By default, the alignments are dumped so that the --qy species sequence is 
                                always on forward strand. --oo is mostly useful in association with -tsl 
                                option, when a full translated alignment program has been used e.g 
                                TRANSLATED_BLAT, and allow to obtain the right translation phase. So the --qy
                                species sequence might be reverse complemented.
  [--ft string]                 alignment format, available in bioperl Bio::AlignIO (default: clustalw)
                                Also available are gaf and axtplus.
  [--uc]                        print out sequence in upper cases (default is lower cases)
  [--limit integer]             (e.g. 2) limit the output to the number of alignments specified
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given, 
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
                                ~/.ensembl_init will be used.

gaf alignment format:
--------------------
18 space-separated columns per line. One line per alignments.
Only the first 9 are mandatory and are defined as

qy_seqname qy_start qy_end qy_strand tg_seqname tg_start tg_end tg_strand score

The remaining 9 if empty can be set to a single dot '.' and are defined as

percent_id qy_length tg_length qy_species_name tg_species_name \
alignment_type strands_reversed group_id level_id

An example:

X 50563682 50563753 + scaffold_145 253075 253146 + 39 87 153692391 307110 human fugu TRANSLATED_BLAT 1 247 0
X 50563682 50563753 + scaffold_992 17608 17679 - 36 83 153692391 91569 human fugu TRANSLATED_BLAT 1 3250 0

axtplus alignment format:
------------------------
This is an extension of the axt format, with an extended header and the freedom to have the qy_sequence
in - strand (axt assumes always qy_sequence to be i + strand). As for the axt format, there are 4 lines
per alignment:

header
qy_sequence
tg_sequence
newline

The header is now 12 spaced-separated columns (only 9 in the former axt format)

index qy_seqname qy_start qy_end qy_strand tg_seqname tg_start tg_end tg_strand \
score qy_length tg_length

An example:

0 X 50563682 50563753 + scaffold_145 253075 253146 + 39 153692391 307110
acctacctcaggcttctcccggtgtgtgttcacggcctccacattcaggtggacggactccaccttgcagcc
acccacctccggtctctctctgtgcgtgttgaccgcttccacgttcaggctgattgactccaccttacagcc

1 X 50563682 50563753 + scaffold_992 73891 73962 - 36 153692391 91569
acctacctcaggcttctcccggtgtgtgttcacggcctccacattcaggtggacggactccaccttgcagcc
acctacctctggtctgtctctgtgagtgtttacagcctccacgttgaggaagacggactcgactctgcaacc

and with the -oo option, you can obtain

0 X 103128639 103128710 - scaffold_145 53965 54036 - 39 153692391 307110
ggctgcaaggtggagtccgtccacctgaatgtggaggccgtgaacacacaccgggagaagcctgaggtaggt
ggctgtaaggtggagtcaatcagcctgaacgtggaagcggtcaacacgcacagagagagaccggaggtgggt

1 X 103128639 103128710 - scaffold_992 17608 17679 + 36 153692391 91569
ggctgcaaggtggagtccgtccacctgaatgtggaggccgtgaacacacaccgggagaagcctgaggtaggt
ggttgcagagtcgagtccgtcttcctcaacgtggaggctgtaaacactcacagagacagaccagaggtaggt

\n";

my $dbname;
my ($seq_region,$seq_region_start,$seq_region_end);
my ($qy_species,$tg_species);
my $help = 0;
my $alignment_type = "BLASTZ_NET";
my $limit;
my $reg_conf;
my $format = "clustalw";
my $translated = 0;
my $uc = 0;
my $original_orientation = 0;

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'seq_region=s' => \$seq_region,
	   'seq_region_start=i' => \$seq_region_start,
	   'seq_region_end=i' => \$seq_region_end,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species,
	   'alignment_type=s' => \$alignment_type,
           'tsl' => \$translated,
           'ft=s' => \$format,
           'uc' => \$uc,
           'oo' => \$original_orientation,
           'limit=i' => \$limit,
           'reg_conf=s' => \$reg_conf);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

$format = lc $format;

if ($original_orientation && $format eq "axt") {
  warn("
WARNING: The axt format assumes that the query is always + strand, so -oo option does not applied here.
Use the axtplus format instead
\n");
  $original_orientation = 0;
}

my $qy_sa = Bio::EnsEMBL::Registry->get_adaptor($qy_species,'core','Slice');
throw "Cannot get adaptor for ($qy_species,'core','Slice')" if (!$qy_sa);

my $qy_slice = $qy_sa->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);

my $tg_binomial = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','MetaContainer')->get_Species->binomial;

my $dafad = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','DnaAlignFeature');

my $DnaDnaAlignFeatures = $dafad->fetch_all_by_Slice($qy_slice,$tg_binomial,undef,$alignment_type,$limit);

my $index = 0;

foreach my $ddaf (@{$DnaDnaAlignFeatures}) {
  
  if ($ddaf->cigar_string eq "") {
    warn $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," has no cigar line";
    next;
  }

  if ($original_orientation && $ddaf->strands_reversed) {
    $ddaf->reverse_complement;
  }
    
  if ($format eq "axt") {
    print_out_axt($ddaf,$index);
    $index++;
  } elsif ($format eq "axtplus") {
    print_out_axtplus($ddaf,$index);
    $index++;
  } elsif ($format eq "gaf") {
    print_out_gaf($ddaf);
  } else {
    my $sa;
    my @flags;
    push @flags, 'translated' if ($translated);
    push @flags, 'uc' if ($uc);
    
    $sa = $ddaf->get_SimpleAlign(@flags);
    
    my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                      -fh => \*STDOUT,
                                      -format => $format,
                                      -idlength => 20);
    print $alignIO $sa;
  }
}

sub print_out_axt {
  my $ddaf = shift;
  my $index = shift;

  $ddaf->reverse_complement if ($ddaf->strand < 0);

  print $index . " " .
    $ddaf->seqname . " " .
      $ddaf->seq_region_start . " " .
        $ddaf->seq_region_end . " " .
          $ddaf->hseqname . " ";

  my ($hstart, $hend, $hstrand);
  if ($ddaf->hstrand < 0)  {
    $hstrand = "-";
    $hstart = $ddaf->hslice->seq_region_length - $ddaf->hseq_region_end + 1;
    $hend = $ddaf->hslice->seq_region_length - $ddaf->hseq_region_start + 1;
  } else {
    $hstrand = "+";
    $hstart = $ddaf->hseq_region_start;
    $hend = $ddaf->hseq_region_end;
  }

  print $hstart . " " .
    $hend . " " .
      $hstrand . " " .
        $ddaf->score,"\n";

  my ($sb_seq,$qy_seq) = @{$ddaf->alignment_strings};

  my $loc_sb_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $sb_seq : lc $sb_seq,
                                          -START  => $ddaf->seq_region_start,
                                          -END    => $ddaf->seq_region_end,
                                          -ID     => $ddaf->seqname,
                                          -STRAND => $ddaf->strand);

  $loc_sb_seq->seq($uc ? uc $loc_sb_seq->translate->seq
                   : lc $loc_sb_seq->translate->seq) if ($translated);

  my $loc_qy_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $qy_seq : lc $qy_seq,
                                          -START  => $ddaf->hseq_region_start,
                                          -END    => $ddaf->hseq_region_end,
                                          -ID     => $ddaf->hseqname,
                                          -STRAND => $ddaf->hstrand);

  $loc_qy_seq->seq($uc ? uc  $loc_qy_seq->translate->seq
                   : lc $loc_qy_seq->translate->seq) if ($translated);
  
  print $loc_sb_seq->seq,"\n";
  print $loc_qy_seq->seq,"\n";
  print "\n";
}

sub print_out_gaf {
  my $ddaf = shift;
  my $strand = "+";
  my $hstrand = "+";
  $strand = "-" if ($ddaf->strand < 0);
  $hstrand = "-" if ($ddaf->hstrand < 0);
  

  print $ddaf->seqname . " " .
    $ddaf->seq_region_start . " " .
      $ddaf->seq_region_end . " " .
        $strand . " " .
          $ddaf->hseqname . " " .
            $ddaf->hseq_region_start . " " .
              $ddaf->hseq_region_end . " " .
                $hstrand . " " .
                  $ddaf->score . " ".
                    $ddaf->percent_id . " " .
                      $ddaf->slice->seq_region_length . " " .
                        $ddaf->hslice->seq_region_length . " " .
                          $qy_species . " " .
                            $tg_species . " " .
                              $alignment_type . " " .
                                $ddaf->strands_reversed . " " .
                                  $ddaf->group_id . " " .
                                    $ddaf->level_id . "\n";
  
}

sub print_out_axtplus {
  my $ddaf = shift;
  my $index = shift;

  my ($start, $end, $strand);
  if ($ddaf->strand < 0)  {
    $strand = "-";
    $start = $ddaf->slice->seq_region_length - $ddaf->seq_region_end + 1;
    $end = $ddaf->slice->seq_region_length - $ddaf->seq_region_start + 1;
  } else {
    $strand = "+";
    $start = $ddaf->seq_region_start;
    $end = $ddaf->seq_region_end;
  }

  my ($hstart, $hend, $hstrand);
  if ($ddaf->hstrand < 0)  {
    $hstrand = "-";
    $hstart = $ddaf->hslice->seq_region_length - $ddaf->hseq_region_end + 1;
    $hend = $ddaf->hslice->seq_region_length - $ddaf->hseq_region_start + 1;
  } else {
    $hstrand = "+";
    $hstart = $ddaf->hseq_region_start;
    $hend = $ddaf->hseq_region_end;
  }

  print $index . " " .
    $ddaf->seqname . " " .
      $start . " " .
        $end . " "  .
          $strand . " " .
            $ddaf->hseqname . " " .
              $hstart . " " .
                $hend . " " .
                  $hstrand . " " .
                    $ddaf->score . " " .
                      $ddaf->slice->seq_region_length . " " .
                        $ddaf->hslice->seq_region_length . "\n";
  
  my ($sb_seq,$qy_seq) = @{$ddaf->alignment_strings};

  my $loc_sb_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $sb_seq : lc $sb_seq,
                                          -START  => $ddaf->seq_region_start,
                                          -END    => $ddaf->seq_region_end,
                                          -ID     => $ddaf->seqname,
                                          -STRAND => $ddaf->strand);

  $loc_sb_seq->seq($uc ? uc $loc_sb_seq->translate->seq
                   : lc $loc_sb_seq->translate->seq) if ($translated);

  my $loc_qy_seq = Bio::LocatableSeq->new(-SEQ    => $uc ? uc $qy_seq : lc $qy_seq,
                                          -START  => $ddaf->hseq_region_start,
                                          -END    => $ddaf->hseq_region_end,
                                          -ID     => $ddaf->hseqname,
                                          -STRAND => $ddaf->hstrand);

  $loc_qy_seq->seq($uc ? uc  $loc_qy_seq->translate->seq
                   : lc $loc_qy_seq->translate->seq) if ($translated);
  
  print $loc_sb_seq->seq,"\n";
  print $loc_qy_seq->seq,"\n";
  print "\n";
}

exit 0;
