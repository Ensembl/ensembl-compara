#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignBlockSet;
use Bio::EnsEMBL::Compara::AlignBlock;
use Bio::EnsEMBL::DnaDnaAlignFeature;

my $host = 'ensrv3.sanger.ac.uk';
my $dbname = 'homo_sapiens_core_4_28';
my $dbuser = 'ensro';
my $dbpass = "";

&GetOptions('h=s' => \$host,
	    'd=s' => \$dbname,
	    'u=s' => \$dbuser);

$| = 1;

my $human_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
						   -user => $dbuser,
						   -dbname => $dbname);
$host = 'ecs1f.sanger.ac.uk';
$dbname = 'alistair_mouse_si_Nov01';
$dbuser = 'ensro';
$dbpass = "";

my $mouse_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
						   -user => $dbuser,
						   -dbname => $dbname);

$host = 'ecs1b.sanger.ac.uk';
$dbname = 'abel_test4';
$dbuser = 'ensro';
$dbpass = "";

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
							     -dbname => $dbname,
							     -user => $dbuser,
							     -pass => $dbpass);
my $ga = $compara_db->get_GenomicAlignAdaptor();

my @HSP_with_chromosome_and_raw_contig_coordinates;

foreach my $gid ($ga->list_align_ids()) {
#  next if ($gid != 491);
  
  my $galn = new Bio::EnsEMBL::Compara::GenomicAlign(-align_id => $gid,
						     -adaptor => $ga);
  my ($score,$perc_id);
  
  foreach my $abs ($galn->each_AlignBlockSet) {
    foreach my $ab ($abs->get_AlignBlocks) {
      if (defined $score &&
	  defined $perc_id) {
	next if ($ab->score < $score ||
		 $ab->perc_id < $perc_id);
      }

# getting the AlignBlock as a DnaDnaAlignFeature object
      my $DnaDnaAlignFeature = $ab->return_DnaDnaAlignFeature($galn->align_name);
      my $human_contig = $human_db->get_Contig($DnaDnaAlignFeature->seqname);
      my $mouse_contig = $mouse_db->get_Contig($DnaDnaAlignFeature->hseqname);

# clean HSP outside of human static golden path
      $DnaDnaAlignFeature = $DnaDnaAlignFeature->restrict_between_positions($human_contig->static_golden_start,$human_contig->static_golden_end,'seqname');
      next unless (defined $DnaDnaAlignFeature);
# clean HSP outside of mouse static golden path
      $DnaDnaAlignFeature = $DnaDnaAlignFeature->restrict_between_positions($mouse_contig->static_golden_start,$mouse_contig->static_golden_end,'hseqname');
      next unless (defined $DnaDnaAlignFeature);
      
      my ($chr_start,$chr_end,$chr_strand,$chr_hstart,$chr_hend,$chr_hstrand);
      ($chr_start,$chr_strand) = $human_contig->chromosome_position($DnaDnaAlignFeature->start,$DnaDnaAlignFeature->strand);
      ($chr_end,$chr_strand) = $human_contig->chromosome_position($DnaDnaAlignFeature->end,$DnaDnaAlignFeature->strand);
      ($chr_hstart,$chr_hstrand) = $mouse_contig->chromosome_position($DnaDnaAlignFeature->hstart,$DnaDnaAlignFeature->hstrand);
      ($chr_hend,$chr_hstrand) = $mouse_contig->chromosome_position($DnaDnaAlignFeature->hend,$DnaDnaAlignFeature->hstrand);

      my $cigar_string = $DnaDnaAlignFeature->cigar_string;
      if ($human_contig->static_golden_ori == -1) {
	$cigar_string =~ s/([IDM])/$1:/g;
	my @tmp = split ":",$cigar_string;
	my $cigar_string = "";
	foreach my $tmp (@tmp) {
	  $cigar_string = $tmp.$cigar_string;
	}
      }

      push @HSP_with_chromosome_and_raw_contig_coordinates,[$human_contig->chromosome,$chr_start,$chr_end,$chr_strand,$mouse_contig->chromosome,$chr_hstart,$chr_hend,$chr_hstrand,$DnaDnaAlignFeature,$cigar_string]

#      print $human_contig->chromosome," ",$chr_start," ",$chr_end," ",$chr_strand," ",$mouse_contig->chromosome," ",$chr_hstart," ",$chr_hend," ",$chr_hstrand," ",$DnaDnaAlignFeature->score," ",$DnaDnaAlignFeature->percent_id,"\n";
      
    }
  }
#  last;
}
#exit;
@HSP_with_chromosome_and_raw_contig_coordinates = sort {
  $a->[0]<=>$b->[0] ||
    $a->[1]<=>$b->[1] ||
      $a->[2]<=>$b->[2]
} @HSP_with_chromosome_and_raw_contig_coordinates;

my @new_HSP_with_chromosome_and_raw_contig_coordinates;
my $current_chromosome;
my @overlapping_HSPs;

print "size before: ",scalar @HSP_with_chromosome_and_raw_contig_coordinates,"\n";

foreach my $HSP (@HSP_with_chromosome_and_raw_contig_coordinates) {
#  print $HSP->[0]," ",$HSP->[1]," ",$HSP->[2]," ",$HSP->[3]," ",$HSP->[4]," ",$HSP->[5]," ",$HSP->[6]," ",$HSP->[7]," ",$HSP->[8]->score," ",$HSP->[8]->percent_id,"\n";
  if (defined $current_chromosome) {
#    print "OK2: $current_chromosome\n";
    if ($current_chromosome == $HSP->[0]) {
#      print "OK3: $current_chromosome\n";
      if (($HSP->[1] >= $overlapping_HSPs[-1]->[1] && $HSP->[1] <= $overlapping_HSPs[-1]->[2]) ||
	  ($HSP->[2] >= $overlapping_HSPs[-1]->[1] && $HSP->[2] <= $overlapping_HSPs[-1]->[2])) {
	push @overlapping_HSPs,$HSP;
      } else {
#      print "OK4: $current_chromosome\n";
	push @new_HSP_with_chromosome_and_raw_contig_coordinates, return_best_HSP(\@overlapping_HSPs);
	@overlapping_HSPs = ($HSP);
      }
    } else {
      push @new_HSP_with_chromosome_and_raw_contig_coordinates, return_best_HSP(\@overlapping_HSPs);
      $current_chromosome = $HSP->[0];
      @overlapping_HSPs = ($HSP);
    }
  } else {
    $current_chromosome = $HSP->[0];
    push @overlapping_HSPs,$HSP;
#    print "OK1: $current_chromosome\n";
  }
}

push @new_HSP_with_chromosome_and_raw_contig_coordinates, return_best_HSP(\@overlapping_HSPs);


sub return_best_HSP ($) {
  my ($overlapping_HSPs_aref) = @_;
  my $best_HSP;
  
  foreach my $HSP (@{$overlapping_HSPs_aref}) {
    if (defined $best_HSP) {
      if ($HSP->[8]->score*$HSP->[8]->percent_id > $best_HSP->[8]->score*$best_HSP->[8]->percent_id) {
	$best_HSP = $HSP;
      } elsif ($HSP->[8]->score*$HSP->[8]->percent_id == $best_HSP->[8]->score*$best_HSP->[8]->percent_id) {
	if ($HSP->[2] - $HSP->[1] > $best_HSP->[2] - $best_HSP->[1]) {
	  $best_HSP = $HSP;
	}
      }
    } else {
      $best_HSP = $HSP;
    }
  }
#  print "ok: ",$best_HSP,"\n";
  return $best_HSP;
}

print "size after: ",scalar @new_HSP_with_chromosome_and_raw_contig_coordinates,"\n";

foreach my $HSP (@new_HSP_with_chromosome_and_raw_contig_coordinates) {
  print $HSP->[0]," ",$HSP->[1]," ",$HSP->[2]," ",$HSP->[3]," ",$HSP->[4]," ",$HSP->[5]," ",$HSP->[6]," ",$HSP->[7]," ",$HSP->[9]," ",$HSP->[8]->seqname," ",$HSP->[8]->start," ",$HSP->[8]->end," ",$HSP->[8]->strand," ",$HSP->[8]->hseqname," ",$HSP->[8]->hstart," ",$HSP->[8]->hend," ",$HSP->[8]->hstrand," ",$HSP->[8]->score," ",$HSP->[8]->percent_id," ",$HSP->[8]->cigar_string,"\n";
}
		     
