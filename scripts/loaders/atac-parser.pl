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


use strict;
use warnings;

use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

my %genomic_aligns;
my %genomic_align_blocks;
my %r_components;
my %r_overall;

my $atac_in;
my $reg_conf;
my $mlss_id;
my $r_gdbid;
my $q_gdbid;
my $starting_group_id;
my $nodb;
my $logfile;
my $help;

GetOptions("atac=s" => \$atac_in,
	   "reg-conf=s" => \$reg_conf,
	   "mlss=i" => \$mlss_id,
	   "r-gdb-id=i" => \$r_gdbid,
	   "q-gdb-id=i" => \$q_gdbid,
	   "starting-group-id=i" => \$starting_group_id,
	   "nodb" => \$nodb,
	   "logfile=s" => \$logfile,
	   "help" => \$help);

if ($help || !$atac_in || !$reg_conf || 
    !$mlss_id || !$r_gdbid || !$q_gdbid || !$starting_group_id) {
  die usage();
}

open ATAC, $atac_in or die "couldn't open ATAC file $atac_in $!\n";
if ($logfile) {
  open LOGFILE, ">$logfile" or die "couldn't open logfile $logfile $!\n";
  select((select(LOGFILE), $| = 1)[0]); #make LOGFILE unbuffered (a.k.a. "hot").
  #See http://perl.plover.com/FAQs/Buffering.html
}

print LOGFILE "setting up adaptors\n" if $logfile;
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_all($reg_conf);
my $dfa = $reg->get_adaptor("Multi", "compara", "DnaFrag");
my $gaa = $reg->get_adaptor("Multi", "compara", "GenomicAlign");
my $gaba = $reg->get_adaptor("Multi", "compara", "GenomicAlignBlock");
my $mlssa = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

my $mlss_o = $mlssa->fetch_by_dbID($mlss_id);
print LOGFILE "fetched mlss " . $mlss_o->dbID() . "\n" if $logfile;
validate_mlss_and_species($r_gdbid, $q_gdbid, $mlss_o) or 
  die "mlss $mlss_id does not link genome_dbs $r_gdbid and $q_gdbid $!\n";
my $next_ga_id = ($mlss_id * 10**10) + 1;
my $next_gab_id = $next_ga_id;
print LOGFILE "starting genomic align [block] ID will be $next_ga_id\n";

print LOGFILE "starting to read atac file\n" if $logfile;
my $atac_lines = 1;
while (<ATAC>) {
  next unless (/^M/);
  chomp;
  my @line = split;

  #ATAC coords are 0 based.
  if ($line[1] eq 'u') {
    my $ungapped_hit = {'r_id' => $line[4],
			'r_start' => $line[5] + 1,
			'r_length' => $line[6],
			'r_strand' => $line[7],
			'q_id' => $line[8],
			'q_start' => $line[9] + 1,
			'q_length' => $line[10],
			'q_strand' => $line[11]};
    push(@{$r_components{$line[3]}}, $ungapped_hit);
    if ($logfile && (($atac_lines % 10000) == 0)) {
      print LOGFILE "read $atac_lines atac lines\n";
    }
    $atac_lines++;
  } elsif ($line[1] eq 'r') {
    $r_overall{$line[2]} = {'r_id' => $line[4],
			    'r_start' => $line[5] + 1,
			    'r_length' => $line[6],
			    'r_strand' => $line[7],
			    'q_id' => $line[8],
			    'q_start' => $line[9] + 1,
			    'q_length' => $line[10],
			    'q_strand' => $line[11]};
    if ($logfile && (($atac_lines % 10000) == 0)) {
      print LOGFILE "read $atac_lines atac lines\n";
    }
    $atac_lines++;
  } else {
    next;
  }
}

print LOGFILE "processing hsps\n" if $logfile;

my $group_id = $starting_group_id;
foreach my $run_id (keys(%r_components)) {
  my $ref_dnafrag = $dfa->fetch_by_GenomeDB_and_name($r_gdbid,
						     $r_overall{$run_id}->{r_id});
  my $query_dnafrag = $dfa->fetch_by_GenomeDB_and_name($q_gdbid,
						       $r_overall{$run_id}->{q_id});

  die "could not find ref dnafrag for " . $r_overall{$run_id}->{r_id} . "\n" unless $ref_dnafrag;
  die "could not find query dnafrag for " . $r_overall{$run_id}->{q_id} . "\n" unless $query_dnafrag;
  my @run_components = @{$r_components{$run_id}};

  @run_components = sort {$a->{'r_start'} <=> $b->{'r_start'}} @run_components;
  
  foreach my $run_component (@run_components) {
    my $ref_ga = new Bio::EnsEMBL::Compara::GenomicAlign
      (-adaptor => $gaa,
       -method_link_species_set => $mlss_o,
       -dnafrag => $ref_dnafrag,
       -dnafrag_start => $run_component->{r_start},
       -dnafrag_end => $run_component->{r_start} + ($run_component->{r_length} - 1),
       -dnafrag_strand => $run_component->{r_strand},
       -cigar_line => $run_component->{r_length} . "M",
       -dbID => $next_ga_id,
       -visible => 1);
    $next_ga_id++;

    my $query_ga = new Bio::EnsEMBL::Compara::GenomicAlign
      (-adaptor => $gaa,
       -method_link_species_set => $mlss_o,
       -dnafrag => $query_dnafrag,
       -dnafrag_start => $run_component->{q_start},
       -dnafrag_end => $run_component->{q_start} + ($run_component->{q_length} - 1),
       -dnafrag_strand => $run_component->{q_strand},
       -cigar_line => $run_component->{q_length} . "M",
       -dbID => $next_ga_id,
       -visible => 1);
    $next_ga_id++;

    my $new_gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock
      (-adaptor => $gaba,
       -method_link_species_set => $mlss_o,
       -length => $run_component->{q_length},
       -genomic_align_array => [$ref_ga, $query_ga],
       -group_id => $group_id,
       -dbID => $next_gab_id
      ); 
    $next_gab_id++;
    $gaba->store($new_gab) unless $nodb;
  }

  if ($logfile) {
    if ((($group_id - $starting_group_id + 1) % 1000) == 0) {
      print LOGFILE "processed " . ($group_id - $starting_group_id + 1) . " hsps\n";
    }
  }
  $group_id++;
}

sub validate_mlss_and_species {
  my ($r_gdbid, $q_gdbid, $mlss_o) = @_;
  my @given_gdbids = ($r_gdbid, $q_gdbid);
  @given_gdbids = sort {$a <=> $b} @given_gdbids;
  my $ss_gdbs = $mlss_o->species_set()->genome_dbs();
  my @ss_gdbids = map {$_->dbID()} @{$ss_gdbs};
  #assume if there is one gdb_id in the species set that this
  #is a triticum self alignment, so duplicate the id
  if (scalar(@ss_gdbids) == 1) {
    push(@ss_gdbids, $ss_gdbids[0]);
  }
  @ss_gdbids = sort {$a <=> $b} @ss_gdbids;
  return ((join(",", @given_gdbids)) eq (join(",", @ss_gdbids)));
}

sub usage {
  my $usagestr = <<'END_USAGE';
usage: atac-parser.pl [options]
required options:
  --atac filename            file containing ATAC output
  --reg-conf reg_conf_file   registry file pointing to the compara database to load to
  --r-gdb-id genome_db_id    genome_db_id of reference genome (second set of columns in standard ATAC output)
  --q-gdb-id genome_db_id    genome_db_id of query genome (first set of columns in standard ATAC output)
  --mlss mlss_id             mlss_id for storing alignments
  --starting-group-id int    new group_id number to start with (for genomic_align_blocks)
optional options:
  --logfile filename         log of script progress
  --nodb                     if set, do not write to database
END_USAGE
  print STDERR "$usagestr\n";
}
