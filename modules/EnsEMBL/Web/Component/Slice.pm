package EnsEMBL::Web::Component::Slice;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::AlignStrainSlice;
no warnings "uninitialized";

my ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On) = (1, 16, 32, 64, 128, 256);
my $BR = '###';

sub generateHTML {
  my ($object, $hRef, $max_position, $max_label, $linenumber_ref) = @_;

  my  @linenumbers = $linenumber_ref ? @$linenumber_ref:  $object->get_slice_object->line_numbering;
  my $lineformat  =  length($max_position); #sort{$b<=>$a} map{length($_)} @linenumbers;

  if (@linenumbers) {
      $linenumbers[0] --;
  }
  my $width = $object->param("display_width") || 60;
  my $line_numbering = $object->param('line_numbering');
  my $t_set = $object->param('title_display') ne 'off' ? 1 : 0 ;

  foreach my $species (keys %$hRef) {
    my $sequence = $hRef->{$species}->{sequence};
    my $slice = $hRef->{$species}->{slice};
    my $slice_length = $hRef->{$species}->{slice_length};
    my @markup = sort {($a->{pos} <=> $b->{pos})*10 + 5*($a->{mark} <=> $b->{mark})  } @{$hRef->{$species}->{markup}};

# Get abbriviated species name (first letters of each word 
    my @fl = $species =~ m/^(.)|_(.)/g;
    my $abbr = join("",@fl, " ");

    my $html = $abbr;


# If the line numbering is on - then add the index of the first position
    if ($line_numbering eq 'slice') {
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
# In case of AlignSlice we show the position of the first defined nucleotide
        my $segment = substr($sequence, 0, $width);
        if ($segment =~ m/[ATGCN]/g) {
          my ($oslice, $pos) = $slice->get_original_seq_region_position(pos($segment) );
          $html .= sprintf("%*s:%*u ", $max_label, $oslice->seq_region_name, $lineformat, $pos);
        } else {
          $html .= sprintf("%*s ", $lineformat+$max_label+1, "");
        }
      } else {
        $html .= sprintf("%*s:%*u ", $max_label, $slice->seq_region_name, $lineformat, $linenumbers[0] + 1);
      }
    } elsif ( $line_numbering eq 'sequence') {
      $html .= sprintf("%*u ", $lineformat, $linenumbers[0] + 1);
    }


# And now the hard bit 
    my $smask = 0; # Current span mask
    my @title; # Array of span notes
    my $sindex = 0;
    my $notes; # Line notes - at the moment info on SNPs present on the line

    for (my $i = 1; $i < (@markup); $i++) {

# First take the preceeding bin 
      my $p = $markup[$i -1];

# If the bin has a mask apply it to the global mask
# If the bin mask positive then it is the start of a highlighted region - add the bin text to the span notes if it is not there already
# Otherwise it is the end of a highlighted region - remove the bin text from the span notes
 
      if ($p->{mask}) {
        $smask += $p->{mask};
        if ($p->{mask} > 0) {
          push @title, $p->{text} if ($p->{text} ne $title[-1]);
        } else {
          @title = grep { $_ ne $p->{text}} @title;
        }
      }

# If the bin has snpID then we need to display SNP's info at the end of the line
      if ($p->{snpID}) {
        push @$notes, sprintf("{<a href=\"/%s/snpview?snp=%s\">base %u:%s</a>}", $species, $p->{snpID}, $p->{pos}, $p->{textSNP});
      }

# And now onto the current bin
      my $c = $markup[$i];

# Move over to the next bin if the current bin annotates the same bp and does not mark end of line
# The idea is that several regions might have edges in the same position. So we need to take into account 
# which ones start in the position and which ones end. To do this we process the mask field of all the bins located in the position
# before adding the actual sequence.
 
      next if ($p->{pos} == $c->{pos} && (! $c->{mark}));

# Get the width of the sequence region to display
      my $w = $c->{pos} - $p->{pos};

# If it is the EOL/BOL defining bin then we need to increment the width to get the right region length
      $w++ if ($c->{mark} && (!defined($c->{mask})));

# If the preceeding bin has 'mark' set it means the current bin is BOL - ie just moving onto the next line
# Otherwise it is EOL symbol - we need to get the region sequence; the region starts from the previous bin position 
      my $sq = $p->{mark} ? '' : substr($sequence, $p->{pos}-1, $w);

# If the previous bin was EOL then this is the time to add the line break BR and the start of the new line - species abbreviation  and line numbering
      if ($p->{mark} && ! defined($c->{mark})) {
        $html .= "$BR$abbr";

        if ($line_numbering eq 'slice') {
	  if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
            my $srt = substr($sequence, $sindex, $width);
            if ($srt =~ m/[ATGCN]/g) {
              my ($oslice, $pos) = $slice->get_original_seq_region_position( $sindex + pos($srt) );
              $html .= sprintf("%*s:%*u ", $max_label, $oslice->seq_region_name, $lineformat, $pos);
            } else {
              $html .= sprintf("%*s ", $lineformat + $max_label + 1, "");
            }
          } else {
            if ($sindex < $slice_length) {
              my $pos = $slice->strand > 0 ? ($sindex + $linenumbers[0] + 1) : ($linenumbers[0] + 1 - $sindex);
              $html .= sprintf("%*s:%*u %s", $max_label, $slice->seq_region_name, $lineformat, $pos);
            }
          }
        } elsif ($line_numbering eq 'sequence') {
          if ($sindex < $slice_length) {
            $html .= sprintf("%*u %s", $lineformat, $sindex + $linenumbers[0] + 1);
          }
        }
      }

# Are we about to display some sequence ? 
# Then check whether the region should be highlighted and if it the case  put it into <span> tag
      if (length($sq)) {
# If 'show title' is on and there is some span note add it to the span
        my $tag_title = $t_set ? ($p->{textSNP} || join(':', @title)) : '';

# Now analyze the state of the global span mask and choose appropriate span class from ensembl.css
# At the moment the highlight works on two levels : background colour and font colour
# Font colour indicates exons/introns and background colour highlights all other features which sounds a bit messy but
# actually works out quite nicely 
  
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

        if (($sclass ne $NBP) || $tag_title) {
          $html .= sprintf (qq{<span%s%s>%s</span>},
                                $sclass ne 'mn' ? qq{ id="$sclass"} : '',
                                $tag_title ? qq{ title="$tag_title"} : '', $sq);
        } else {
          $html .= $sq;
        }
      }

      $sindex += length($sq);

# Ok, we have displayed the sequence, now is time to add the line numbering and the line notes if any
      if ($sindex % $width == 0 && length($sq) != 0) {
        if ($line_numbering eq 'slice') {
# In case of AlignSlice display the position of the last meaningful bp in the line
          if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
            my $srt = substr($sequence, $sindex-$width, $width);
            my $posa = -1;

            while ($srt =~ m/[AGCT]/g) {
              $posa = pos($srt);
            }

            if ($posa > 0) {
              my ($oslice, $pos) = $slice->get_original_seq_region_position( $sindex + $posa - $width);
              $html .= sprintf(" %*s:%*u", $max_label, $oslice->seq_region_name, $lineformat, $pos);
            } else {
              $html .= sprintf(" %*s", $lineformat + $max_label + 1, "");
            }
          } else {
            my $pos = $slice->strand > 0 ? ($sindex + $linenumbers[0]) : ($linenumbers[0] - $sindex + 2);
            $html .= sprintf(" %*s:%*u", $max_label, $slice->seq_region_name, $lineformat, $pos);
          }
        } elsif( $line_numbering eq 'sequence') {
          $html .= sprintf(" %*u %s", $lineformat, $sindex + $linenumbers[0]);
        }

        if ($notes) {
          $html .= join('|', " ", @$notes);
          $notes = undef;
        }
	$html .= "\n";
      }
    }

# All the markup bins have been processed now display any leftovers
    if (($sindex % $width)  != 0) {
      if ($line_numbering eq 'slice') {
        if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
          my $wd = $sindex % $width;
          my $srt = substr($sequence, -$wd);
          my $posa = -1;
          while ($srt =~ m/[AGCT]/g) {
            $posa = pos($srt);
          }

          if ($posa > 0) {
            my ($oslice, $pos) = $slice->get_original_seq_region_position( $sindex + $posa - $wd);
            $html .= sprintf("%*s %*s:%*u", $width - $wd, " ", $max_label, $oslice->seq_region_name, $lineformat, $pos);
          } else {
            $html .= sprintf(" %*s", $lineformat + $max_label + 1, "");
          }
        } else {
          my $w = $width - ($sindex % $width);
          $html .= sprintf("%*s %*s:%*u", $w, " ", $max_label, $slice->seq_region_name, $lineformat, $sindex + $linenumbers[0]);
        }
      } elsif($line_numbering eq 'sequence') {
        my $w = $width - ($sindex % $width) + $lineformat;
        $html .= sprintf(" %*u", $w, $sindex + $linenumbers[0]);
      }
    }

    if ($notes) {
      $html .= join('|', " ", @$notes);
    }

    $html .= "\n";

# Now $html holds ready html for the $species
# To display multiple species aligned line by line here we split the species html on $BR symbol
# so later we can pick the html line by line from each species in turn
    @{$hRef->{$species}->{html}} = split /$BR/, $html;
  }

  my $html = '';
  if (scalar(keys %$hRef) > 1) {
    while (1) {
      my $line_html = '';
      foreach my $species (sort keys %{$hRef}) {
        $line_html .= shift @{$hRef->{$species}->{html}};
      }
      $html .= "$line_html\n";
      last if (!$line_html);
    }
  } else {
    $html = join '', @{$hRef->{ $object->species }->{html}};
  }

  return $html;
}

sub markupSNPs {
  my ($object, $hRef) = @_;

  my $width = $object->param("display_width") || 60;
  foreach my $species (keys %$hRef) {
    my $slice =  $hRef->{$species}->{slice};

    foreach my $s (@{$slice->get_all_VariationFeatures || []}) {
      my ($st, $en, $allele, $id, $mask) = ($s->start, $s->end, $s->allele_string, $s->variation_name, $snp_On);
      if ($en < $st) {
        ($st, $en) = ($en, $st);
        $mask = $snp_Del;
      }
      $en ++;

      push @{$hRef->{$species}->{markup}}, { 'pos' => $st, 'mask' => $mask, 'textSNP' => $allele, 'mark' => 0, 'snpID' => $id };
      push @{$hRef->{$species}->{markup}}, { 'pos' => $en, 'mask' => -$mask  };

      my $bin = int(($st-1) / $width);
      my $binE = int(($en-2) / $width);

      while ($bin < $binE) {
        $bin ++;
        my $pp = $bin * $width + 1;
        push @{$hRef->{$species}->{markup}}, { 'pos' => $pp, 'mask' => $mask, 'textSNP' => $allele   };
        push @{$hRef->{$species}->{markup}}, { 'pos' => $pp-1, 'mark' => 1, 'mask' => -$mask  };
      }
    } # end foreach $s (@snps)
  }
}

sub markupExons {
  my ($object, $hRef) = @_;

  my $width = $object->param("display_width") || 60;
  foreach my $species (keys %$hRef) {
    my $sequence = $hRef->{$species}->{sequence};
    my $slice =  $hRef->{$species}->{slice};
    my $slice_length =  $hRef->{$species}->{slice_length};
    my @exons;

    my $exontype = $object->param( 'exon_display' );
    if( $exontype eq 'prediction' ){
      my( $s, $e ) = ( $slice->start, $slice->end );
      @exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
                   map { @{$_->get_all_Exons } }
                   @{$slice->get_all_PredictionTranscripts } );
    } else {
      $exontype ='' unless( $exontype eq 'vega' or $exontype eq 'est' );
      @exons = ($species eq $object->species) ?
          map  { @{$_->get_all_Exons } } grep { $_->stable_id eq $object->stable_id } @{$slice->get_all_Genes('', $exontype)} :
          map  { @{$_->get_all_Exons } } @{$slice->get_all_Genes('', $exontype)} ;
    }

    my $ori = $object->param('exon_ori');
    if( $ori eq 'fwd' ) {
      @exons = grep{$_->seq_region_strand > 0} @exons; # Only fwd exons
    } elsif( $ori eq 'rev' ){
      @exons = grep{$_->seq_region_strand < 0} @exons; # Only rev exons
    }

    # Mark exons
    foreach my $e (sort {$a->{start} <=> $b->{start} }@exons) {
      next if $e->seq_region_end < $slice->start || $e->seq_region_start > $slice->end;
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

      push @{$hRef->{$species}->{markup}}, { 'pos' => $start, 'mask' => $exon_On, 'text' => $e->stable_id };
      push @{$hRef->{$species}->{markup}}, { 'pos' => $end+1, 'mask' => -$exon_On, 'text' => $e->stable_id  };

      my $bin = int($start / $width);
      my $binE = int(($end-1) / $width);

     # Mark again the start of each line that the exon covers with exon style
      while ($bin < $binE) {
        $bin ++;
        my $pp = $bin * $width;
        push @{$hRef->{$species}->{markup}}, { 'pos' => $pp, 'mask' => -$exon_On, 'mark' => 1, 'text' =>  $e->stable_id };
        push @{$hRef->{$species}->{markup}}, { 'pos' => $pp+1, 'mask' => $exon_On, 'text' => $e->stable_id };
      }
    }
  }
}

sub markupCodons {
  my ($object, $hRef) = @_;

  foreach my $species (keys %$hRef) {
    my $sequence = $hRef->{$species}->{sequence};
    my $slice =  $hRef->{$species}->{slice};
    my $slice_length =  $hRef->{$species}->{slice_length};

    my @transcripts =  map  { @{$_->get_all_Transcripts } } @{$slice->get_all_Genes()} ;
    if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
      foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
        next if (! defined($t->translation));

	# Mark START codons
        foreach my $c (@{$t->translation->all_start_codon_mappings || []}) {
          my ($start, $end) = ($c->start, $c->end);
          if ($t->strand < 0) {
            ($start, $end) = ($slice_length - $end, $slice_length - $start);
          }

          next if ($end < 1 || $start > $slice_length);
          $start = 1 unless $start > 0;
          $end = $slice_length unless $end < $slice_length;

          my $txt = sprintf("START(%s)",$t->stable_id);
          push @{$hRef->{$species}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$species}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }

	# Mark STOP codons
        foreach my $c (@{$t->translation->all_end_codon_mappings ||[]}) {
          my ($start, $end) = ($c->start, $c->end);
          if ($t->strand < 0) {
            ($start, $end) = ($slice_length - $end, $slice_length - $start);
          }
          next if ($end < 1 || $start > $slice_length);
          $start = 1 unless $start > 0;
          $end = $slice_length unless $end < $slice_length;

          my $txt = sprintf("STOP(%s)",$t->stable_id);
          push @{$hRef->{$species}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$species}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }  # end foreach $t
    } else { # Normal Slice
      foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
        my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
        if ((my $x = $start) > -2) {
          $x = 1 if ($x < 1);
          my $txt = sprintf("START(%s)",$t->stable_id);
          push @{$hRef->{$species}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$species}->{markup}}, { 'pos' => $start + 3, 'mask' => - $codon_On, 'text' => $txt  };
        }

        if ((my $x = $end) < $slice_length) {
          $x -= 2;
          $x = 1 if ($x < 1);
          my $txt = sprintf("STOP(%s)",$t->stable_id);
          push @{$hRef->{$species}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$species}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }
    }
  }
}

sub markupConservation {
  my ($object, $hRef, $consArray) = @_;
 
  return unless (scalar(keys %$hRef) > 1);
# Regions where more than 50% of bps match considered `conserved`
  my $consThreshold = int((scalar(keys %$hRef) + 1) / 2);

  my $width = $object->param("display_width") || 60;
 
# Now for each bp in the alignment identify the nucleotides with scores above the threshold.
# In theory the data should come from a database. 
  foreach my $nt (@$consArray) {
    $nt->{S} = join('', grep {$nt->{$_} > $consThreshold} keys(%{$nt}));
    $nt->{S} =~ s/[-.N]//; # here we remove different representations of nucleotides from  gaps and undefined regions : 
  }

  foreach my $species (keys %$hRef) {
    my $sequence = $hRef->{$species}->{sequence};

    my $f = 0;
    my $ms = 0;
    my @csrv = ();
    my $idx = 0;

    foreach my $sym (split(//, $sequence)) {
      if (uc ($sym) eq $consArray->[$idx++]->{S}) {
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

    foreach my $c (@csrv) {
      push @{$hRef->{$species}->{ markup }}, { 'pos' => $c->[0], 'mask' => $cs_On };
      if ($c->[1] % $width == 0) {
	push @{$hRef->{$species}->{ markup }}, { 'pos' => $c->[1]+1, 'mask' => -$cs_On };
      } else {
	push @{$hRef->{$species}->{ markup }}, { 'pos' => $c->[1], 'mask' => -$cs_On };
      }
    }
  }
}

sub markupInit {
  my ($object, $slices, $hRef) = @_;

  my ($species, @conservation);
  my $max_position = 0;
  my $max_label = -1;

  my $slice_length = length($slices->[0]->seq) + 1 ;
  my $width = $object->param("display_width") || 60;

  foreach my $slice (@$slices) {
    my $sequence = $slice->seq;
    if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
      ($species = $slice->seq_region_name) =~ s/ /\_/g;
      foreach my $uSlice (@{$slice->get_all_underlying_Slices}) {
        next if ($uSlice->seq_region_name eq 'GAP');
        push @{$hRef->{$species}->{slices}}, $uSlice->name;
        if ( (my $label_length = length($uSlice->seq_region_name)) > $max_label) {
          $max_label = $label_length;
        }
        $max_position = $uSlice->start if ($uSlice->start > $max_position);
        $max_position = $uSlice->end if ($uSlice->end > $max_position);
      }
    } else {
      $species = $object->species;
      $max_position = $slice->start if ($slice->start > $max_position);
      $max_position = $slice->end if ($slice->end > $max_position);
      if ( (my $label_length = length($slice->seq_region_name)) > $max_label) {
        $max_label= $label_length;
      }
      push @{$hRef->{$species}->{slices}}, $slice->name;
    }
    $hRef->{$species}->{slice} = $slice;
    $hRef->{$species}->{sequence} = $sequence . ' ';
    $hRef->{$species}->{slice_length} = $slice_length;

    # Now put some initial sequence marking
    # Mark final bp
    my @markup_bins = ({ 'pos' => $slice_length, 'mark' => 1 });

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

    $hRef->{$species}->{markup} = \@markup_bins;

# And in case the conservation markup is switched on - get conservation scores for each basepair in the alignment.
# In future the conservation scores will come out of a database and this will be removed
    if ( $object->param("conservation") ne 'off') {
      my $idx = 0;
      foreach my $s (split(//, $sequence)) {
        $conservation[$idx++]->{uc($s)} ++;
      }
    }
  }

  return ($max_position, $max_label, \@conservation);
}


sub align_sequence_display {
  my( $panel, $object ) = @_;
  my $slice   = $object->get_slice_object->Obj;
  my @sliceArray;

# Get the alignment configuration 

# First get the selected alignment
  my $selectedAlignment = $object->param("RGselect") || 'NONE';

# If 'No alignment' selected then we just display the original sequence as in geneseqview
  if ($selectedAlignment eq 'NONE') {
    push @sliceArray, $slice;
  } else {
    my $compara_db = $object->database('compara');
    my $mlss_adaptor = $compara_db->get_adaptor("MethodLinkSpeciesSet");
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($selectedAlignment); 

    my $as_adaptor = $compara_db->get_adaptor("AlignSlice" );
    my $align_slice = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set);

    my @selected_species = grep {$_ } $object->param("ms_${selectedAlignment}");

# I could not find a better way to distinguish between pairwise alignments
# and multiple alignments. The difference is that in case of multiple alignments
# there are checkboxes for all species from the alignment apart from the reference species: So we need to add the reference species to the list of selected species. In case of pairwise alignments the list remains empty - that will force the display of all available species in the alignment
    if ( scalar (@{$method_link_species_set->species_set}) > 2) {
      unshift @selected_species, $object->species;
    }

    push @sliceArray, @{$align_slice->get_all_Slices(@selected_species)};
  }

  my %sliceHash;
  my ($max_position, $max_label, $consArray) = markupInit($object, \@sliceArray, \%sliceHash);

  my $key_tmpl = qq(<p><code><span id="%s">%s</span></code> %s</p>\n);
  my $KEY = '';

  if( ($object->param( 'conservation' ) ne 'off')  &&  markupConservation($object, \%sliceHash, $consArray)){
      $KEY .= sprintf( $key_tmpl, 'nc', "THIS STYLE:", "Location of conserved regions (where >50% of bases in alignments match) ");
  }

  if(  $object->param( 'codons_display' ) ne 'off' ){
    markupCodons($object, \%sliceHash);
    $KEY .= sprintf( $key_tmpl, 'eo', "THIS STYLE:", "Location of START/STOP codons ");
  }

  if(  $object->param( 'exon_display' ) ne 'off' ){
    markupExons($object, \%sliceHash);
    $KEY .= sprintf( $key_tmpl, 'e', "THIS STYLE:", "Location of selected exons ");
  }


  if( $object->param( 'snp_display' )  eq 'snp'){
    markupSNPs($object, \%sliceHash);
    $KEY .= sprintf( $key_tmpl, 'ns', "THIS STYLE:", "Location of SNPs" );
    $KEY .= sprintf( $key_tmpl, 'nd', "THIS STYLE:", "Location of deletions" );
  }

  if ($object->param('line_numbering') eq 'slice') {
    $KEY .= qq{ NOTE:     For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line };
  }

  my $html = generateHTML($object, \%sliceHash, $max_position, $max_label);

# Add a section holding the names of the displayed slices
  my $Chrs;
  foreach my $sp ( $object->species, grep {$_ ne $object->species } keys %sliceHash) {
    $Chrs .= qq{<p><br/><b>$sp&gt;<br/></b>};
    foreach my $loc (@{$sliceHash{$sp}->{slices}}) {
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $loc);
      $Chrs .= qq{<p><a href="/$sp/contigview?l=$region:$start-$end">$loc</a></p>};
    }
  }

  $panel->add_row( 'Marked_up_sequence', qq(
    $KEY
    $Chrs
    <pre>\n$html\n</pre>
  ) );


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

###### SEQUENCE ALIGN SLICE ########################################################

sub sequencealignview {

  ### SequenceAlignView
  ### Returns 1

  my( $panel, $object ) = @_;
  my $width = $object->param("display_width") || 60;

  #Get reference slice
  my $refslice = $object->slice;
  my @strain_slices;
  my @individuals = ($object->get_individuals('display'));

  # Get slice for each display strain
  foreach my $individual ( @individuals ) {
    my $individual_slice = $refslice->get_by_strain( $individual );
    next unless $individual_slice;
    push @strain_slices, $individual_slice;
  }


  # Markup
  my ($sliceHash, $max_position, $max_label, $consArray) =  markupInit_fc1($object, \@strain_slices);
  my  @linenumbers =  $object->line_numbering;
  my $html = generateHTML($object, $sliceHash, $max_position, $max_label, \@linenumbers);

  my $name = $refslice->name;
#  $panel->add_row("Slice", "<p>$name Length: $length</p>");

# # Add a section holding the names of the displayed slices
#   my $Chrs;
#   foreach my $sp ( $object->species, grep {$_ ne $object->species } keys %$sliceHash) {
#     $Chrs .= qq{<p><br/><b>$sp&gt;<br/></b>};
#     foreach my $loc (@{$sliceHash->{$sp}{slices}}) {
#       my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $loc);
#       $Chrs .= qq{<p><a href="/$sp/contigview?l=$region:$start-$end">$loc</a></p>};
#     }
#   }

#     $KEY
#     $Chrs

 #  $panel->add_row( 'Marked_up_sequence', qq(
 #    <pre>\n$html\n</pre>
 #  ) );


  # Make an align slice
  my $align_slice = Bio::EnsEMBL::AlignStrainSlice->new(-SLICE => $refslice,
                                                     -STRAINS => \@strain_slices);

  my $length =  $align_slice->length;
  my $info;
  foreach my $strain_slice (@strain_slices) {

    #get coordinates of variation in alignSlice
    my @allele_features = @{$strain_slice->get_all_AlleleFeatures_Slice() || []};
    print Dumper($align_slice->{'mapper'});
    foreach my $af ( @allele_features ){
      my $new_feature = $align_slice->alignFeature($af, $strain_slice);
      $info .= "Coordinates of the feature in AlignSlice are: ". $new_feature->start. "-". $af->start. "<br />";
    }
  }
  $panel->add_row( "Alignment", "<p>$info</p>" );
  return 1;
}


sub markupInit_fc1 {
  my ($object, $slices) = @_;

  my (@conservation);
  my $max_position = 0;
  my $max_label = -1;
  my $ins_On = 128;
  my $hRef;

  my $slice_length = length($slices->[0]->seq) + 1 ;
  my $width = $object->param("display_width") || 60;

  foreach my $slice (@$slices) {
    my $sequence = $slice->seq;
    my $strain_name = $slice->strain_name;
#     if ($slice->isa('Bio::EnsEMBL::AlignStrainSlice')) {
#       foreach my $uSlice (@{$slice->get_all_underlying_Slices}) {
#         next if ($uSlice->seq_region_name eq 'GAP');
#         push @{$hRef->{$strain_name}->{slices}}, $uSlice->name;
#         if ( (my $label_length = length($uSlice->seq_region_name)) > $max_label) {
#           $max_label = $label_length;
#         }
#         $max_position = $uSlice->start if ($uSlice->start > $max_position);
#         $max_position = $uSlice->end if ($uSlice->end > $max_position);
#       }
#     } 
#     else {
      $max_position = $slice->start if ($slice->start > $max_position);
      $max_position = $slice->end if ($slice->end > $max_position);
      if ( (my $label_length = length($slice->seq_region_name)) > $max_label) {
        $max_label= $label_length;
      }
      push @{$hRef->{$strain_name}->{slices}}, $slice->name;
#    }
    $hRef->{$strain_name}->{slice} = $slice;
    $hRef->{$strain_name}->{sequence} = $sequence . ' ';
    $hRef->{$strain_name}->{slice_length} = $slice_length;

    # Now put some initial sequence marking
    # Mark final bp
    my @markup_bins = ({ 'pos' => $slice_length, 'mark' => 1 });

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

    $hRef->{$strain_name}->{markup} = \@markup_bins;

    # And in case the conservation markup is switched on - get conservation scores for each basepair in the alignment.
    # In future the conservation scores will come out of a database and this will be removed
    if ( $object->param("conservation") ne 'off') {
      my $idx = 0;
      foreach my $s (split(//, $sequence)) {
        $conservation[$idx++]->{uc($s)} ++;
      }
    }
  }  # end of foreach slice

  return ($hRef, $max_position, $max_label, \@conservation);
}


1;
