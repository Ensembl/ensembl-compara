#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;

$| = 1;

my $help = 0;
my $glob = 50;
my $min_size = 30;
my $mouse_super_contig_size = 5000000;

my $static_mouse_file = "/nfs/acari/abel/work/mouse_human/mouse_1_static_raw_contigs";
my $human_golden_contig = "/nfs/acari/abel/work/mouse_human/human_golden_contigs_28";
my $mouse_ending_chr_name_contigs ="/nfs/acari/abel/work/mouse_human/mouse_1_ending_chr_name_contigs";
my $mouse_static_super_contigs = "/nfs/acari/abel/work/mouse_human/mouse_1_static_super_contigs";

GetOptions('help' => \$help,
	   'glob=i' => \$glob,
	   'min_size=i' => \$min_size,
	   'mscs=i' => \$mouse_super_contig_size,
	   'smf=s' => \$static_mouse_file,
	   'hgc=s' => \$human_golden_contig,
	   'mecnc=s' => \$mouse_ending_chr_name_contigs,
	   'mssc:s' => \$mouse_static_super_contigs);

open(MS,$static_mouse_file) || die "Could not open $static_mouse_file; $!\n";

my %mouse_golden_contigs;

while (<MS>) {
    my ($id,$chr,$start,$end,$raw_start,$raw_end,$raw_ori) = split;
    next if ($chr =~ /^NA.*$/);
    my $h = {};
    #print STDERR "Storing $chr,$start,$end for $id\n";
    $h->{'chr'} = $chr;
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw_start'} = $raw_start;
    $h->{'raw_end'} = $raw_end;
    $h->{'raw_ori'} = $raw_ori;
    $mouse_golden_contigs{$id} = $h;
}

close MS;

open(HS,$human_golden_contig) || die "Could not open $human_golden_contig; $!\n";

my %human_golden_contigs;

while (<HS>) {
    my ($id,$chr,$start,$end,$raw_start,$raw_end,$raw_ori) = split;
    my $h = {};
    #print STDERR "Storing $chr,$start,$end for $id\n";
    $h->{'chr'} = $chr;
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw_start'} = $raw_start;
    $h->{'raw_end'} = $raw_end;
    $h->{'raw_ori'} = $raw_ori;
    $human_golden_contigs{$id} = $h;
}

close HS;

open(ENDING,$mouse_ending_chr_name_contigs) || die "Could not open $mouse_ending_chr_name_contigs; $!\n"; 

my %mouse_ending_contigs;

while (<ENDING>) {
  my ($chr,$ending_start,$ending_end) = split;
  $mouse_ending_contigs{$chr}{'start'} = $ending_start;
  $mouse_ending_contigs{$chr}{'end'} = $ending_end;
}

close ENDING;

open(MOUSE_STATIC_SUPER_CONTIGS,$mouse_static_super_contigs) || die "$mouse_static_super_contigs; $!\n";

my %mouse_static_super_contigs;

while (<MOUSE_STATIC_SUPER_CONTIGS>) {
  my ($super_contig) = split;
  $mouse_static_super_contigs{$super_contig} = 1;
}

close MOUSE_STATIC_SUPER_CONTIGS;

#foreach my $contig (keys %mouse_static_super_contigs) {
#  print $contig,"\n";
#}



my ($current_start,$current_end,$prev_id,$prev_mouse_id,$prev_human_id,$current_m_start,$current_m_end,$current_strand);

while (<>) {
  my ($align_id,$d,$human_id,$start,$end,$mouse_id,$m_start,$m_end,$strand) = split;
  
  # avoid non-golden contigs
  next unless (defined $mouse_golden_contigs{$mouse_id});
  next unless (defined $human_golden_contigs{$human_id});
  
  #print STDERR "Seeing $align_id vs $prev_id $current_end $start\n";
  
  if (! defined $prev_id) {
    
    # first contig
    $current_start = $start;
    $current_end   = $end;
    $prev_id       = $align_id;
    $prev_mouse_id = $mouse_id;
    $prev_human_id = $human_id;
    $current_m_start = $m_start;
    $current_m_end   = $m_end;
    $current_strand  = $strand;
    
  } elsif ($align_id == $prev_id &&
	   ($current_end + $glob) > $start) {
    # join hit separated by less than $glob 
    # globbed. Simply extend end and worry about m_start and m_end
    #print STDERR "globbed out\n";
    
    $current_end = $end;
    if ($m_start < $current_m_start) {
      $current_m_start = $m_start;
    }
    if ($m_end  > $current_m_end) {
      $current_m_end = $m_end;
    }
    
  } else {
    # write the block out
    #print STDERR "Writing out\n";
    # first map mouse to chromosomal coordinates
    
    if ($current_end - $current_start < $min_size ||
	$current_m_end - $current_m_start < $min_size) {
      # protect us against micro-matches... why do we have them?
      $current_start = $start;
      $current_end   = $end;
      $prev_id       = $align_id;
      $prev_mouse_id = $mouse_id;
      $prev_human_id = $human_id;
      $current_m_start = $m_start;
      $current_m_end   = $m_end;
      $current_strand  = $strand;
      next;
    }
    
    # taking $prev_mouse_id and $prev_human_id because they are from these ones we want to dump match information
    # not the $mouse_id and $human_id from the current while (<>) entry !!!

    my $h = $mouse_golden_contigs{$prev_mouse_id};

    my ($chr_start,$chr_end,$chr_strand);
    
    if( $h->{'raw_ori'} == 1 ) {
      $chr_start = $h->{'start'} + $current_m_start - $h->{'raw_start'} +1;
      $chr_end   = $h->{'start'} + $current_m_end - $h->{'raw_start'} +1;
    } else {
      $chr_start = $h->{'start'} + $h->{'raw_end'} - $current_m_end;
      $chr_end   = $h->{'start'} + $h->{'raw_end'} - $current_m_start;
    }
    
    if( $h->{'raw_ori'} == $current_strand ) {
      $chr_strand = 1;
    } else {
      $chr_strand = -1;
    }
    
    # now figure out where this is on denormalised coordinates
    
    my ($de_scontig_id,$de_start) = &map_to_denormalised($h->{'chr'},$chr_start,$mouse_ending_contigs{$h->{'chr'}});
    my ($de_econtig_id,$de_end)   = &map_to_denormalised($h->{'chr'},$chr_end,$mouse_ending_contigs{$h->{'chr'}});
    
    #print STDERR "Got $de_scontig_id vs $de_econtig_id $chr_start $chr_end\n";
    
    # if we cross boundaries - currently skip!
    
    if( $de_scontig_id eq $de_econtig_id ) {
      if (defined $mouse_static_super_contigs{$de_scontig_id}) {
	# dump it
	print "$prev_human_id\t$current_start\t$current_end\t1\t$de_scontig_id\t$de_start\t$de_end\t$chr_strand\t$prev_mouse_id\n";
      } else {
	print STDERR "$prev_human_id\t$current_start\t$current_end\t1\t$de_scontig_id\t$de_start\t$de_end\t$chr_strand\t$prev_mouse_id\n";
      }
    }
    
    # initialization with the current while (<>) entry

    $current_start = $start;
    $current_end   = $end;
    $prev_id       = $align_id;
    $prev_mouse_id = $mouse_id;
    $prev_human_id = $human_id;
    $current_m_start = $m_start;
    $current_m_end   = $m_end;
    $current_strand  = $strand;
  } 
}

# getting out the while (<>), dumping last entry if necessary

unless ($current_end - $current_start < $min_size || 
	$current_m_end - $current_m_start < $min_size) {
  # protect us against micro-matches... why do we have them?
  
  my $h = $mouse_golden_contigs{$prev_mouse_id};

  my ($chr_start,$chr_end,$chr_strand);
  
  if ($h->{'raw_ori'} == 1) {
    $chr_start = $h->{'start'} + $current_m_start - $h->{'raw_start'} + 1;
    $chr_end   = $h->{'start'} + $current_m_end - $h->{'raw_start'} + 1;
  } else {
    $chr_start = $h->{'start'} + $h->{'raw_end'} - $current_m_end;
    $chr_end   = $h->{'start'} + $h->{'raw_end'} - $current_m_start;
  }
  
  if ($h->{'raw_ori'} == $current_strand) {
    $chr_strand = 1;
  } else {
    $chr_strand = -1;
  }
  
  # now figure out where this is on denormalised coordinates
  
  my ($de_scontig_id,$de_start) = &map_to_denormalised($h->{'chr'},$chr_start,$mouse_ending_contigs{$h->{'chr'}});
  my ($de_econtig_id,$de_end)   = &map_to_denormalised($h->{'chr'},$chr_end,$mouse_ending_contigs{$h->{'chr'}});
  
  #print STDERR "Got $de_scontig_id vs $de_econtig_id $chr_start $chr_end\n";
  
  # if we cross boundaries - currently skip!

  if ($de_scontig_id eq $de_econtig_id) {
    if (defined $mouse_static_super_contigs{$de_scontig_id}) {
      # dump it
      print "$prev_human_id\t$current_start\t$current_end\t1\t$de_scontig_id\t$de_start\t$de_end\t$chr_strand\t$prev_mouse_id\n";
    } else {
      print STDERR "$prev_human_id\t$current_start\t$current_end\t1\t$de_scontig_id\t$de_start\t$de_end\t$chr_strand\t$prev_mouse_id\n";
    }
  }
}

sub map_to_denormalised ($$$) {
  my ($chr,$pos,$mouse_ending_contigs) = @_;
  
  my $block = int($pos / $mouse_super_contig_size);
  
  my $start = ($block * $mouse_super_contig_size) + 1;
  my $end = ($block + 1) * $mouse_super_contig_size;
 
  if ($start >= $mouse_ending_contigs->{'start'}) {
    $end   = $mouse_ending_contigs->{'end'};
  }

  my $rem   = $pos - $start + 1; # plus 1 for 'biological' coordinates
  
  my $denorm_contig_id = $chr.".".$start."-".$end;
  
  return ($denorm_contig_id,$rem);
}











