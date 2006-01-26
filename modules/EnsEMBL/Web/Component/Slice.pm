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


sub sequence_display {
  my( $panel, $object ) = @_;

  my $object_id; 
  my $orthologue;

  if (! $object->isa("Bio::EnsEMBL::Slice")) {
      $object_id = $object->stable_id;

#      my $ohash = $object->get_homology_matches('ENSEMBL_ORTHOLOGUES');
#      foreach my $k (keys %$ohash) {
#	  (my $m = $k) =~ s/ /_/g;
#	  %{$orthologue->{$m}} = map {$_ => 1} keys %{$ohash->{$k}};
#      }
      $orthologue->{ $object->species }->{$object_id} = 1;
#      warn(Data::Dumper::Dumper($orthologue));
      $object = $object->get_slice_object();
  }

  my $slice   = $object->Obj;
  my $sstrand = $slice->strand; # SNP strand bug has been fixed in snp_display function
  my $sstart  = $slice->start;
  my $send    = $slice->end;
  my $slength = $slice->length;

  my $species = $object->species;
  my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");

  my $query_slice= $query_slice_adaptor->fetch_by_region($slice->coord_system_name, $slice->seq_region_name, $slice->start, $slice->end);
  my $comparadb = $object->database('compara');

  my $aselect = $object->param("RGselect") || 'NONE';

  my $width = $object->param("display_width") || 60;
  my @slice_display;
  my @SEQ = ();
  my $DNA;
  my $SeqDNA;
  my @tsa;
  my $ts = time;
  my @slice_seq;
  my $alignments_no = 1;

  if ($aselect eq 'NONE') {
      push @slice_display, $slice;
      my $spe = $object->species;
      $SeqDNA->{$spe} = $slice->seq;
  } else {
      my ($aID, $aType);
      my @sarray;
      my @selarray;
      
      if( $aselect =~ /^(BLASTZ_NET)_(.+)/) {
	  $aType = $aID = $1;
	  push @sarray, $2;
	  push @selarray, $2;
      } else {
	  $aID = $aselect;
	  $aType = 'MLAGAN';
	  my %shash = $object->species_defs->multi($aID, $species);
	  push @sarray, keys %shash;
	  push @selarray , $object->param("ms_$aID");
      }

      my @s_array;
      foreach my $sp ($species, @sarray) {
	  $sp =~ s/_/ /g;
	  push @s_array, $sp;
      }
      my @sel_array;
      foreach my $sp ($species, @selarray) {
	  $sp =~ s/_/ /g;
	  push @sel_array, $sp;
      }

      my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
      my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases($aType, \@s_array );

      my $asa = $comparadb->get_adaptor("AlignSlice" );
      
      my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set);
      push @slice_display, $slice;
      (my $sss = $species) =~ s/_/ /g;
      push @slice_display, grep { $_->genome_db->name ne $sss } @{$align_slice->get_all_Slices(@sel_array)};

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

	  if ($ass && $sstrand < 0) {
	      $sq =~ tr/ACGTacgt/TGCAtgca/;
	      $sq = reverse($sq);
	  }
	 
	  $SeqDNA->{$spe} =$sq." ";
	  foreach my $s (split(//, $sq)) {
	      $SEQ[$idx++]->{uc($s)} ++;
	  }

#	  push @lsa, (time - $ff);
#	  while ($sq =~ m/(\-+\w)/gc) {
#	      warn ("M:$-[0]:".(pos($sq) - $-[0] + 1)."\n");
#	  }
#	  push @lsa, (time - $ff);
	  warn("\t$spe: ".join('*', @lsa)."\n");
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
	      my $sq = $SeqDNA->{$spe};
	
	      my $f = 0;
	      my $ms = 0;
	      my @csrv = ();
	      foreach my $sym (split(//, $sq)) {
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
  }
 
#  warn("DNA:".Dumper($DNA));

  my $t1 = time;
#  my ($exon_On, $snp_On, $snp_Del, $cs_On, $codon_On, $ins_On) = (1, 32, 16, 8, 128, 256);

  my ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On) = (1, 16, 32, 64, 128, 256);
  my @linenumbers = $object->line_numbering();
  my ( $lineformat ) = sort{$b<=>$a} map{length($_)} @linenumbers;
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
      my $sq = $SeqDNA->{$spe};
      
      my $csrv = $DNA->{$spe};

      my $slice_length = length($sq);
      warn("SLENGTH:$spe:$slice_length\n");
#      warn("SEQ: $sq");
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


#      foreach my $g ( @{$as->get_all_Genes()}) {
#	  warn("GENE : $g");
#	  foreach my $k (sort keys %$g) {
#	      warn("$k => $g->{$k}");
#	  }
#      }

      while ($sq =~ m/(\-+[\w\s])/gc) {
	  my $txt = sprintf("%d bp", pos($sq) - $-[0] - 1);
	  push @markup_bins, { 'pos' => $-[0]+1, 'mask' => $ins_On, 'text' => $txt };
	  push @markup_bins, { 'pos' => pos($sq), 'mask' => -$ins_On, 'text' => $txt };
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
      
      if (0) {
      my @transcripts = 
	  $object->param( 'codons_display' ) ne 'off' ? 
	    ( $orthologue ?  
	      map  { @{$_->get_all_Transcripts } } grep { $orthologue->{$spe}->{$_->stable_id} } @{$as->get_all_Genes()} :
	      map  { @{$_->get_all_Transcripts } } @{$as->get_all_Genes()} 

	      )
	    : ();
  }

      my @transcripts =  map  { @{$_->get_all_Transcripts } } @{$as->get_all_Genes()} ;
      if ($ass) {
	  foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
#	      warn(join('*', 'T:', $spe, $t->stable_id, $t->coding_region_start, $t->coding_region_end, $t->strand));
	      next if (! defined($t->translation));

	      foreach my $c (@{$t->translation->all_start_codon_mappings || []}) {
		  warn(join('*', "SCod:", $spe, $t->stable_id, $c->start, $c->end, $t->strand, "\n"));

		  my ($start, $end) = ($c->start, $c->end);
#		  if ($t->strand < 0 && $sstrand > 0) {
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
	  }
      } else {
	  foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
	      my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
		  warn(join('*', 'T:', $spe, $t->stable_id, $start, $end, $t->strand, "\n"));
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

      my @exons = ();

      if ((my $exontype = $object->param( 'exon_display' )) ne 'off') {
#	  warn("GET E");
	  if( $exontype eq 'prediction' ){
	      my( $s, $e ) = ( $as->start, $as->end );
	      @exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
			 map { @{$_->get_all_Exons } }
			 @{$as->get_all_PredictionTranscripts } );
	  } else {
	      $exontype ='' unless( $exontype eq 'vega' or $exontype eq 'est' );
#	      warn("GENES: ".join('*', @{$as->get_all_Genes('', $exontype)}));

	      my @genes = @{$as->get_all_Genes('', $exontype)} ;
#	      foreach my $g (@genes) {
#		  warn("G:".$g->stable_id);
#	      }
	      
	      @exons = $orthologue->{$spe} ?
		  map  { @{$_->get_all_Exons } } grep { $orthologue->{$spe}->{$_->stable_id} } @{$as->get_all_Genes('', $exontype)} :
		  map  { @{$_->get_all_Exons } } @{$as->get_all_Genes('', $exontype)} ;
#	      warn("EXONS: ".scalar(@exons));
	  }
      }
	  
#      warn("GREP E");
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

	  warn("S:".join('*', $st, $en, $allele, $id, $s->strand, $sstrand));


	  if ($sstrand < 0) {
	      if ($ass) {
		  $st = $slice_length - $st + 1;
		  $en = $slice_length - $en + 1;
	      }
	      if ($s->strand < 0) {
		  my @al = split('/', $allele);
	      
		  $allele = reverse(shift(@al));
		  foreach my $al (@al) {
		      $allele .= "/".reverse($al);
		  }
		  $allele =~ tr/ACGTacgt/TGCAtgca/;
	      } else {
#		  $allele =~ tr/ACGTacgt/TGCAtgca/;
	      }
	  } else {
	      if ($s->strand < 0) {
		  $allele =~ tr/ACGTacgt/TGCAtgca/;
	      }
	  }
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
      }

#      warn(Dumper(\@markup_bins));
      my @markup  = sort {($a->{pos} <=> $b->{pos})*10 + 5*($a->{mark} <=> $b->{mark})  } @markup_bins;
#      warn(Dumper(\@markup));

      my @ht = ();
      push @ht, $abbr;
      
      if (@linenumbers) {
	  push @ht, sprintf("%*u ", $lineformat, $linenumbers[0] + 1);
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

	  my $sq = $p->{mark} ? '' : substr($sq, $p->{pos}-1, $w);

	  if ($p->{mark} && ! defined($c->{mark})) {
	      push @ht, $BR, $abbr;

	      if (@linenumbers) {
		  push @ht, sprintf("%*u %s", $lineformat, $sindex + $linenumbers[0] + 1);
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
	      if (@linenumbers) {
		  push @ht, sprintf(" %*u", $lineformat, $sindex + $linenumbers[0]);
		  if ($notes) {
		      push @ht, join('|', " ", @$notes);
		      $notes = undef;
		  }
	      } else {
		  if ($notes) {
		      push @ht, join('|', " ", @$notes);
		      $notes = undef;;
		  }
	      }
	      push @ht, "\n";
	  }
       
      }
      if (@linenumbers && ($sindex % $width  != 0)) {
	  my $w = $width - ($sindex % $width) + $lineformat;
	  push @ht, sprintf(" %*u", $w, $sindex + $linenumbers[0]);
	  if ($notes) {
	      push @ht, join('|', " ", @$notes);
	  }
      } else {
	  if ($notes) {
	      push @ht, join('|', " ", @$notes);
	  }
      }

#      push @ht, "</span><Br/>\n";
      push @ht, "\n";

#      warn(Dumper(\@ht));

      my $html = join('',@ht);

      @{$html_hash->{"${ind}_$spe"}} = split(/$BR/, $html);
      $ind ++;

  
  }


#  warn(Dumper($html_hash));
      push @tsa, (time - $ts);

  my $hhh;

  if ($alignments_no > 1) {
      while (1) {
	  my $hi;
	  foreach my $k (sort keys %{$html_hash}) {
	      $hi .= shift (@{$html_hash->{$k}});
	  }

#	  $hhh .= "$hi<BR/>\n";
	  $hhh .= "$hi\n";
	  last if (!$hi);
      }
  } else {
      warn("KEYS: ".join('*', sort keys %{$html_hash}));
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

  $panel->add_row( 'Marked_up_sequence', qq(
    $KEY
    <pre><b>&gt;@{[ $slice->name ]}</b>\n$hhh\n</pre>
  ) );

      push @tsa, (time - $ts);

  my $t2 = time;

#  warn("TIME: ".join('*', $t2 - $t1));

  warn("TIMEZ: ".length($hhh).":".join('*', @tsa));

}

1;
