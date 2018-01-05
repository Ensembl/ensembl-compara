#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.




####Nb just dumps chr fragments, including whole chromosomes, but doesn't load into compara database -- has advantage of not needing compara details
use strict;
use warnings;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;
use Bio::PrimarySeq;
use Getopt::Long;

my $usage = "
DumpChromosomeFragments.pl 
            -dbname homo_sapiens_core_10_30 or alias
            -chr_names \"22\"
            -chr_start 1
            -chr_end 1000000
            -overlap 0
            -chunk_size 60000
            -masked 0
            -phusion Hs
            -mask_restriction RepeatMaksingRestriction.conf
            -o output_filename
            -coord_system coordinate system (default=chromosome)
            -top_level
            -conf Registry.conf

$0 [-help]
   -dbname core_database_name (or alias)
   -chr_names \"20,21,22\" (default = \"all\")
   -chr_start position on chromosome from dump start (default = 1)
   -chr_end position on chromosome to dump end (default = chromosome length)
   -chunk_size bp size of the sequence fragments dumped (default = 60000)
   -overlap overlap between chunk fragments (default = 0)
   -masked status of the sequence 0 unmasked (default)
                                  1 masked
                                  2 soft-masked
   -phusion \"Hs\" tag put in the FASTA header >Hs22.1 
   -mask_restriction RepeatMaksingRestriction.conf
       Allow you to do hard and soft masking at the same time depending on
       the repeat class or name. See RepeatMaksingRestriction.conf.example,
       and the get_repeatmasked_seq method in Bio::EnsEMBL::Slice
   -o output_filename
   -conf Registry.conf
   -coord_system coordinate system (default=chromosome, but must be all of
       same type-->2 dumps for danio and can't use all for them )
   -top_level
       Default: all. Restricts dump to seq_regions which are 'top_level'.
       This works with -coord_system option only.


";

$| = 1;

my $dbname;
my $chr_names = "all";
my $chr_start;
my $chr_end;
my $overlap = 0;
my $chunk_size = 60000;
my $masked = 0;
my $phusion;
my $output;
my $help = 0;
my $mask_restriction_file;
my $coordinate_system="chromosome";
my $top_level = 0;
my $conf;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'chr_names=s' => \$chr_names,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'overlap=i' => \$overlap,
	   'chunk_size=i' => \$chunk_size,
	   'masked=i' => \$masked,
           'mask_restriction=s' => \$mask_restriction_file,
	   'phusion=s' => \$phusion,
	   'coord_system=s' => \$coordinate_system,
	   'top_level' => \$top_level,
	   'conf=s'	=> \$conf,
	   'o=s' => \$output);

if ($help) {
  print $usage;
  exit 0;
}

# Some checks on arguments

unless ($dbname) {
  warn "dbname or alias must be specified
exit 1\n";
  exit 1;
}
my $db = "Bio::EnsEMBL::Registry";

  $db->load_all($conf);


my %not_default_masking_cases;
if (defined $mask_restriction_file) {
  %not_default_masking_cases = %{do $mask_restriction_file};
}
my $slice_adaptor = $db->get_adaptor($dbname, 'core', 'Slice') or die "can't get Adaptor for $dbname, 'core', 'Slice'\n";

my $chromosomes;

if (defined $chr_names and $chr_names ne "all") {
  my @chr_names = split /,/, $chr_names;
  foreach my $chr_name (@chr_names) {
    print STDERR "chr_name=$chr_name\n";
    push @{$chromosomes}, $slice_adaptor->fetch_by_region($coordinate_system , $chr_name);
  }
} else {
  if($coordinate_system){
    if ($top_level) {
      $chromosomes = [grep {@{$_->get_all_Attributes('toplevel')}} @{$slice_adaptor->fetch_all($coordinate_system)}];
    } else {
      $chromosomes = $slice_adaptor->fetch_all($coordinate_system);
    }
  } else {
    $chromosomes = $slice_adaptor->fetch_all('toplevel');
  }
}
 
if (scalar @{$chromosomes} > 1 && 
    (defined $chr_start || defined $chr_end)) {
  warn "When more than one chr_name is specified chr_start and chr_end must not be specified
exit 1\n";
  exit 1;
}

unless ($chr_start) {
  warn "WARNING : setting chr_start=1\n";
  $chr_start = 1;
}
if ($chr_start <= 0) {
  warn "WARNING : chr_start <= 0, setting chr_start=1\n";
  $chr_start = 1;
}

if (defined $chr_end && $chr_end < $chr_start) {
  warn "chr_end $chr_end should be >= chr_start $chr_start
exit 2\n";
  exit 2;
}
  
my $fh = \*STDOUT;
if (defined $output) {
  open F, ">$output";
  $fh = \*F;
}    
my $output_seq = Bio::SeqIO->new( -fh => $fh, -format => 'Fasta');

foreach my $chr (@{$chromosomes}) {
  print STDERR "fetching slice...\n";
 
  # futher checks on arguments

  if ($chr_start > $chr->length) {
    warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 3\n";
    exit 3;
  }
  unless (defined $chr_end) {
    warn "WARNING : setting chr_end=chr_length ".$chr->length."\n";
    $chr_end = $chr->length;
  }
  if ($chr_end > $chr->length) {
    warn "WARNING : chr_end $chr_end larger than chr_length ".$chr->length."
setting chr_end=chr_length\n";
    $chr_end = $chr->length;
  }
  
  my $slice;
  if ($chr_start && $chr_end) {
    $slice = $slice_adaptor->fetch_by_region($coordinate_system, $chr->seq_region_name,$chr_start,$chr_end) or die "$coordinate_system, ".$chr->seq_region_name.",$chr_start,$chr_end\n";
  } else {
    $slice = $slice_adaptor->fetch_by_region($coordinate_system, $chr->seq_region_name);
  }
  
  print STDERR "..fetched slice for $coordinate_system ",$slice->seq_region_name," from position ",$slice->start," to position ",$slice->end,"\n";

  printout_by_overlapping_chunks($slice,$overlap,$chunk_size,$output_seq);
  
  $chr_end = undef;
}

close $fh;

sub printout_by_overlapping_chunks {
  my ($slice,$overlap,$chunk_size,$output_seq) = @_;
  my $this_slice;

  if ($masked == 1) {

    print STDERR "getting masked sequence...\n";
    if (%not_default_masking_cases) {
      $this_slice = $slice->get_repeatmasked_seq(undef,0,\%not_default_masking_cases);
    } else {
      $this_slice = $slice->get_repeatmasked_seq;
    }
    $this_slice->name($slice->seq_region_name);
    print STDERR "...got masked sequence\n";

  } elsif ($masked == 2) {

    print STDERR "getting soft masked sequence...\n";
    if (%not_default_masking_cases) {
      $this_slice = $slice->get_repeatmasked_seq(undef,1,\%not_default_masking_cases);
    } else {
      $this_slice = $slice->get_repeatmasked_seq(undef,1);
    }
    $this_slice->name($slice->seq_region_name);
    print STDERR "...got soft masked sequence\n";

  } else {

    print STDERR "getting unmasked sequence...\n";
    $this_slice = Bio::PrimarySeq->new( -id => $slice->seq_region_name, -seq => $slice->seq);
    print STDERR "...got unmasked sequence\n";

  }

  print STDERR "sequence length : ",$this_slice->length,"\n";
  print STDERR "printing out the sequences chunks...";

  for (my $i=1;$i<=$this_slice->length;$i=$i+$chunk_size-$overlap) {

    my $chunk;
    if ($i+$chunk_size-1 > $this_slice->length) {
      
      ## This is the last bit we have to dump
      my $chr_start = $i+$slice->start-1;
      my $id;
      if (defined $phusion) {
        $id = $phusion.".".$coordinate_system.":".$slice->seq_region_name.".".$chr_start;
      } else {
        $id = $coordinate_system.":".$slice->seq_region_name.".".$chr_start.".".$slice->end;
      }
      ## Uses sub_Slice and not the subseq method of the original slice as the subseq
      ## is fetching the RepeatFeautes for the whole slice every time.
      my $sub_slice = $this_slice->sub_Slice($i,$this_slice->length);
      $chunk = Bio::PrimarySeq->new (
              -seq => $sub_slice->seq,
              -id  => $id,
              -moltype => 'dna'
          );

    } else {

      my $chr_start = $i+$slice->start-1;
      my $id;
      if (defined $phusion) {
        $id = $phusion.".".$coordinate_system.":".$slice->seq_region_name.".".$chr_start;
      } else {
        $id = $coordinate_system . ":" . 
          $slice->seq_region_name . "." . 
            $chr_start . "." . 
              ($chr_start + $chunk_size - 1);
      }
      ## Uses sub_Slice and not the subseq method of the original slice as the subseq
      ## is fetching the RepeatFeautes for the whole slice every time.
      my $sub_slice = $this_slice->sub_Slice($i,$i+$chunk_size-1);
      $chunk = Bio::PrimarySeq->new (
              -seq => $sub_slice->seq,
              -id  => $id,
              -moltype => 'dna'
          );

    }

    $output_seq->write_seq($chunk);

  }
  print STDERR "Done\n";
}
