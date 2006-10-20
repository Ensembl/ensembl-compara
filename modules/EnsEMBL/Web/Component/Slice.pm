package EnsEMBL::Web::Component::Slice;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
use Data::Dumper;
no warnings "uninitialized";

#----------------------------------------------------------------------


=head2 markedup_seq

  Arg [1]   : 
  Function  : Creates marked-up FASTA-like string 
  Returntype: string (HTML fromatted)
  Exceptions: 
  Caller    : 
  Example   : 

=cut


sub align_sequence_display {
  my( $panel, $object ) = @_;

  my $object_id = $object->stable_id;
  my $slice   = $object->get_slice_object->Obj;
  my $sstrand = $slice->strand; # SNP strand bug has been fixed in snp_display function
  my $sstart  = $slice->start;
  my $send    = $slice->end;
  my $slength = $slice->length;

  my $species = $object->species;
  my $orthologue = {
      $species => {
	  $object_id => 1
	  }
      };
  

  my $comparadb = $object->database('compara');

  my $aselect = $object->param("RGselect") || 'NONE';

  my $width = $object->param("display_width") || 60;
  my @slice_display;
  my @SEQ = ();
  my $DNA;
  my $SeqDNA;
  my $SeqSlices;
  my @tsa;
  my $ts = time;
  my @slice_seq;
  my $alignments_no = 1;
  my $max_position = 0;
  my $max_region = -1;

  if ($aselect eq 'NONE') {
    push @slice_display, $slice;
    my $spe = $object->species;
    $SeqDNA->{$spe} = $slice->seq;
    push @{$SeqSlices->{$spe}}, $slice->name;
  } else {
    my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($aselect); 

    my $asa = $comparadb->get_adaptor("AlignSlice" );
    my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set);

    my @selected_species = grep {$_ } $object->param("ms_$aselect");

# I could not find a better way to distinguish between pairwise alignments
# and multiple alignments. The difference is that in case of multiple alignments
# there are checkboxes for all species from the alignment apart from the reference species: So we need to add the reference species to the list of selected species. In case of pairwise alignments the list remains empty - that will force the display of all available species in the alignment
    if ( scalar (@{$method_link_species_set->species_set}) > 2) {
      unshift @selected_species, $object->species;
    }

    push @slice_display, @{$align_slice->get_all_Slices(@selected_species)};
    
    push @tsa, (time - $ts);

    $alignments_no = scalar(@slice_display);  

    foreach my $sl (@slice_display) {
      my @lsa = ();
      my $ff = time;
      my $idx = 0;
      #	  push @lsa, (time - $ff);
      my $sq = $sl->seq;
      push @lsa, (time - $ff);
      my $ass = $sl->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') ? 1 : 0;
      my $spe = $ass ? $sl->seq_region_name : $object->species;
      $spe =~ s/ /_/g;
      
      $SeqDNA->{$spe} =$sq." ";

      foreach my $s (split(//, $sq)) {
	$SEQ[$idx++]->{uc($s)} ++;
      }

      #	  warn("\t$spe: ".join('*', @lsa)."\n");


### In case we need to display coordinates relative to a coordinate system - 
### get the format of line numbering
      if ($ass) {
	foreach my $ss (@{$sl->get_all_underlying_Slices}) {
	  next if ($ss->seq_region_name eq 'GAP');
	  push @{$SeqSlices->{$spe}}, $ss->name;
	  if ( (my $srn_length = length($ss->seq_region_name)) > $max_region) {
	    $max_region = $srn_length;
	  }
	  $max_position = $ss->start if ($ss->start > $max_position);
	  $max_position = $ss->end if ($ss->end > $max_position);
	}
      } else {
	$max_position = $sl->start if ($sl->start > $max_position);
	$max_position = $sl->end if ($sl->end > $max_position);
	if ( (my $srn_length = length($sl->seq_region_name)) > $max_region) {
	  $max_region = $srn_length;
	}

	push @{$SeqSlices->{$spe}}, $sl->name;
      }
    }
    push @tsa, (time - $ts);

    if ($alignments_no > 1 && (my $conservation = $object->param("conservation") ne 'off')) {
      my $num = int(scalar(@slice_display) + 1) / 2;
	  
      foreach my $nt (@SEQ) {
	$nt->{S} = join('', grep {$nt->{$_} > $num} keys(%{$nt}));
	$nt->{S} =~ s/[-.]//;
      }

      #      warn("SEQ:".Dumper(\@SEQ));
      push @tsa, (time - $ts);

      foreach my $sl (@slice_display) {
	
	my $idx = 0;
	my $ass = $sl->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') ? 1 : 0;
	my $spe = $ass ? $sl->seq_region_name : $object->species;
	$spe =~ s/ /_/g;
	my $sequence = $SeqDNA->{$spe};
	
	my $f = 0;
	my $ms = 0;
	my @csrv = ();
	foreach my $sym (split(//, $sequence)) {
	  if (uc ($sym) eq $SEQ[$idx++]->{S}) {
	    if ($f == 0) {
	      $f = 1;
	      $ms = $idx;
	    }
	  } else {
	    if ($f == 1) {
	      $f = 0;
	      push @csrv, [$ms, $idx];
	    }
	  }
	}
	if ($f == 1) {
	  push @csrv, [$ms, $idx];
	}
	
	$DNA->{$spe} = \@csrv;
      }
    }
    push @tsa, (time - $ts);
  } # end if ($aselect eq'NONE')
  
  #  warn("DNA:".Dumper($DNA));
  
  my $t1 = time;
  my ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On) = (1, 16, 32, 64, 128, 256);
  my @linenumbers = $object->get_slice_object->line_numbering();
  my ($lineformat)  =  $object->param('line_numbering') eq 'slice' ? length($max_position) : sort{$b<=>$a} map{length($_)} @linenumbers;
  
  if (@linenumbers) {
      $linenumbers[0] --;
  }

  my $BR = '###';
  my $html_hash;
  my $ind = 1;

  my $t_set = $object->param('title_display') ne 'off' ? 1 : 0 ;

  foreach my $as (@slice_display) {
    my $ass = $as->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') ? 1 : 0;
    my $spe = $ass ? $as->seq_region_name : $object->species;
    $spe =~ s/ /_/g;
    my @fl = $spe =~ m/^(.)|_(.)/g;
    my $abbr = $alignments_no > 1 ? join("",@fl, " ") : '';
    my $sequence = $SeqDNA->{$spe};
    
    my $csrv = $DNA->{$spe};

    my $slice_length = length($sequence);
    warn("SLENGTH:$spe:$slice_length\n");
    my @markup_bins;

    my $h;
    
    # Mark final bp
    push @markup_bins, { 'pos' => $slice_length, 'mark' => 1 };


    # Split the sequence into lines of $width bp length.
    # Mark start and end of each line
    my $bin = 0;
    my $binE = int(($slice_length-1) / $width);

    while ($bin < $binE) {
      my $pp = $bin * $width + 1;
      push @markup_bins, { 'pos' => $pp };

      $pp += ($width - 1);
      push @markup_bins, { 'pos' => $pp, 'mark' => 1 };
      $bin ++;
    }
    push @markup_bins, { 'pos' => $bin * $width + 1 };

    while ($sequence =~ m/(\-+[\w\s])/gc) {
      my $txt = sprintf("%d bp", pos($sequence) - $-[0] - 1);
      push @markup_bins, { 'pos' => $-[0]+1, 'mask' => $ins_On, 'text' => $txt };
      push @markup_bins, { 'pos' => pos($sequence), 'mask' => -$ins_On, 'text' => $txt };
    }

    foreach my $c (@$csrv) {
      #	  warn("CS:".join('*', @$c));
      push @markup_bins, { 'pos' => $c->[0], 'mask' => $cs_On };
      if ($c->[1] % $width == 0) {
	push @markup_bins, { 'pos' => $c->[1]+1, 'mask' => -$cs_On };
      } else {
	push @markup_bins, { 'pos' => $c->[1], 'mask' => -$cs_On };
      }
    }
      
    if (  $object->param( 'codons_display' ) ne 'off' ) {
      my @transcripts =  map  { @{$_->get_all_Transcripts } } @{$as->get_all_Genes()} ;
      if ($ass) {
	foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
	  #	      warn(join('*', 'T:', $spe, $t->stable_id, $t->coding_region_start, $t->coding_region_end, $t->strand));
	  next if (! defined($t->translation));

	  foreach my $c (@{$t->translation->all_start_codon_mappings || []}) {
	    warn(join('*', "SCod:", $spe, $t->stable_id, $c->start, $c->end, $t->strand, "\n"));
	    
	    my ($start, $end) = ($c->start, $c->end);
	    if ($t->strand < 0) {
	      ($start, $end) = ($slice_length - $end, $slice_length - $start);
	    }


	    next if ($end < 1 || $start > $slice_length);
	    $start = 1 unless $start > 0;
	    $end = $slice_length unless $end < $slice_length;

	    my $txt = sprintf("START(%s)",$t->stable_id);
	    push @markup_bins, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
	    push @markup_bins, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
		  
	  }

	  foreach my $c (@{$t->translation->all_end_codon_mappings ||[]}) {
	    warn(join('*', 'ECod:', $spe, $t->stable_id, $c->{start}, $c->{end}, $t->strand, "\n"));
	    
	    my ($start, $end) = ($c->start, $c->end);

	    if ($t->strand < 0) {
	      ($start, $end) = ($slice_length - $end, $slice_length - $start);
	    }


	    next if ($end < 1 || $start > $slice_length);
	    $start = 1 unless $start > 0;
	    $end = $slice_length unless $end < $slice_length;

	    my $txt = sprintf("STOP(%s)",$t->stable_id);
	    push @markup_bins, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
	    push @markup_bins, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
	    
	  }
	}  # end foreach $t
      } else {
	foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
	  my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
	  #		  warn(join('*', 'T:', $spe, $t->stable_id, $start, $end, $t->strand, "\n"));
	  if ((my $x = $start) > -2) {
	    $x = 1 if ($x < 1);
	    my $txt = sprintf("START(%s)",$t->stable_id);
	    push @markup_bins, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
	    push @markup_bins, { 'pos' => $start + 3, 'mask' => - $codon_On, 'text' => $txt  };  
	  }

	  if ((my $x = $end) < $slice_length) {
	    $x -= 2;
	    $x = 1 if ($x < 1);
	    my $txt = sprintf("STOP(%s)",$t->stable_id);
	    push @markup_bins, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
	    push @markup_bins, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
	    
	  }
	}
	
      }
    } # if object->param('codon_display')

    my @exons = ();

    if ((my $exontype = $object->param( 'exon_display' )) ne 'off') {
      if( $exontype eq 'prediction' ){
	my( $s, $e ) = ( $as->start, $as->end );
	@exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
		   map { @{$_->get_all_Exons } }
		   @{$as->get_all_PredictionTranscripts } );
      } else {
	$exontype ='' unless( $exontype eq 'vega' or $exontype eq 'est' );
	my @genes = @{$as->get_all_Genes('', $exontype)} ;
	      
	@exons = $orthologue->{$spe} ?
	  map  { @{$_->get_all_Exons } } grep { $orthologue->{$spe}->{$_->stable_id} } @{$as->get_all_Genes('', $exontype)} :
	    map  { @{$_->get_all_Exons } } @{$as->get_all_Genes('', $exontype)} ;
      }
    }
	  
    my $ori = $object->param('exon_ori');
    if( $ori eq 'fwd' ) {
      @exons = grep{$_->seq_region_strand > 0} @exons; # Only fwd exons
    } elsif( $ori eq 'rev' ){
      @exons = grep{$_->seq_region_strand < 0} @exons; # Only rev exons
    }
      
    # Mark exons
    foreach my $e (sort {$a->{start} <=> $b->{start} }@exons) {
      if ($ass) {
	next if $e->seq_region_end < 1 || $e->seq_region_start > $slice_length;
	
      } else {
	next if $e->seq_region_end < $sstart || $e->seq_region_start > $send;
      }

      my ($start, $end) = ($e->start, $e->end);

      if ($start < 1) {
	$start = 1;
      }
      if ($end > $slice_length) {
	$end = $slice_length-1;
      }

      if ($e->strand < 0) {
	($start, $end) = ($slice_length-$end, $slice_length - $start);
      }

      #	  warn("E:".join('*', $e->start, $e->end, $e->stable_id, $e->strand, $e->seq_region_start, $e->seq_region_end, $sstrand, $start, $end));

      push @markup_bins, { 'pos' => $start, 'mask' => $exon_On, 'text' => $e->stable_id };
      push @markup_bins, { 'pos' => $end+1, 'mask' => -$exon_On, 'text' => $e->stable_id  };




      my $bin = int($start / $width);
      my $binE = int(($end-1) / $width);

      # Mark again the start of each line that the exon covers with exon style
      while ($bin < $binE) {
	$bin ++;
	my $pp = $bin * $width;
	push @markup_bins, { 'pos' => $pp, 'mask' => -$exon_On, 'mark' => 1, 'text' =>  $e->stable_id };
	push @markup_bins, { 'pos' => $pp+1, 'mask' => $exon_On, 'text' => $e->stable_id };

      }
    }

    #      warn(Dumper(\@markup_bins));

    # Mark SNPs

    my @snps = $object->param( 'snp_display' )  eq 'snp' ? @{$as->get_all_VariationFeatures} : ();
    foreach my $s (@snps) {
      my ($st, $en, $allele, $id, $mask) = ($s->start, $s->end, $s->allele_string, $s->variation_name, $snp_On);

      #	  warn("S:".join('*', $st, $en, $allele, $id, $s->strand, $sstrand));

      if ($en < $st) {
	($st, $en) = ($en, $st);
	$mask = $snp_Del;
      }
      $en ++;


      push @markup_bins, { 'pos' => $st, 'mask' => $mask, 'textSNP' => $allele, 'mark' => 0, 'snpID' => $id };
      push @markup_bins, { 'pos' => $en, 'mask' => -$mask  };


      my $bin = int(($st-1) / $width);
      my $binE = int(($en-2) / $width);
	
      while ($bin < $binE) {
	$bin ++;
	my $pp = $bin * $width + 1;
	push @markup_bins, { 'pos' => $pp, 'mask' => $mask, 'textSNP' => $allele   };
	push @markup_bins, { 'pos' => $pp-1, 'mark' => 1, 'mask' => -$mask  };
      }
    } # end foreach $s (@snps)

    #      warn(Dumper(\@markup_bins));
    my @markup  = sort {($a->{pos} <=> $b->{pos})*10 + 5*($a->{mark} <=> $b->{mark})  } @markup_bins;
    #      warn(Dumper(\@markup));

    my @ht = ();
    push @ht, $abbr;
      
    if ($object->param('line_numbering') eq 'slice') {
      if ($ass) {
	my $srt = substr($sequence, 0, $width);
	if ($srt =~ m/[ATGCN]/g) {
	  my ($oslice, $pos) = $as->get_original_seq_region_position(pos($srt) );
		  
	  push @ht, sprintf("%*s:%*u ", $max_region, $oslice->seq_region_name, $lineformat, $pos);
	} else {
	  push @ht, sprintf("%*s ", $lineformat+$max_region+1, "");
	}

      } else {
	push @ht, sprintf("%*s:%*u ", $max_region, $as->seq_region_name, $lineformat, $linenumbers[0] + 1);
      }
	  
    } else {
      if (@linenumbers) {
	push @ht, sprintf("%*u ", $lineformat, $linenumbers[0] + 1);
      }
    }
     
    my $smask = 0;

    my @title;
    my $sindex = 0;
    my $notes;

    #     warn("MARK:".Dumper(\@markup));
    for (my $i = 1; $i < (@markup); $i++) {
      my $p = $markup[$i -1];
      if ($p->{mask}) {
	$smask += $p->{mask};
	if ($p->{mask} > 0) {
	  push @title, $p->{text} if ($p->{text} ne $title[-1]);
	} else {
	  @title = grep { $_ ne $p->{text}} @title;
	}
      }
      
      if ($p->{snpID}) {
	push @$notes, sprintf("{<a href=\"/%s/snpview?snp=%s\">base %u:%s</a>}", $spe, $p->{snpID}, $p->{pos}, $p->{textSNP});
      }

      my $c = $markup[$i];
      next if ($p->{pos} == $c->{pos} && (! $c->{mark} || $p->{mask} == -8));
      
      my $w = $c->{pos} - $p->{pos};

      $w++ if ($c->{mark} && (!defined($c->{mask})));

      my $sq = $p->{mark} ? '' : substr($sequence, $p->{pos}-1, $w);


      if ($p->{mark} && ! defined($c->{mark})) {
	push @ht, $BR, $abbr;

	      
	if ($object->param('line_numbering') eq 'slice') {
	  if ($ass) {
	    my $srt = substr($sequence, $sindex, $width);
	    if ($srt =~ m/[ATGCN]/g) {
	      my ($oslice, $pos) = $as->get_original_seq_region_position( $sindex + pos($srt) );
	      push @ht, sprintf("%*s:%*u ", $max_region, $oslice->seq_region_name, $lineformat, $pos);
	    } else {
	      push @ht, sprintf("%*s ", $lineformat + $max_region + 1, "");
	    }
	    
	  } else {
	    if ($sindex < $slice_length) {
	      my $pos = $sstrand > 0 ? ($sindex + $linenumbers[0] + 1) : ($linenumbers[0] + 1 - $sindex);
	      push @ht, sprintf("%*s:%*u %s", $max_region, $as->seq_region_name, $lineformat, $pos);
	    }
	  }
		
	} else {
	  if (@linenumbers) {
	    if ($sindex < $slice_length) {
	      push @ht, sprintf("%*u %s", $lineformat, $sindex + $linenumbers[0] + 1);
	    }
	  }
	}
      }


      if (length($sq)) {
	my $tag_title = $t_set ? ($p->{textSNP} || join(':', @title)) : '';

	#  my ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On) = (1, 16, 32, 64, 128, 256);
	my $NBP = 'n';
	my $sclass = $NBP;
	
	if ($smask & 0x0F) {
	  $sclass = 'e';
	}

	if ($smask & 0x40) {
	  $sclass .= 'd';
	} elsif ($smask & 0x20) {
	  $sclass .= 's';
	} elsif ($smask & 0xF00) {
	  $sclass .= 'o';
	} elsif ($smask & 0x10) {
	  $sclass .= 'c';
	}
	  

	my $span_open;
	if ($sclass ne $NBP || $tag_title) {
	  $span_open = sprintf (qq{<span%s%s>}, 
				$sclass ne 'mn' ? qq{ id="$sclass"} : '',
				$tag_title ? qq{ title="$tag_title"} : '');
	  
	  push @ht, $span_open, $sq, "</span>";
	} else {
	  push @ht, $sq;
	}
      }

      $sindex += length($sq);

      if ($sindex % $width == 0 && length($sq) != 0) {
	if ($object->param('line_numbering') eq 'slice') {
	  if ($ass) {
	    my $srt = substr($sequence, $sindex-$width, $width);
	    my $posa = -1;
	    
	    while ($srt =~ m/[AGCT]/g) {
	      $posa = pos($srt);
	    }

	    if ($posa > 0) { 
	      my ($oslice, $pos) = $as->get_original_seq_region_position( $sindex + $posa - $width);			  
	      push @ht, sprintf(" %*s:%*u", $max_region, $oslice->seq_region_name, $lineformat, $pos);
	    } else {
	      push @ht, sprintf(" %*s", $lineformat + $max_region + 1, "");
	    }

	  } else {
	    my $pos = $sstrand > 0 ? ($sindex + $linenumbers[0]) : ($linenumbers[0] - $sindex + 2);
	    push @ht, sprintf(" %*s:%*u", $max_region, $as->seq_region_name, $lineformat, $pos);
	  }
	  
	} else {
	  if (@linenumbers) {
	    push @ht, sprintf(" %*u %s", $lineformat, $sindex + $linenumbers[0]);
	  }
	}
	
	if ($notes) {
	  push @ht, join('|', " ", @$notes);
	  $notes = undef;
	}

	push @ht, "\n";
      }
      
    }  #end for @markup

    if (@linenumbers && ($sindex % $width  != 0)) {
      if ($object->param('line_numbering') eq 'slice') {
	if ($ass) {
	  my $wd = $sindex % $width;
	  my $srt = substr($sequence, -$wd);
	  my $posa = -1;
	  while ($srt =~ m/[AGCT]/g) {
	    $posa = pos($srt);
	  }

	  if ($posa > 0) { 
	    my ($oslice, $pos) = $as->get_original_seq_region_position( $sindex + $posa - $wd);			  
	    push @ht, sprintf("%*s %*s:%*u", $width - $wd, " ", $max_region, $oslice->seq_region_name, $lineformat, $pos);
	  } else {
	    push @ht, sprintf(" %*s", $lineformat + $max_region + 1, "");
	  }
		  
	} else {
	  my $w = $width - ($sindex % $width);
	  push @ht, sprintf("%*s %*s:%*u", $w, " ", $max_region, $as->seq_region_name, $lineformat, $sindex + $linenumbers[0]);
	}
      } else {
	my $w = $width - ($sindex % $width) + $lineformat;
	push @ht, sprintf(" %*u", $w, $sindex + $linenumbers[0]);
      }
    }

    if ($notes) {
      push @ht, join('|', " ", @$notes);
    }

    push @ht, "\n";
    
    my $html = join('',@ht);

    @{$html_hash->{"${ind}_$spe"}} = split(/$BR/, $html);
    $ind ++;
  }  # end foreach?


  push @tsa, (time - $ts);

  my $hhh;

  if ($alignments_no > 1) {
    while (1) {
      my $hi;
      foreach my $k (sort keys %{$html_hash}) {
	$hi .= shift (@{$html_hash->{$k}});
      }

      $hhh .= "$hi\n";
      last if (!$hi);
    }
  } else {
    $hhh = join('', @{$html_hash->{"1_$species"}});
  }

  push @tsa, (time - $ts);

  my $key_tmpl = qq(<p><code><span id="%s">%s</span></code> %s</p>\n);

  my $KEY = '';

  if(  $object->param( 'exon_display' ) ne 'off' ){
      $KEY .= sprintf( $key_tmpl, 'e', "THIS STYLE:", "Location of selected exons ");
  }

  if(  $object->param( 'codons_display' ) ne 'off' ){
      $KEY .= sprintf( $key_tmpl, 'eo', "THIS STYLE:", "Location of START/STOP codons ");
  }

  if( $object->param( 'snp_display' )  eq 'snp'){
      $KEY .= sprintf( $key_tmpl, 'ns', "THIS STYLE:", "Location of SNPs" );
      $KEY .= sprintf( $key_tmpl, 'nd', "THIS STYLE:", "Location of deletions" );
  }

  if( $alignments_no > 1 && $object->param( 'conservation' ) ne 'off' ){
      $KEY .= sprintf( $key_tmpl, 'nc', "THIS STYLE:", "Location of conserved regions (where >75% of bases in alignments match) ");
  }


  if ($object->param('line_numbering') eq 'slice') {
      $KEY .= qq{ NOTE:     For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line };
  }

  my $Chrs;
  (my $spa = $species) =~ s/ /_/g;
  foreach my $sp ( $spa, grep {$_ ne $spa} keys %$SeqSlices) {
    $Chrs .= qq{<p><br/><b>$sp&gt;<br/></b>};

    foreach my $loc (@{$SeqSlices->{$sp}}) {
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $loc);
      $Chrs .= qq{<p><a href="/$sp/contigview?l=$region:$start-$end">$loc</a></p>};
    }
  }
  #  warn(Dumper($SeqSlices));


  #  $Chrs = qq{<p><br/><b>$sp&gt;</b>}.join("<br/>", @{$SeqSlices->{$sp}})."</p>";

  $panel->add_row( 'Marked_up_sequence', qq(
    $KEY
    $Chrs
    <pre>\n$hhh\n</pre>
  ) );

  push @tsa, (time - $ts);

  my $t2 = time;

  warn("TIMEZ: ".length($hhh).":".join('*', @tsa));

}

#---------------------------------------------------------------------------------------
sub sequence_display {
  my( $panel, $object ) = @_;

  my $slice   = $object->Obj;
  my $sstrand = $slice->strand; # SNP strand bug has been fixed in snp_display function
  my $sstart  = $slice->start;
  my $send    = $slice->end;
  my $slength = $slice->length;

  my $snps  = $object->param( 'snp_display' )  eq 'snp' ? $object->snp_display()  : [];
  my $exons = $object->param( 'exon_display' ) ne 'off' ? $object->exon_display() : [];
  my $feats = $object->highlight_display();

  # Define a formatting styles. These correspond to name/value pairs
  # in HTML style attributes
  my $style_tmpl = qq(<span style="%s" title="%s">%s</span>);
  my %styles = (
    DEFAULT =>{},
    exon    => { 'color' => 'darkred',  'font-weight' =>'bold' },
    high2   => { 'color' => 'darkblue', 'font-weight' =>'bold' },
    high1   => { 'background-color' => 'blanchedalmond' },
    snp     => { 'background-color' => '#caff70'        },
    snpexon => { 'background-color' => '#7fff00'        }
  );

  my $key_tmpl = qq(<p><code>$style_tmpl</code> %s</p>);

  my $KEY = '';

  if( @$feats ){
    my $type = "features";
    if( $feats->[0]->isa('Bio::EnsEMBL::Exon') ){$type='exons'}
    my %istyles = %{$styles{high1}};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of other $type" )
  }

  if( @$exons ){
    my %istyles = %{$styles{exon}};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of selected exons ")
  }

  if( @$snps ){
    my %istyles = %{$styles{snp}};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of SNPs" )
  }

  # Sequence markup uses a 'variable-length bin' approach.
  # Each bin has a format.
  # Allows for feature overlaps - combined formats.
  # Bins start at feature starts, and 1 + feature ends.
  # Allow for cigar strings - these split alignments into 'mini-features'.
  # A feature can span multiple bins

  # Get a unique list of all possible bin starts

  my %all_locs = ( 1=>1, $slength+1=>1 );

  foreach my $feat ( @$feats, @$exons ){
    # skip the features that were cut off by applying flanking sequence parameters
    next if $feat->seq_region_start < $sstart || $feat->seq_region_end > $send;
    my $cigar;
    $cigar = $feat->cigar_string if $feat->can('cigar_string');
    $cigar ||= $feat->length . "M"; # Fake cigar; matches length of feat
 # If the feature is on reverse strand - then count from the end
    my $fstrand = $feat->seq_region_strand;
    my $fstart  = $fstrand < 0 ? $send - $feat->seq_region_end + 1 : $feat->seq_region_start - $sstart + 1;
#    my $fstart  = $feat->seq_region_start - $sstart + 1;
    $fstart = $slength+1   if $fstart > $slength+1;
    $all_locs{$fstart} = 1 if $fstart > 0;
    my @segs = ( $cigar =~ /(\d*\D)/g ); # Split cigar into segments
    @segs = reverse @segs if $fstrand < 1; # if -ve ori, invert cigar
    foreach my $seg( @segs ) {
      my $type = chop( $seg ); # Remove seg type - length remains
      next if( $type eq 'D' ); # Ignore deletes
      $fstart += $seg;
      $fstart = $slength+1 if $fstart > $slength+1;
      $all_locs{$fstart} = 1 if $fstart > 0;
    }
  }

  foreach my $snp( @$snps ){
    my $fstart = $snp->start;
    my $fend   = $snp->end;

    if( $fstart <= $fend ) { # Deletion/replacement
      $fend ++;
    } else {                 # Insertion
      $fend = $fstart + ( $sstrand < 0 ? -2 : 2 );
    }
    $all_locs{ $fstart } = 1;
    $all_locs{ $fend   } = 1;
  }

  # Initialise bins; lengths and formats
  my @bin_locs = sort{ $a<=>$b } ( keys %all_locs );
  my %bin_idx; # A hash index of bin start locations vs pos in index

  my @bin_markup;
  for( my $i=0; $i<@bin_locs; $i++ ){
    my $bin_start  = $bin_locs[$i];
    my $bin_end    = $bin_locs[$i+1] || last;
    my $bin_length = $bin_end - $bin_start;
    $bin_idx{$bin_start} = $i;
    $bin_markup[$i] = [ $bin_length, {} ]; # Init bin, and flag as empty
  }

  # Populate bins with exons
  my %estyles       = %{$styles{exon}};
  # Populate bins with snps
  my %snpstyles     = %{$styles{snp}};
  my %snpexonstyles = %{$styles{snpexon}};


  # Populate bins with exons
  foreach my $feat( @$exons ){
    my $cigar;
    if( $feat->can('cigar_string') ){ $cigar = $feat->cigar_string }
    $cigar ||= $feat->length . "M"; # Fake cigar; matches length of feat
    my $fstrand = $feat->seq_region_strand;
    my $title = $feat->stable_id;
    my $fstart  = $fstrand < 0 ? $send - $feat->seq_region_end + 1 : $feat->seq_region_start - $sstart + 1;
    my @segs = ( $cigar =~ /(\d*\D)/g ); # Segment cigar
    if( $fstrand < 1 ){ @segs = reverse( @segs ) } # if -ve ori, invert cigar
    foreach my $seg( @segs ){
      my $type = chop( $seg ); # Remove seg type - length remains
      next if( $type eq 'D' ); # Ignore deletes
      my $fend = $fstart + $seg;
      my $idx_start = $fstart > 0 ? $bin_idx{$fstart} : $bin_idx{1};
      my $idx_end   = ( $bin_idx{$fend} ? $bin_idx{$fend} : @bin_markup ) -1;
      $fstart += $seg;
      next if $type ne 'M'; # Only markup matches
      # Add styles to affected bins
      my %istyles = %{$styles{high1}};
      foreach my $bin( @bin_markup[ $idx_start .. $idx_end ] ){
        map{ $bin->[1]->{$_} = $estyles{$_} } keys %estyles;
        $bin->[2] = join( ' : ', $bin->[2]||(), $title||() );
      }
    }
  }

  # Populate bins with highlighted features
  foreach my $feat( @$feats ){
      # skip the features that were cut off by applying flanking sequence parameters
    next if ($feat->end < $sstart || $feat->start > $send);
    my $cigar;
    if( $feat->can('cigar_string') ){ $cigar = $feat->cigar_string }
    $cigar ||= $feat->length . "M"; # Fake cigar; matches length of feat
    my $fstrand = $feat->seq_region_strand;
    my $title;
    if ($feat->can('stable_id')) { $title = $feat->stable_id; }

    my $fstart  = $fstrand < 0 ? $send - $feat->seq_region_end + 1 : $feat->seq_region_start - $sstart + 1;
    my @segs = ( $cigar =~ /(\d*\D)/g ); # Segment cigar
    if( $fstrand < 1 ){ @segs = reverse( @segs ) } # if -ve ori, invert cigar
    foreach my $seg( @segs ){
    my $type = chop( $seg ); # Remove seg type - length remains
    next if( $type eq 'D' ); # Ignore deletes
    my $fend = $fstart + $seg;
    my $idx_start = $fstart > 0 ? $bin_idx{$fstart} : $bin_idx{1};
    my $idx_end   = ( $bin_idx{$fend} ? $bin_idx{$fend} : @bin_markup ) -1;
    $fstart += $seg;
    next if $type ne 'M'; # Only markup matches
    # Add styles to affected bins
    my %istyles = %{$styles{high1}};
    foreach my $bin( @bin_markup[ $idx_start..$idx_end ] ){
      map{ $bin->[1]->{$_} = $istyles{$_} } keys %istyles;
        if ($title) {
        if (defined (my $alt = $bin->[2])) {
            if (! grep {$_ eq $title} split(/ : /, $alt) ) {
            $bin->[2] = "$alt:$title";
            }
        } else {
            $bin->[2] = $title;
        }
        }
    }
    }
  }

  foreach my $snp( @$snps ){
    my( $fstart, $fend ) = ( $snp->start, $snp->end );
    if($fstart > $fend) { # Insertion
      $fstart = $fstart - 2 if $sstrand < 0;
    }

    my $idx_start = $bin_idx{$fstart};
    my $bin = $bin_markup[$idx_start];
    my %usestyles = ( $bin->[1]->{'background-color'} ?  %snpexonstyles : %snpstyles );
    map{ $bin->[1]->{$_} = $usestyles{$_} } keys %usestyles;
    my $allele = $snp->allele_string;

    if ($sstrand < 0) {
# Ig gene is reverse strand we need to reverse parts of allele, i.e AGT/- should become TGA/-
    my @av = split(/\//, $allele);
    $allele = '';

    foreach my $aq (@av) {
        $allele .= reverse($aq).'/';
    }

    $allele =~ s/\/$//;
    }

# if snp is on reverse strand - flip the bases
    if( $snp->strand < 0 ){
      $allele =~ tr/ACGTacgt/TGCAtgca/;
    }
    $bin->[2] = $allele || '';
    $bin->[3] = ($snp->end > $snp->start) ? 'ins' : 'del';
    $bin->[4] = $snp->{variation_name};
  }

  # If strand is -ve ori, invert bins
# SNP strand bug has been fixed in snp_display function : no need to check for the strand
#  if( $sstrand < 1 ){ @bin_markup = reverse( @bin_markup ) }

  # Turn the 'bin markup' style hashes into style templates
  foreach my $bin( @bin_markup ){
    my %istyles = %{$bin->[1]};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    my $title = $bin->[2] || '';
    $bin->[1] = sprintf( $style_tmpl, $style, $title, '%s' );
  }

  # Let's do the markup!
  my $markedup_seq = '';
  my $seq     = $slice->seq;
  my $linelength  = 60; # TODO: retrieve with method?
  my $length = length( $seq );
  my @linenumbers = $object->line_numbering();
  my $numdir = ($linenumbers[0]||0)<($linenumbers[1]||0)?1:-1;
  my( $numlength ) = sort{$b<=>$a} map{length($_)} @linenumbers;
  $numlength ||= '';
  my $numtmpl   = "%${numlength}d ";

  my $i = 0;

  while( $i < $length ){ # Loop over length of sequence

    if( @linenumbers ){ # Deal with line numbering (start-of-line)
      my $num = $i + 1;
      if( $numdir > 0 ){ $num = $linenumbers[0] + $num - 1 } #Increasing nums
      else             { $num = $linenumbers[0] - $num + 1 } #Decreasing nums
      $markedup_seq .= sprintf($numtmpl, $num )
    }

    my $j = 0;
    my (@var_list) = (); # will contain the info about the alleles in the form |base 3456:A/G
    while( $j < $linelength ){
      my $markup = shift @bin_markup|| last;
      my( $n, $tmpl, $title, $type, $snp_id ) = @$markup; # Length and template of markup
      if (defined($type)) {
    # atm, it can only be 'ins' or 'del' to indicate the type of a variation
    # in case of deletion we highlight flanked bases, and actual region where some bases are missing located at the right flank
      my $ind = ($type eq 'ins') ? $i+$j : $i+$j+1;
      push @var_list, qq({<a href="/@{[$object->species]}/snpview?snp=$snp_id">base $ind:$title</a>});
    }
      if( ! $n ){ next }
      if( $n > $linelength-$j ){ # Markup extends over line end. Trim for next
        unshift( @bin_markup, [ $n-($linelength-$j), $tmpl ] );
        $n = $linelength-$j;
      }
      $markedup_seq .= sprintf( $tmpl, substr( $seq, $i+$j, $n) );
      $j += $n;
    }
    #$markedup_seq .= "\n".substr( $seq, $i+1, $linelength ); # DEBUG
    $i += $linelength;

    if( @linenumbers ){ # Deal with line numbering (end-of-line)
      my $incomplete = $linelength-$j;
      $markedup_seq .= ' ' x $incomplete;
      my $num = $i - $incomplete;
      if( $numdir > 0 ){ $num = $linenumbers[0] + $num - 1 } #Increasing nums
      else             { $num = $linenumbers[0] - $num + 1 } #Decreasing nums
      $markedup_seq .= " $num";
    }
    if (@var_list) {
      $markedup_seq .= "&nbsp;|".join(qq{ |}, @var_list);
    }
    $markedup_seq .= "\n";
  }
  $panel->add_row( 'Marked_up_sequence', qq(
    $KEY
    <pre>&gt;@{[ $slice->name ]}\n$markedup_seq</pre>
  ) );
}


1;
