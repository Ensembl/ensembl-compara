#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

print "# debut: ",time,"\n";

my ($input_chr_name) = @ARGV;

my $compara_host = 'ecs1b.sanger.ac.uk';
my $compara_dbname = 'abel_compara_human_mouse';
my $compara_dbuser = 'ensro';

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $compara_host,
							      -user => $compara_dbuser,
							      -dbname => $compara_dbname );

my $ncbi_host = 'ecs1d.sanger.ac.uk';
my $ncbi_dbname = 'homo_sapiens_core_130';
my $ncbi_dbuser = 'ensro';

my $ncbi_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $ncbi_host,
						  -user => $ncbi_dbuser,
						  -dbname => $ncbi_dbname );
#$ncbi_db->static_golden_path_type('NCBI_26');
#my $sncbi = $ncbi_db->get_StaticGoldenPathAdaptor;

my $mouse_host = 'ecs1a.sanger.ac.uk';
my $mouse_dbname = 'mouse_sc011015_alistair';
my $mouse_dbuser = 'ensro';

my $mouse_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $mouse_host,
						   -user => $mouse_dbuser,
						   -dbname => $mouse_dbname );

$| = 1;

#$mouse_db->static_golden_path_type('sanger_20011015_2');
#my $smouse = $mouse_db->get_StaticGoldenPathAdaptor;

# HUMAN assembly data reading
#############################

print "# HUMAN assembly data reading...\n";

# list all chromosome name
#my $sth = $ncbi_db->prepare("select distinct(chr_name) from static_golden_path where chr_name not like \"%NT%\"");

#unless ($sth->execute()) {
#  $ncbi_db->throw("Failed execution of a select query");
#}

# key $contig_id
# value array = ($chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori)
my %human_contig;

# key $chr_name
# value array of contig_ids
my %human_chromosome;

#while (my ($chr_name) = $sth->fetchrow_array()) {
#  last if ($chr_name eq "10");
print "# chr nb ",$input_chr_name,"\n";
if (defined $input_chr_name) {
  my $chr_name = $input_chr_name;
  my $sth = $ncbi_db->prepare("select c.id,s.chr_start,s.chr_end,s.raw_start,s.raw_end,s.raw_ori from contig c,static_golden_path s where c.internal_id = s.raw_id and s.chr_name=\"$chr_name\" order by s.chr_start asc");

  unless ($sth->execute()) {
    $ncbi_db->throw("Failed execution of a select query");
  }

  while (my ($contig_id,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori) = $sth->fetchrow_array()) {
    $human_contig{$contig_id} = [$chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori];
    push @{$human_chromosome{$chr_name}},$contig_id;
  }
} else {
  die "Needs a input chromosome name\n";
}

# MOUSE assembly data reading
#############################

print "# MOUSE assembly data reading...\n";

# list all chromosome name
my $sth = $mouse_db->prepare("select distinct(chr_name) from static_golden_path");

unless ($sth->execute()) {
  $ncbi_db->throw("Failed execution of a select query");
}

# key $contig_id
# value array = ($chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori)
my %mouse_contig;

# key $chr_name
# value array of contig_ids
my %mouse_chromosome;

while (my ($chr_name) = $sth->fetchrow_array()) {
#  next if ($chr_name ne "4" && $chr_name ne "5" && $chr_name ne "NA_unmapped");
  print "# chr nb ",$chr_name,"\n";

  my $sth = $mouse_db->prepare("select c.id,s.chr_start,s.chr_end,s.raw_start,s.raw_end,s.raw_ori from contig c,static_golden_path s where c.internal_id = s.raw_id and s.chr_name=\"$chr_name\" order by s.chr_start asc");

  unless ($sth->execute()) {
    $ncbi_db->throw("Failed execution of a select query");
  }

  while (my ($contig_id,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori) = $sth->fetchrow_array()) {
    $mouse_contig{$contig_id} = [$chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori];
    push @{$mouse_chromosome{$chr_name}},$contig_id;
  }
}

# HUMAN <-> MOUSE correspondance
################################

print "# HUMAN <-> MOUSE correspondance...\n";

foreach my $chr_name (keys %human_chromosome) {
  
#  my $index = 0;
  my @gaps;
  my $gap = new Compara::Gap;
  my $close_the_gap = 0;

  print "# chr_name: $chr_name, number of contigs: ",scalar @{$human_chromosome{$chr_name}},"\n";
  print "# nb contig: ", scalar @{$human_chromosome{$chr_name}},"\n";
  foreach my $contig_id (@{$human_chromosome{$chr_name}}) {
#    $index++;
    my $sth = $compara_db->prepare("select g.align_id,g.dnafrag_id,g.raw_start-g.align_start from dnafrag d,genomic_align_block g where d.dnafrag_id=g.dnafrag_id and d.name=\"$contig_id\"");

    unless ($sth->execute()) {
      $compara_db->throw("Failed execution of a select query");
    }
    
    my $align_found = 0;
    my @align_blocks;

    while (my ($align_id,$dnafrag_id,$offset_compara) = $sth->fetchrow_array()) {

      unless ($align_id =~ /^\d+$/ && $dnafrag_id =~ /^\d+$/) {
	print "# $align_id:$dnafrag_id:\n";
	die;
      }

      my $sth = $compara_db->prepare("select d.name,g.align_start,g.align_end,g.raw_start,g.raw_end,g.raw_strand from dnafrag d,genomic_align_block g where align_id=$align_id and g.dnafrag_id!=$dnafrag_id and d.dnafrag_id=g.dnafrag_id order by g.align_start asc");
      
      unless ($sth->execute()) {
	$compara_db->throw("Failed execution of a select query");
      }

      while (my ($name,$align_start,$align_end,$raw_start,$raw_end,$raw_strand) = $sth->fetchrow_array()) {

	unless (defined $mouse_contig{$name}) {
	  next;
	}

	my @human_contig_feat = @{$human_contig{$contig_id}};
	my @mouse_contig_feat = @{$mouse_contig{$name}};
	
	if ($human_contig_feat[5] == 1) {

# should not consider here align blocks which are outside of the part of contig used in the golden path assembly

	  my $offset_gp = $human_contig_feat[1]-$human_contig_feat[3];
	  push  @align_blocks, [$contig_id,@{$human_contig{$contig_id}},$name,@{$mouse_contig{$name}},$raw_start,$raw_end,$raw_strand,$align_start+$offset_compara,$align_end+$offset_compara,$raw_strand*$mouse_contig_feat[5],$align_start+$offset_compara+$offset_gp,$align_end+$offset_compara+$offset_gp];

	} elsif ($human_contig_feat[5] == -1) {

# should not consider here align blocks which are outside of the part of contig used in the golden path assembly

	  my $offset_gp = $human_contig_feat[1]+$human_contig_feat[4];
	  push  @align_blocks, [$contig_id,@{$human_contig{$contig_id}},$name,@{$mouse_contig{$name}},$raw_start,$raw_end,$raw_strand,$align_start+$offset_compara,$align_end+$offset_compara,-($raw_strand*$mouse_contig_feat[5]),$offset_gp-($align_end+$offset_compara),$offset_gp-($align_start+$offset_compara)];

	}

	$align_found = 1;

      } 
    }
    
    if ($align_found) {
      
      @align_blocks = sort {$a->[-2] <=> $b->[-2] || $a->[-1] <=> $b->[-1]} @align_blocks;
      
      foreach my $align_block (@align_blocks) {
	
#	print join(" ",@{$align_block}),"\n";
	
	if (scalar @{$gap->contigs}) {
	  
	  my $contig = new Compara::Contig;

	  $contig->id($align_block->[7]);
	  $contig->chr_name($align_block->[8]);
	  $contig->chr_start($align_block->[9]);
	  $contig->chr_end($align_block->[10]);
	  $contig->raw_start($align_block->[11]);
	  $contig->raw_end($align_block->[12]);
	  $contig->raw_strand($align_block->[19]);
	  if (scalar @{$gap->upstream_mapped_border_contigs}) {
	    my $last_contig = $gap->upstream_mapped_border_contigs->[-1];
	    unless ($contig->id eq $last_contig->id) {
	      $gap->upstream_mapped_border_contigs($contig);
	    }
	  } else {
	    $gap->upstream_mapped_border_contigs($contig);
	  }
	  $close_the_gap = 1;
	} 
	
	if (! scalar @{$gap->contigs}) {
	  my $contig = new Compara::Contig;
	  $contig->id($align_block->[7]);
	  $contig->chr_name($align_block->[8]);
	  $contig->chr_start($align_block->[9]);
	  $contig->chr_end($align_block->[10]);
	  $contig->raw_start($align_block->[11]);
	  $contig->raw_end($align_block->[12]);
	  $contig->raw_strand($align_block->[19]);
	  if (scalar @{$gap->downstream_mapped_border_contigs}) {
	    my $last_contig = $gap->downstream_mapped_border_contigs->[-1];
	    unless ($contig->id eq $last_contig->id) {
	      $gap->downstream_mapped_border_contigs($contig);
	    }
	  } else {
	    $gap->downstream_mapped_border_contigs($contig);
	  }
	}
      }

    }  else {

     if (scalar @{$gap->contigs} && $close_the_gap) {
       
#       last if (scalar @gaps == 5);
	push @gaps,$gap;
#	print ".";

	my $j;
	if (scalar @{$gap->upstream_mapped_border_contigs} >= 5) {
	  $j = 5;
	} else {
	  $j = scalar @{$gap->upstream_mapped_border_contigs};
	}
	
	my @uptream_mapped_border_contigs;

	for (my $i = -$j; $i < 0; $i++) {
	  push @uptream_mapped_border_contigs, $gap->upstream_mapped_border_contigs->[$i];
	}
	$gap = new Compara::Gap;
	foreach my $contig (@uptream_mapped_border_contigs) {
	  $gap->downstream_mapped_border_contigs($contig);
	}
      }
      $close_the_gap = 0;

      my $contig = new Compara::Contig;
      $contig->id($contig_id);
      $contig->chr_name($human_contig{$contig_id}->[0]);
      $contig->chr_start($human_contig{$contig_id}->[1]);
      $contig->chr_end($human_contig{$contig_id}->[2]);
      $contig->raw_start($human_contig{$contig_id}->[3]);
      $contig->raw_end($human_contig{$contig_id}->[4]);
      $contig->raw_strand($human_contig{$contig_id}->[5]);
      
#      print $contig->id($contig_id)," ",$contig->chr_name," ",$contig->chr_start," ",$contig->chr_end," ",$contig->raw_start," ",$contig->raw_end," ",$contig->raw_strand," : UNDEF\n";

      $gap->contigs($contig);
      $gap->chromosome($contig->chr_name) unless (defined $gap->chromosome);
      $gap->start($contig->chr_start) unless(defined $gap->start); 
      if (defined $gap->start && $gap->start > $contig->chr_start) {
	$gap->start($contig->chr_start);
      }
      $gap->end($contig->chr_end) unless(defined $gap->end);
      if (defined $gap->end && $gap->end < $contig->chr_end) {
	$gap->end($contig->chr_end);
      }
     $gap->size($gap->end-$gap->start+1);
     
   }
  }
  
#  $gap->{'_upstream_mapped_border_contigs'} = [];
  
  push @gaps, $gap;
  
#  print "# index: $index\n";
  
  print "# nb gaps: ",scalar @gaps,"\n";
  my $gap_sum_size = 0;
  foreach my $gap (@gaps) {
    $gap_sum_size += $gap->size;
  }
  print "# gap_sum_size: $gap_sum_size\n";
  print "# average size: ",$gap_sum_size/(scalar @gaps),"\n";
  my %correspondance_already_printed;

  foreach my $gap (@gaps) {



    print "# gap: ",$gap->chromosome," ",$gap->start," ",$gap->end," ",$gap->size,"\n";
#    print "downstream_mapped_border_contigs\n";
#    if (scalar @{$gap->downstream_mapped_border_contigs}) {
#	print "# down_contig: ",$gap->downstream_mapped_border_contigs->[-1]->id," ",$gap->downstream_mapped_border_contigs->[-1]->chr_name," ",$gap->downstream_mapped_border_contigs->[-1]->chr_start," ",$gap->downstream_mapped_border_contigs->[-1]->chr_end," ",$gap->downstream_mapped_border_contigs->[-1]->raw_start," ",$gap->downstream_mapped_border_contigs->[-1]->raw_end," ",$gap->downstream_mapped_border_contigs->[-1]->raw_strand,"\n";
#    }
#    foreach my $contig (@{$gap->downstream_mapped_border_contigs}) {
#      print "down_contig: ",$contig->id," ",$contig->chr_name," ",$contig->chr_start," ",$contig->chr_end," ",$contig->raw_start," ",$contig->raw_end," ",$contig->raw_strand,"\n";
#    }
#    print "contigs\n";
#    foreach my $contig (@{$gap->contigs}) {
#      print "contig: ",$contig->id," ",$contig->chr_name," ",$contig->chr_start," ",$contig->chr_end," ",$contig->raw_start," ",$contig->raw_end," ",$contig->raw_strand,"\n";
#    }
#    print "upstream_mapped_border_contigs\n";
#    my $j;
#    if (scalar @{$gap->upstream_mapped_border_contigs} >= 5) {
#      $j = 5;
#    } else {
#      $j = scalar @{$gap->upstream_mapped_border_contigs};
#    }
#    if (scalar @{$gap->upstream_mapped_border_contigs}) {
#	print "# up_contig: ",$gap->upstream_mapped_border_contigs->[0]->id," ",$gap->upstream_mapped_border_contigs->[0]->chr_name," ",$gap->upstream_mapped_border_contigs->[0]->chr_start," ",$gap->upstream_mapped_border_contigs->[0]->chr_end," ",$gap->upstream_mapped_border_contigs->[0]->raw_start," ",$gap->upstream_mapped_border_contigs->[0]->raw_end," ",$gap->upstream_mapped_border_contigs->[0]->raw_strand,"\n";
#    }
#    for (my $i = 0; $i < $j; $i++) {
#      my $contig = $gap->upstream_mapped_border_contigs->[$i];
#      print "up_contig: ",$contig->id," ",$contig->chr_name," ",$contig->chr_start," ",$contig->chr_end," ",$contig->raw_start," ",$contig->raw_end," ",$contig->raw_strand,"\n";
#    }
    
#    next;
    
    if (scalar @{$gap->downstream_mapped_border_contigs} &&
	scalar @{$gap->upstream_mapped_border_contigs}) {
     
      if ($gap->downstream_mapped_border_contigs->[-1]->chr_name eq
	  $gap->upstream_mapped_border_contigs->[0]->chr_name) {
	
	my ($chr_name,$chr_start,$chr_end,$strand);
	$chr_name = $gap->downstream_mapped_border_contigs->[-1]->chr_name;
	if ($gap->downstream_mapped_border_contigs->[-1]->chr_start <=
	    $gap->upstream_mapped_border_contigs->[0]->chr_start) {
	  $chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start;
	  $chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end;
	  $strand = 1;
	} else {
	  $chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start;
	  $chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end;
	  $strand = -1;
	}
	
	if (abs($gap->size - abs($chr_end - $chr_start)) <= 10000) {
	  
#	  print "# A1 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	  print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);	
	  
	} elsif ($gap->size > abs($chr_end - $chr_start)) {
	  
	  my $restricted_gap = new Compara::Gap;
	  $restricted_gap->chromosome($gap->chromosome);
	  $restricted_gap->start($gap->start);
	  $restricted_gap->end($restricted_gap->start + ($chr_end - $chr_start));
	  $restricted_gap->size($restricted_gap->end - $restricted_gap->start+1);
	  foreach my $contig (@{$gap->contigs}) {
	    if (($contig->chr_start >= $restricted_gap->start && $contig->chr_start <= $restricted_gap->end) ||
		($contig->chr_end >= $restricted_gap->start && $contig->chr_end <= $restricted_gap->end)) {
	      $restricted_gap->contigs($contig);
	    }
	  }
	  
#	  print "# A2.1 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	  print_contigs_between_down_and_upstream($mouse_db,$restricted_gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	  
	  $restricted_gap = new Compara::Gap;
	  $restricted_gap->chromosome($gap->chromosome);
	  $restricted_gap->start($gap->end - ($chr_end - $chr_start));
	  $restricted_gap->end($gap->end);
	  $restricted_gap->size($restricted_gap->end - $restricted_gap->start + 1);
	  foreach my $contig (@{$gap->contigs}) {
	    if (($contig->chr_start >= $restricted_gap->start && $contig->chr_start <= $restricted_gap->end) ||
		($contig->chr_end >= $restricted_gap->start && $contig->chr_end <= $restricted_gap->end)) {
	      $restricted_gap->contigs($contig);
	    }
	  }
	  
#	  print "# A2.2 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	  print_contigs_between_down_and_upstream($mouse_db,$restricted_gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	  
	  
	} elsif ($gap->size < abs($chr_end - $chr_start)) {
	  
	  my ($chr_name,$chr_start,$chr_end,$strand);
	  $chr_name = $gap->downstream_mapped_border_contigs->[-1]->chr_name;
	  $strand = $gap->downstream_mapped_border_contigs->[-1]->raw_strand;
	  if ($strand > 0) {
	    $chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start;
	    $chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end + $gap->size;
	  } elsif ($strand < 0) {
	    $chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start - $gap->size;
	    $chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end;
	  }
#	  print "# A3.1 = B1 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	  print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	  
	  $chr_name = $gap->upstream_mapped_border_contigs->[0]->chr_name;
	  $strand = $gap->upstream_mapped_border_contigs->[0]->raw_strand;
	  if ($strand < 0) {
	    $chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start;
	    $chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end + $gap->size;
	  } elsif ($strand > 0) {
	    $chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start - $gap->size;
	    $chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end;
	  }
#	  print "# A3.2 = B2 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	  print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	  
	}
	
      } else {
	
	my ($chr_name,$chr_start,$chr_end,$strand);
	$chr_name = $gap->downstream_mapped_border_contigs->[-1]->chr_name;
	$strand = $gap->downstream_mapped_border_contigs->[-1]->raw_strand;
	if ($strand > 0) {
	  $chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start;
	  $chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end + $gap->size;
	} elsif ($strand < 0) {
	  $chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start - $gap->size;
	  $chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end;
	}
#	print "# B1 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	
	$chr_name = $gap->upstream_mapped_border_contigs->[0]->chr_name;
	$strand = $gap->upstream_mapped_border_contigs->[0]->raw_strand;
	if ($strand < 0) {
	  $chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start;
	  $chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end + $gap->size;
	} elsif ($strand > 0) {
	  $chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start - $gap->size;
	  $chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end;
	}
#	print "# B2 chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
	print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	
      }
 
    } elsif (scalar @{$gap->downstream_mapped_border_contigs}) {

      my ($chr_name,$chr_start,$chr_end,$strand);
      $chr_name = $gap->downstream_mapped_border_contigs->[-1]->chr_name;
      $strand = $gap->downstream_mapped_border_contigs->[-1]->raw_strand;
      if ($strand > 0) {
	$chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start;
	$chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end + $gap->size;
      } elsif ($strand < 0) {
	$chr_start = $gap->downstream_mapped_border_contigs->[-1]->chr_start - $gap->size;
	$chr_end = $gap->downstream_mapped_border_contigs->[-1]->chr_end;
      }
#      print "# C chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
      print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);

    } elsif (scalar @{$gap->upstream_mapped_border_contigs}) {

      my ($chr_name,$chr_start,$chr_end,$strand);
      $chr_name = $gap->upstream_mapped_border_contigs->[0]->chr_name;
      $strand = $gap->upstream_mapped_border_contigs->[0]->raw_strand;
      if ($strand < 0) {
	$chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start;
	$chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end + $gap->size;
      } elsif ($strand > 0) {
	$chr_start = $gap->upstream_mapped_border_contigs->[0]->chr_start - $gap->size;
	$chr_end = $gap->upstream_mapped_border_contigs->[0]->chr_end;
      }
#      print "# D chr_start: $chr_start, chr_end: $chr_end, chr_name: $chr_name\n";
      print_contigs_between_down_and_upstream($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,\%correspondance_already_printed);
	
    }
  }
  print "# //\n";
}

print "# fin: ",time,"\n";

sub print_contigs_between_down_and_upstream ($$$$$$) {
  my ($mouse_db,$gap,$chr_start,$chr_end,$chr_name,$strand,$correspondance_already_printed_href) = @_; 
  my $sth;
  my $size = $chr_end - $chr_start + 1;
  if ($strand > 0) {
    $sth = $mouse_db->prepare("select fpcctg_name,chr_name,chr_start,chr_end,raw_start,raw_end,raw_ori from static_golden_path where chr_start>=$chr_start and chr_end<=$chr_end and chr_name=\"$chr_name\" order by chr_start asc");
  } elsif ($strand < 0) {
    $sth = $mouse_db->prepare("select fpcctg_name,chr_name,chr_start,chr_end,raw_start,raw_end,raw_ori from static_golden_path where chr_start>=$chr_start and chr_end<=$chr_end and chr_name=\"$chr_name\" order by chr_start desc");
  } 
	
  unless ($sth->execute()) {
    $mouse_db->throw("Failed execution of a select query");
  }

  my @Mapped_Contigs;
  while (my ($id,$chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_strand) = $sth->fetchrow_array()) {

    my $contig = new Compara::Contig;
    $contig->id($id);
    $contig->chr_name($chr_name);
    $contig->chr_start($chr_start);
    $contig->chr_end($chr_end);
    $contig->raw_start($raw_start);
    $contig->raw_end($raw_end);
    $contig->raw_strand($raw_strand);
    push @Mapped_Contigs, $contig;
  }

  if ($strand > 0) {
    @Mapped_Contigs = sort {$a->chr_start <=> $b->chr_start} @Mapped_Contigs;
  } elsif  ($strand < 0) {
    @Mapped_Contigs = sort {$b->chr_start <=> $a->chr_start} @Mapped_Contigs;
  }

  my ($main_window,$splipping_window,$mapped_contig_size) = (50000,10000,$chr_end - $chr_start + 1);

  my ($contigW,$contigSW,$mapped_contigW,$mapped_contigSW);
  if ($gap->size == $mapped_contig_size) {
    ($contigW,$contigSW,$mapped_contigW,$mapped_contigSW) = ($main_window,$splipping_window,$main_window,$splipping_window);
  } elsif ($gap->size > $mapped_contig_size) {
    ($contigW,$contigSW) = ($main_window,$splipping_window);
    $mapped_contigW = $mapped_contig_size * $contigW / $gap->size;
    $mapped_contigSW = $mapped_contig_size * $contigSW / $gap->size;
  } elsif ($gap->size < $mapped_contig_size) {
    ($mapped_contigW,$mapped_contigSW) = ($main_window,$splipping_window);
    $contigW = $gap->size * $mapped_contigW / $mapped_contig_size;
    $contigSW = $gap->size * $mapped_contigSW / $mapped_contig_size;
  }

  my ($contigstart,$contigend,$mapped_contigstart,$mapped_contigend) =
    ($gap->start, $gap->end, $chr_start,$chr_end);

#  return 1;
  
  if ($strand > 0) {
    $contigend = $contigstart + $contigW - 1;
    $mapped_contigend = $mapped_contigstart + $mapped_contigSW - 1;
    my @contigs = get_contigs($gap->contigs,$contigstart,$contigend);
    my @mapped_contigs = get_contigs(\@Mapped_Contigs,$mapped_contigstart,$mapped_contigend);
    print_correspondance(\@contigs,\@mapped_contigs,$correspondance_already_printed_href);
    $contigend = $contigend + $contigSW;
    ($mapped_contigstart,$mapped_contigend) = ($mapped_contigstart + $mapped_contigSW,$mapped_contigend +  $mapped_contigSW);
#    print "# milieu1:",time,"\n";

    while ($contigstart <= $gap->end || $mapped_contigstart <= $chr_end) {

      @contigs = get_contigs($gap->contigs,$contigstart,$contigend);
      @mapped_contigs = get_contigs(\@Mapped_Contigs,$mapped_contigstart,$mapped_contigend);
      print_correspondance(\@contigs,\@mapped_contigs,$correspondance_already_printed_href);
      ($contigstart,$contigend) = ($contigstart + $contigSW,$contigend +  $contigSW);
      ($mapped_contigstart,$mapped_contigend) = ($mapped_contigstart + $mapped_contigSW,$mapped_contigend + $mapped_contigSW);

    }
#    print "# milieu2:",time,"\n";
#    return 1;

  } elsif ($strand < 0) {

    $contigend = $contigstart + $contigW - 1;
    $mapped_contigstart = $mapped_contigend - $mapped_contigSW + 1;
    my @contigs = get_contigs($gap->contigs,$contigstart,$contigend);
    my @mapped_contigs = get_contigs(\@Mapped_Contigs,$mapped_contigstart,$mapped_contigend);
    print_correspondance(\@contigs,\@mapped_contigs,$correspondance_already_printed_href);
    $contigend = $contigend + $contigSW;
    ($mapped_contigstart,$mapped_contigend) = ($mapped_contigstart - $mapped_contigSW,$mapped_contigend - $mapped_contigSW);
#    print "# milieu1:",time,"\n";
    while ($contigstart <= $gap->end || $mapped_contigend >= $chr_start) {

      @contigs = get_contigs($gap->contigs,$contigstart,$contigend);
      @mapped_contigs = get_contigs(\@Mapped_Contigs,$mapped_contigstart,$mapped_contigend);
      print_correspondance(\@contigs,\@mapped_contigs,$correspondance_already_printed_href);
      ($contigstart,$contigend) = ($contigstart + $contigSW,$contigend +  $contigSW);
      ($mapped_contigstart,$mapped_contigend) = ($mapped_contigstart - $mapped_contigSW,$mapped_contigend - $mapped_contigSW);

    }
#    print "# milieu2:",time,"\n";
#    return 1;
  }
}

sub get_contigs ($$$) {
  my ($contigs_aref,$start,$end) = @_;
  my @contigs;
#  print "## $start, $end\n";
  foreach my $contig (@{$contigs_aref}) {
#    print "# ",$contig->id,", ",$contig->chr_start,", ",$contig->chr_end,"\n";
    if (($contig->chr_start >= $start && $contig->chr_start <= $end) ||
	($contig->chr_end >= $start && $contig->chr_end <= $end) ||
	($contig->chr_start < $start && $contig->chr_end > $end)) {
      push @contigs,$contig;
     }
  }
#  print "scalar: ",scalar @contigs,"\n";
  return @contigs;
}

sub print_correspondance ($$$) {
  my ($contigs_aref,$mapped_contigs_aref,$correspondance_already_printed_href) = @_;
  foreach my $contig (@{$contigs_aref}) {
    foreach my $mapped_contig (@{$mapped_contigs_aref}) {
      next if (exists $correspondance_already_printed_href->{$contig->id}{$mapped_contig->id});
      print "Homo_sapiens:",$contig->id,"::Mus_musculus:",$mapped_contig->id,"\n";
#      print "Homo_sapiens:",$contig->id," ",$contig->chr_start," ",$contig->chr_end,"::Mus_musculus:",$mapped_contig->id," ",$mapped_contig->chr_start," ",$mapped_contig->chr_end,"\n";
      $correspondance_already_printed_href->{$contig->id}{$mapped_contig->id} = 1;
    }
  }
}

package Compara::Gap;

use strict;

sub new {
  my ($class, @args) = @_;
  my $self = bless {}, $class;

  $self->{'_contigs'} = [];
  $self->{'_mapped_contigs'} = [];
  $self->{'_upstream_mapped_border_contigs'} = [];
  $self->{'_downstream_mapped_border_contigs'} = [];

  return $self;
}

sub contigs {
  my ($self,$value) = @_;
  if (defined $value) {
    push @{$self->{'_contigs'}}, $value;
  }
  return $self->{'_contigs'};
}

sub mapped_contigs {
  my ($self,$value) = @_;
  if (defined $value) {
    push @{$self->{'_mapped_contigs'}}, $value;
  }
  return $self->{'_mapped_contigs'};
}

sub upstream_mapped_border_contigs {
  my ($self,$value) = @_;
  if (defined $value) {
    push @{$self->{'_upstream_mapped_border_contigs'}}, $value;
  }
  return $self->{'_upstream_mapped_border_contigs'};
}

sub downstream_mapped_border_contigs {
  my ($self,$value) = @_;
  if (defined $value) {
    if (scalar @{$self->{'_downstream_mapped_border_contigs'}} == 5) {
      shift @{$self->{'_downstream_mapped_border_contigs'}};
      push @{$self->{'_downstream_mapped_border_contigs'}}, $value;
    } else {
      push @{$self->{'_downstream_mapped_border_contigs'}}, $value;
    }
  }
  return $self->{'_downstream_mapped_border_contigs'};
}

sub size {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_size'} = $value;
  }
  return $self->{'_size'};

}

sub chromosome {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_chromosome'} = $value;
  }
  return $self->{'_chromosome'};

}

sub start {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_start'} = $value;
  }
  return $self->{'_start'};

}

sub end {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_end'} = $value;
  }
  return $self->{'_end'};

}

1;

package Compara::Contig;

use strict;

sub new {
  my ($class, @args) = @_;
  my $self = bless {}, $class;
  
  return $self;
}

sub id {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_id'} = $value;
  }
  return $self->{'_id'};

}

sub chr_name {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_chr_name'} = $value;
  }
  return $self->{'_chr_name'};

}

sub chr_start {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_chr_start'} = $value;
  }
  return $self->{'_chr_start'};

}

sub chr_end {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_chr_end'} = $value;
  }
  return $self->{'_chr_end'};

}
sub raw_start {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_raw_start'} = $value;
  }
  return $self->{'_raw_start'};

}
sub raw_end {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_raw_end'} = $value;
  }
  return $self->{'_raw_end'};

}
sub raw_strand {
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'_raw_strand'} = $value;
  }
  return $self->{'_raw_strand'};

}

1;

exit 0;
