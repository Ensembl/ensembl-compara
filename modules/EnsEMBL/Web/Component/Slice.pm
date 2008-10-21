package EnsEMBL::Web::Component::Slice;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
use EnsEMBL::Web::Form;
use Data::Dumper;
use Bio::EnsEMBL::AlignStrainSlice;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);
no warnings "uninitialized";

our ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On, $reseq_On) = (1, 16, 32, 64, 128, 256, 512);

# Gene Seq Align View -----------------------------------------------------------------------
sub align_sequence_display {

  ### GeneSeqAlignView
  ### Arg1 : panel
  ### Arg2 : Proxy Obj of type Gene

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
    my $align_slice = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, undef, "restrict");

    my @selected_species = grep {$_ } $object->param("ms_${selectedAlignment}");

    # I could not find a better way to distinguish between pairwise and multiple alignments. 
    # The difference is that in case of multiple alignments
    # there are checkboxes for all species from the alignment apart from the reference species: 
    # So we need to add the reference species to the list of selected species. 
    # In case of pairwise alignments the list remains empty - that will force the display 
    # of all available species in the alignment

    if ( scalar (@{$method_link_species_set->species_set}) > 2) {
      unshift @selected_species, $object->species;
    }

    push @sliceArray, @{$align_slice->get_all_Slices(@selected_species)};
    if ($method_link_species_set->method_link_class =~ /GenomicAlignTree/) {
      ## Slices built from GenomicAlignTrees (EPO alignments) are returned in a specific order
      ## This tag will allow us to keep that order
      my $count = 0;
      foreach my $slice (@sliceArray) {
        $slice->{"_order"} = $count++;
      }
    }
  }
  markup_and_render( $panel, $object, \@sliceArray);
  return 1;
}

#-----------------------------------------------------------------------------------------
sub markup_and_render {

  ### GeneSeqAlignView and SequenceAlignView

  my ( $panel, $object, $sliceArray ) = @_;

  my %sliceHash;
  my ($max_values, $consArray) =  markupInit($object, $sliceArray, \%sliceHash);
  my $key_tmpl = qq(<p><code><span class="%s">%s</span></code> %s</p>\n);
  my $KEY = '';
  
   if( ($object->param( 'conservation' ) ne 'off') && markupConservation($object, \%sliceHash, $consArray)){
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


  if( $object->param( 'snp_display' )  ne 'off'){
    markupSNPs($object, \%sliceHash);
    $KEY .= sprintf( $key_tmpl, 'ns', "THIS STYLE:", "Location of SNPs" );
    $KEY .= sprintf( $key_tmpl, 'nd', "THIS STYLE:", "Location of deletions" );
  }

  if ($object->param('line_numbering') eq 'slice' &&  $object->param("RGselect") ) {
    $KEY .= qq{ NOTE:     For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line };
  }

  if ($object->param('individuals')) {
    $KEY .= qq{ ~&nbsp;&nbsp; No resequencing coverage at this position };
  }
  my $html = generateHTML($object, \%sliceHash, $max_values);

  # Add a section holding the names of the displayed slices
  my $Chrs = "<table>";
  foreach my $key_name (_sort_slices( \%sliceHash ) ) {
    my $display_name = $sliceHash{$key_name}{display_name};

    my $slices = $sliceHash{$key_name}{slices};

    if ($display_name eq "Ancestral_sequences") {
      ## Display simple tree for ancestral sequences
      $Chrs .= qq{<tr><th>$display_name &gt;&nbsp;</th>};
      foreach my $tree (@$slices) {
        $Chrs .= qq{<td>$tree</td>};
      }
      $Chrs .= "</tr>";
      next;
    } elsif (!$object->species_defs->valid_species($display_name)) {
      ## Looks like this is required for SequenceAlignView but it has its own method (sequence_markup_and_render)
      next;
    }

    # TO ADD : For the strains, work out the original species and add link for that instead
    $Chrs .= qq{<tr><th>$display_name &gt;&nbsp;</th><td>};

    # If page is based on strains, use the URL species
    unless ($slices ) {
      my $slice_name; 
       eval {
        $slice_name = $object->get_slice_object->Obj->name;
       };
      $slices = [$slice_name];
    }

   foreach my $loc (@$slices) {
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $loc);
      $Chrs .= qq{<a href="/$display_name/contigview?l=$region:$start-$end">$loc</a><br />};
    }
    $Chrs .= "</td></tr>";
  }
  $Chrs .= "</table>";

  $panel->add_row( 'Marked up sequence', qq(
    $KEY
    $Chrs
     <pre>\n$html\n</pre>
   ) );
    return 1;
}

#-----------------------------------------------------------------------------------------
sub _sort_slices {

  ### This method sort the values of hRef according to the _order tags if sets

  my ($hRef) = @_;
  return () if (!%$hRef);

  my $use_order = 1;
  foreach my $slice (values %$hRef) {
    if (!defined($slice->{slice}->{"_order"})) {
      $use_order = 0;
      last;
    }
  }
  if ($use_order) {
    ## Use specified order if available
    return sort {$hRef->{$a}->{slice}->{"_order"} <=> $hRef->{$b}->{slice}->{"_order"}} keys %$hRef;
  } else {
    ## Use normal sort otherwise
    return sort keys %$hRef;
  }
}

#------------------------------------------------------------------------------------------
sub markupInit {

  ### Returns hashref - key value pairs of the maximum length of sequence position, sequence_region_name
  ### abbreviated name and display name
  ### Returns arrayref of conservation

  my ($object, $slices, $hRef) = @_;

  my @conservation;
  my $max_position     = 0;
  my $max_label        = -1;
  my $max_abbr         = 0;

  my $slice_length = length($slices->[0]->seq) + 1 ;
  my $width = $object->param("display_width") || 60;

  # An AlignSlice is made up of at least one AlignSlice::Slice for each 
  # species.  The reference species will only have one AlignSlice::Slice
  my $counter = 0;
  foreach my $slice (@$slices) {
    my $sequence = $slice->seq;
    my $display_name = $slice->can('display_Slice_name') ? $slice->display_Slice_name : $object->species;

    my @subslices;
    if ( $slice->can('get_all_underlying_Slices') ) {
      @subslices = @{$slice->get_all_underlying_Slices};
    }
    else {
      @subslices = ($slice);
    }

    $counter++;
    foreach my $uSlice ( @subslices ) {
      next if ($uSlice->seq_region_name eq 'GAP');
      push @{$hRef->{$display_name."_$counter"}->{slices}}, ($uSlice->{_tree}?$uSlice->{_tree}:$uSlice->name);
      if ( (my $label_length = length($uSlice->seq_region_name)) > $max_label) {
	$max_label = $label_length;
      }
      $max_position = $uSlice->start if ($uSlice->start > $max_position);
      $max_position = $uSlice->end   if ($uSlice->end   > $max_position);
    }

    # Get abbreviated species name (first letters of genus, first 3 of species)
    my $abbr = $object->species_defs->get_config($display_name, "SPECIES_ABBREVIATION") || $display_name;
    $hRef->{$display_name."_$counter"}->{display_name} = $display_name;
    $hRef->{$display_name."_$counter"}->{abbreviation} = $abbr;
    $hRef->{$display_name."_$counter"}->{slice} = $slice;
    $hRef->{$display_name."_$counter"}->{sequence} = $sequence . ' ';
    $hRef->{$display_name."_$counter"}->{slice_length} = $slice_length;


    # Maximum lengths
    $max_abbr         = length($abbr) if length($abbr) > $max_abbr;

    # Now put some initial sequence marking
    my @markup_bins = ({ 'pos' => $slice_length, 'mark' => 1 });     # End seq, end of final bin

    # Split the sequence into lines of $width bp length.
    # Mark start and end of each line
    my $bin = 0;
    my $num_of_bins = int(($slice_length-1) / $width);

    while ($bin < $num_of_bins ) {
      my $pp = $bin * $width + 1;
      push @markup_bins, { 'pos' => $pp };
      push @markup_bins, { 'pos' => $pp+$width-1, 'mark' => 1 }; # position for end of line
      $bin ++;
    }
    push @markup_bins, { 'pos' => $bin * $width + 1 }; # start of last bin

    # Markup inserts
    while ($sequence =~ m/(\-+)[\w\s]/gc) {
      my $txt = length($1)." bp";  # length of insertion ie. ----
      push @markup_bins, { 'pos' => pos($sequence)-length($1),
			   'mask' => $ins_On,  'text' => $txt };
      push @markup_bins, { 'pos' => pos($sequence), 
			   'mask' => -$ins_On, 'text' => $txt };
    }

    $hRef->{$display_name."_$counter"}->{markup} = \@markup_bins;

    # And in case the conservation markup is switched on - get conservation scores for each 
    # basepair in the alignment.
    # In future the conservation scores will come out of a database and this will be removed
    if ( $object->param("conservation") ne 'off') {
      my $idx = 0;
      foreach my $s (split(//, $sequence)) {
        $conservation[$idx++]->{uc($s)} ++;
      }
    }
  } # end foreach slice

  my $max_values = {
		  max_position_length => length($max_position),
		  max_label        => $max_label,
		  max_abbr         => $max_abbr +2,
		 };
  return ($max_values, \@conservation);
}


#-----------------------------------------------------------------------------------------
sub generateHTML {
  my ($object, $hRef, $max_values) = @_;

  my @linenumbers = $object->get_slice_object->line_numbering;
  $linenumbers[0] -- if @linenumbers;

  my $BR = '###';
  my $width = $object->param("display_width") || 60;
  my $line_numbering = $object->param('line_numbering');
  my $reference_name = $object->get_slice_object->get_individuals('reference');
  my $flag_done_reference = 0;
#   foreach my $display_name ($reference_name, (sort keys %$hRef)) {
  foreach my $display_name ($reference_name, (sort keys %$hRef)) {
    next unless $hRef->{$display_name};
    if ($display_name eq $reference_name) {
      next if $flag_done_reference;
      $flag_done_reference = 1 ;
    }

    my $species_html = add_text($object, $hRef, $line_numbering, $width, $max_values, \@linenumbers, $display_name, $BR);

    # Now $species_html holds ready html for the $species
    # To display multiple species aligned line by line here we split the species html on $BR symbol
    # so later we can pick the html line by line from each species in turn
    @{$hRef->{$display_name}->{html}} = split /$BR/, $species_html;
  }  # end foreach display name

  my $html = '';
  if (scalar(keys %$hRef) > 1) {
    while (1) {
      my $line_html = '';
      if ($hRef->{$reference_name}) {
	$line_html .= shift @{$hRef->{$reference_name}->{html} || [] };
      }
      foreach my $display_name (_sort_slices $hRef) {
	next if $display_name eq $reference_name;
        $line_html .= shift @{$hRef->{$display_name}->{html}};
      }
      $html .= "$line_html\n";
      last if (!$line_html);
    }
  } else {
    foreach  (keys %{$hRef}) {
      $html .= join '', @{$hRef->{ $_ }->{html}};
    }
  }

  return $html;
}

#--------------------------------------------------------------------------------------
sub add_text {
  my ($object, $hRef, $line_numbering, $width, $max_values, $linenumbers, $display_name, $BR) = @_;

  my $sindex = 0;
  my $max_label = $max_values->{'max_label'};
  my $max_position_length = $max_values->{'max_position_length'};

 my $sequence     = ($object->param('match_display') eq 'dot') ? $hRef->{$display_name}->{dotted_sequence} : $hRef->{$display_name}->{sequence};
#  my $sequence     = $hRef->{$display_name}->{sequence};
  my $slice        = $hRef->{$display_name}->{slice};
  my $slice_length = $hRef->{$display_name}->{slice_length};
  my $abbr         = $hRef->{$display_name}->{abbreviation};

  my $species_html = add_display_name($sequence, $slice, $slice_length, $abbr, $line_numbering, $width, $max_values, $linenumbers);



  # And now the hard bit 
  my $smask = 0; # Current span mask
  my @title; # Array of span notes
  my $notes; # Line notes - at the moment info on SNPs present on the line
  my @markup = sort { $a->{pos} <=> $b->{pos} || $a->{mark} <=> $b->{mark}  } @{$hRef->{$display_name}->{markup}};

  for (my $i = 1; $i < (@markup); $i++) {

    # First take the preceeding bin ------------------------
    my $previous = $markup[$i -1];

    # If the bin has a mask apply it to the global mask
    # If the bin mask positive then it is the start of a highlighted region
    # -> add the bin text to the span notes if it is not there already
    # Otherwise it is the end of a highlighted region - remove the bin text from the span notes

    if ($previous->{mask}) {
      $smask += $previous->{mask};
      if ($previous->{mask} > 0) { # start of highlighted region
	push @title, $previous->{text} if ($previous->{text} ne $title[-1]);
      } else {
	@title = grep { $_ ne $previous->{text}} @title;
      }
    }

    # Display SNP info at the end of the line if bin has snpID 
    if ($previous->{snpID}) {
      my $pos = $previous->{pos};
      if ($line_numbering eq 'slice') {
	if ($slice->strand > 0 ) {
	  $pos += $slice->start -1;
	}
	else {
	  $pos = $slice->end +1 - $pos;
	}
      }

      # If $display name is a strain, need to replace with the species instead for SNPview URL
      my $link_species = $object->species_defs->get_config($display_name, "SPECIES_ABBREVIATION") ? $display_name : $object->species();
      push @$notes, sprintf("{<a href=\"/%s/snpview?panel_individual=on;snp=%s\">base %u:%s</a>}", $link_species, $previous->{snpID}, $pos, $previous->{textSNP})  if ($object->param('snp_display') eq 'snp_link');
    }


    # And now onto the current bin ----------------------------------
    my $current = $markup[$i];

    # Move to next bin if the current bin annotates the same bp and does not mark end of line
    # The idea is that several regions might have edges in the same position. So 
    # we need to take into account which ones start in the position and which ones end. To 
    # do this we process the mask field of all the bins located in the position
    # before adding the actual sequence.
    next if ($previous->{pos} == $current->{pos} && (! $current->{mark}));

    # Get the width of the sequence region to display
    my $w = $current->{pos} - $previous->{pos};

    # If it is the EOL/BOL defining bin, increment the width to get the right region length
    $w++ if ($current->{mark} && (!defined($current->{mask})));

    # If the previous bin was EOL need to add the line break BR to signal a new line
    # Then add species abbreviation and line numbering
    if ($previous->{mark} && ! defined($current->{mark})) {
      $species_html .= "$BR";
      $species_html .= add_display_name($sequence, $slice, $slice_length, $abbr, $line_numbering, $width, $max_values, $linenumbers, $sindex);
    }

    # Otherwise it is EOL symbol and need to get the region sequence; the region starts from the previous bin position 
    my $sq = $previous->{mark} ? '' : substr($sequence, $previous->{pos}-1, $w);


    # Are we about to display some sequence ? 
    # Then check whether the region should be highlighted and if it the case  put it into <span> tag
    if (length($sq)) {
      my $tag_title = $object->param('title_display') ne 'off' ? ($previous->{textSNP} || join(':', @title)) : '';   # add title to span if 'show title' is on and there is a span note

      # Now analyze the state of the global span mask and choose appropriate 
      # span class from ensembl.css
      # At the moment the highlight works on two levels : background colour and font colour
      # Font colour indicates exons/introns and background colour highlights all other features

      my $NBP = 'n';
      my $sclass = $NBP;

      if ($smask & 0x0F) {
	$sclass = 'e';
      }

      if ($smask & 0x40) {
	$sclass .= 'd';
      } elsif ($smask & 0x20) {
	$sclass .= 's';
      } elsif ($smask & 0x100) {
	$sclass .= 'o';
      } elsif ($smask & 0x10) {
	$sclass .= 'c';
      } elsif ($smask & 0x200) {
	$sclass .= 't';
      }

      if (($sclass ne $NBP) || $tag_title) {
	my $base = $sq;
	if ($sclass =~ /s/) { # if it is a SNP
	  my $ambiguity = $previous->{ambiguity};
	  $base = $ambiguity if $ambiguity;
	}
	$species_html .= sprintf (qq{<span%s%s>%s</span>},
				  $sclass ne 'mn' ? qq{ class="$sclass"} : '',
				  $tag_title ? qq{ title="$tag_title"} : '', $base);
      } else {
	$species_html .= $sq;
      }
    }  # end if length ($sq)

    $sindex += length($sq);

    # The seq is displayed.  Now add the line numbering and the line notes if any
    if ($sindex % $width == 0 && length($sq) != 0) {
      my $seq_name_space = 0;
      my $seq_name      = "";
      my $pos           = undef;

      if ($line_numbering eq 'slice') {
	$seq_name_space = $max_label;

	# For AlignSlice display the position of the last meaningful bp
	if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
	  my $segment = substr($sequence, $sindex-$width, $width);

	  my $last_bp_pos = -1;
	  while ($segment =~ m/[AGCT]/g) {
	    $last_bp_pos = pos($segment);
	  }
	
	  if ($last_bp_pos > 0) {
	    my ($oslice, $position) = $slice->get_original_seq_region_position( $sindex + $last_bp_pos - $width);
	    $seq_name      = $oslice->seq_region_name;
	    $pos           = $position;
	  }
	} else {
	  $pos = $slice->strand > 0 ? ($sindex + $linenumbers->[0]) : ($linenumbers->[0] - $sindex + 2);
	  $seq_name = $slice->seq_region_name;
	}
      } elsif( $line_numbering eq 'sequence') {
	$pos = $sindex + $linenumbers->[0];
      }

      if ($seq_name && $pos && (($pos - $linenumbers->[0]) < $slice_length)) {
	$seq_name_space++;
	$seq_name .= ":";
	$species_html .= sprintf(" %*s", $seq_name_space, $seq_name);
      }

      if ($pos) {
        if (($pos - $linenumbers->[0]) < $slice_length) {
          $species_html .= sprintf("%*u", $max_position_length, $pos);
          if ($notes) {
	    $species_html .= join('|', " ", @$notes);
	    $notes = undef;
	  }
	  $species_html .= "\n";
        }
      } else {
        if ($notes) {
	  $species_html .= join('|', " ", @$notes);
	  $notes = undef;
        }
        $species_html .= "\n";
      }
    } # end if ($sindex % $width == 0 && length($sq) != 0) 
  } # end for my $i

  $sindex--; # correction factor for last line

  # Last line, seq region name and position markup if there are leftovers
#  if (($sindex % $width)  != 0) {
  if (($sindex % $width)  != 0 && (($sindex % $width)  != ($width -1))) {
    my $seq_name_space = 0;
    my $seq_name      = "";
    my $pos           = 0;
    my $padding_width = 0;
    if ($line_numbering eq 'slice') {
      $seq_name_space = $max_label;
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
	my $wd = $sindex % $width;
	my $segment = substr($sequence, -$wd);
	my $last_bp_pos = -1;
	while ($segment =~ m/[AGCT]/g) {
	  $last_bp_pos = pos($segment);
	}

	if ($last_bp_pos > 0) {
	  my ($oslice, $position) = $slice->get_original_seq_region_position( $sindex + $last_bp_pos - $wd);
	  $padding_width = $width - $wd;
	  $seq_name      = $oslice->seq_region_name;
	  $pos           = $position;
	}
      } else {
	$padding_width = $width - ($sindex % $width) -1;
	$pos = $slice->strand > 0 ? ($sindex + $linenumbers->[0]) : ($linenumbers->[0] - $sindex + 2); 
	$seq_name = $slice->seq_region_name;
      }
    } elsif($line_numbering eq 'sequence') {
      $pos = $sindex + $linenumbers->[0];
      $max_position_length += $width - ($sindex % $width) -1;
    }
    if ($seq_name) {
      $seq_name_space++;
      $seq_name .= ":";
      $species_html .= sprintf(" %*s%*s", $padding_width, " ", $seq_name_space, $seq_name);
    }
    $species_html .= sprintf("%*u", $max_position_length, $pos) if $pos;
  }

  $species_html .= join('|', " ", @$notes) if $notes;
  $species_html .= "\n" unless ($species_html =~ /\n$/);
  return $species_html;
}
#---------------------------------------------------------------------------------------
sub markupSNPs {
  my ($object, $hRef) = @_;

  my $width = $object->param("display_width") || 60;
  foreach my $display_name (keys %$hRef) {
    my $slice =  $hRef->{$display_name}->{slice};
    my $sstrand = $slice->strand; # SNP strand bug has been fixed in snp_display function

    foreach my $s (@{$slice->get_all_VariationFeatures(1) || []}) {
      my ( $end, $id, $mask) = ($s->end, $s->variation_name, $snp_On);
      my ( $start, $allele ) = sort_out_snp_strand($s, $sstrand);
      if ($end < $start) {
        ($start, $end) = ($end, $start);
        $mask = $snp_Del;
      }
      $end ++;
      my $ambiguity = ambiguity_code($allele);
      push @{$hRef->{$display_name}->{markup}}, { 'pos'     => $start,  'mask'      => $mask, 
						  'textSNP' => $allele, 'mark'      => 0, 
						  'snpID'   => $id,     'ambiguity' => $ambiguity };
      push @{$hRef->{$display_name}->{markup}}, { 'pos'     => $end,    'mask'      => -$mask  };

      # For variations that aren't SNPs
      my $bin  = int(($start-1) / $width);
      my $num_of_bins = int(($end-2) / $width);
      while ($bin < $num_of_bins) {
        $bin ++;
        my $pp = $bin * $width + 1;
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp, 'mask' => $mask, 'textSNP' => $allele   };
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp-1, 'mark' => 1, 'mask' => -$mask  };
      }
    } # end foreach $s (@snps)
  }
}

#-----------------------------------------------------------------------------------------
sub markupExons {
  my ($object, $hRef) = @_;

  my $width = $object->param("display_width") || 60;
  foreach my $display_name (keys %$hRef) {
    my $sequence = $hRef->{$display_name}->{sequence};
    my $slice =  $hRef->{$display_name}->{slice};
    my $slice_length =  $hRef->{$display_name}->{slice_length};
    my @exons;

    my $exontype = $object->param( 'exon_display' );
    if( $exontype eq 'Ab-initio' ){
      my( $s, $e ) = ( $slice->start, $slice->end );
      @exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
                   map { @{$_->get_all_Exons } }
                   @{$slice->get_all_PredictionTranscripts } );
    } else {
      $exontype ='' unless( $exontype eq 'vega' or $exontype eq 'est' );
      @exons = ($display_name eq $object->species) ?
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

      push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $exon_On, 'text' => $e->stable_id };
      push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => -$exon_On, 'text' => $e->stable_id  };

      my $bin = int($start / $width);
      my $num_of_bins = int(($end-1) / $width);

     # Mark again the start of each line that the exon covers with exon style
      while ($bin < $num_of_bins) {
        $bin ++;
        my $pp = $bin * $width;
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp, 'mask' => -$exon_On, 'mark' => 1, 'text' =>  $e->stable_id };
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp+1, 'mask' => $exon_On, 'text' => $e->stable_id };
      }
    }
  }
}

#-----------------------------------------------------------------------------------------
sub markupCodons {
  my ($object, $hRef) = @_;

  foreach my $display_name (keys %$hRef) {
    my $sequence = $hRef->{$display_name}->{sequence};
    my $slice =  $hRef->{$display_name}->{slice};
    my $slice_length =  $hRef->{$display_name}->{slice_length};

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
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
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
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }  # end foreach $t
    } else { # Normal Slice
      foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
        my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
	if ($start < 1) {
	  $start = 1;
        }
        if ($end > $slice_length) {
           $end = $slice_length-1;
        }

        if ((my $x = $start) > -2) {
          $x = 1 if ($x < 1);
          my $txt = sprintf("START(%s)",$t->stable_id);
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start + 3, 'mask' => - $codon_On, 'text' => $txt  };
        }

        if ((my $x = $end) < $slice_length) {
          $x -= 2;
          $x = 1 if ($x < 1);
          my $txt = sprintf("STOP(%s)",$t->stable_id);
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }
    }
  }
}

#-----------------------------------------------------------------------------------------
sub markupConservation {
  my ($object, $hRef, $consArray) = @_;
  return unless (scalar(keys %$hRef) > 1);

  # Regions where more than 50% of bps match considered `conserved`
  my $consThreshold = int((scalar(keys %$hRef) + 1) / 2);
  my $width = $object->param("display_width") || 60;
 
  # Now for each bp in the alignment identify the nucleotides with scores above the threshold.
  # In theory the data should come from a database. 
  foreach my $nt (@$consArray) {
    #$nt->{S} = join('', grep {$nt->{$_} > $consThreshold} keys(%{$nt}));
    $nt->{S} = join('', grep {$_ ne '~' && $nt->{$_} > $consThreshold} keys(%{$nt}));
    $nt->{S} =~ s/[-.N]//; # here we remove different representations of nucleotides from  gaps and undefined regions : 
  }

  foreach my $display_name (keys %$hRef) {
    my $sequence = $hRef->{$display_name}->{sequence};

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
      push @{$hRef->{$display_name}->{ markup }}, { 'pos' => $c->[0], 'mask' => $cs_On };
      if ($c->[1] % $width == 0) {
	push @{$hRef->{$display_name}->{ markup }}, { 'pos' => $c->[1]+1, 'mask' => -$cs_On };
      } else {
	push @{$hRef->{$display_name}->{ markup }}, { 'pos' => $c->[1], 'mask' => -$cs_On };
      }
    }
  }
  return 1;
}
#----------------------------------------------------------------------------
sub add_display_name {
  my ($sequence, $slice, $slice_length, $abbr, $line_numbering, $width, $max_values, $linenumbers, $sindex) = @_;
  $sindex ||= 0;

  #sprintf("%.*s", 3, $_ )  # word padded to 3 characters
  my $html = sprintf("%-*.*s", $max_values->{max_abbr},  $max_values->{max_abbr}, $abbr);
  my $max_position_length = $max_values->{'max_position_length'};

  # Number markup
  my $seq_name_space = 0;
  my $seq_name      = "";
  my $pos           = undef;

  # If the line numbering is on - then add the index of the first position
  if ($line_numbering eq 'slice') {
    $seq_name_space = $max_values->{max_label};

    if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
      # In case of AlignSlice we show the position of the first defined nucleotide
      my $segment = substr($sequence, $sindex, $width);

      # max_label is the longest seq_region_name
      if ($segment =~ m/[ATGCN]/g) {  # if there is sequence
	my ($oslice, $position) = $slice->get_original_seq_region_position( $sindex + pos($segment) );
	$seq_name      = $oslice->seq_region_name;
	$pos           = $position;
      }
      else {
	$seq_name_space += $max_position_length + 2;
      }
    } 
    else {
      if ($sindex < $slice_length) {
	my $pos1 = $slice->strand > 0 ? ($sindex + $linenumbers->[0] + 1) : ($linenumbers->[0] + 1 - $sindex); 
	$pos = $pos1;
	$seq_name = $slice->seq_region_name;
      }
    }
  } 

  elsif ($line_numbering eq 'sequence') {
    if ($sindex < $slice_length) {
     	$pos = $sindex + $linenumbers->[0] +1;
    }
  }
  if ($seq_name) {
    $seq_name_space++;
    $seq_name .= ":";
  }
  $html .= sprintf("%*s", $seq_name_space, $seq_name) if $seq_name_space;
  $html .= sprintf("%*u %s", $max_position_length, $pos) if $pos;
  return $html;
}

####### GENE SEQ VIEW #########################################################################

sub sequence_display2 {
  ### GeneSeqView
  ### Arg1 : panel
  ### Arg2 : Proxy Obj of type Gene

  my( $panel, $object ) = @_;
  my $slice   = $object->get_slice_object->Obj(); # Object for this section is the slice
  markup_and_render($panel, $object, [$slice]);
}

#----------------------------------------------------------------------------
sub bin_starts {

  ### GeneSeqView
  ### Sequence markup uses a 'variable-length bin' approach.
  ### Each bin has a format.
  ### A feature can span multiple bins.
  ### Allows for feature overlaps - combined formats.
  ### Bins start at feature starts, and end at feature ends + 1
  ### Allow for cigar strings - these split alignments into 'mini-features'.

  my ($slice, $gene_exons, $other_exons, $snps) = @_;
  my $slength = $slice->Obj->length;
  my $sstart  = $slice->Obj->start;
  my $send    = $slice->Obj->end;
  my $sstrand = $slice->Obj->strand; # SNP strand bug has been fixed in snp_display function

  # Get a unique list of all possible bin starts
  my %all_locs = ( 1=>1, $slength+1=>1 );
  foreach my $feat ( @$gene_exons, @$other_exons ){
    # skip the features that were cut off by applying flanking sequence parameters
    next if $feat->seq_region_start < $sstart || $feat->seq_region_end > $send;

    # If the feature is on reverse strand - then count from the end
    my $fstrand = $feat->seq_region_strand;
    my $fstart  = $fstrand < 0 ? $send - $feat->seq_region_end + 1 : $feat->seq_region_start - $sstart + 1;
    #    my $fstart  = $feat->seq_region_start - $sstart + 1;
    $fstart = $slength+1   if $fstart > $slength+1;
    $all_locs{$fstart} = 1 if $fstart > 0;

    foreach my $seg(  @{ cigar_segments($feat) } ) {
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
  return \@bin_locs || [];
}

#-------------------------------------------------------
sub cigar_segments {

  ### Arg: Bio::EnsEMBL::Feature
  ### GeneSeqView

  my ($feat) = @_;
  my $cigar;
  $cigar = $feat->cigar_string if $feat->can('cigar_string');
  $cigar ||= $feat->length . "M"; # Fake cigar; matches length of feat

  my @segs = ( $cigar =~ /(\d*\D)/g ); # Segment cigar
  if( $feat->seq_region_strand < 1 ){ @segs = reverse( @segs ) } # if -ve ori, invert cigar
  return \@segs || [];
}

#----------------------------------------------------------
sub populate_bins {

  ### GeneSeqView
  ### Code to mark up the exons in each bin

  my ($exons, $slice, $bin_idx, $bin_markup, $styles, $key) = @_;
  my %estyles  = %{ $styles->{$key} };
  my $sstart  = $slice->Obj->start;
  my $send    = $slice->Obj->end;

  foreach my $feat( @$exons ){ 
    next if $key eq 'gene_exons' && ($feat->end < $sstart || $feat->start > $send);
    my $fstrand = $feat->seq_region_strand;
    my $fstart  = $fstrand < 0 ? $send - $feat->seq_region_end + 1 : $feat->seq_region_start - $sstart + 1;

    my $title;
    if ($feat->can('stable_id')) { $title = $feat->stable_id; }

   foreach my $seg(  @{ cigar_segments($feat) }  ){
     my $type = chop( $seg ); # Remove seg type - length remains
     next if( $type eq 'D' ); # Ignore deletes
     my $fend = $fstart + $seg;
     my $idx_start = $fstart > 0 ? $bin_idx->{$fstart} : $bin_idx->{1};
     my $idx_end   = ( $bin_idx->{$fend} ? $bin_idx->{$fend} : @$bin_markup ) -1;
     $fstart += $seg;
     next if $type ne 'M'; # Only markup matches

     # Add styles to affected bins
     my %istyles = %{$styles->{gene_exon}};

     foreach my $bin( @$bin_markup[ $idx_start .. $idx_end ] ){
       map{ $bin->[1]->{$_} = $estyles{$_} } keys %estyles;
       next unless $title;

       if ($key eq 'gene_exon' && defined (my $alt = $bin->[2]) ) {
	 if (! grep {$_ eq $title} split(/ : /, $alt) ) {
	   $bin->[2] = "$alt:$title";
	   next;
	 }
       }
       $bin->[2] = join( ' : ', $bin->[2]||(), $title||() );
     } # end foreach $bin
   }
  }
  return 1;
}

#----------------------------------------------------------------------

sub sort_out_snp_strand {

  ### GeneSeqView and GeneSeqAlignView
  ### Arg: variation object
  ### Arg: slice strand
  ### Returns the start of the snp relative to the gene
  ### Returns the snp alleles relative to the orientation of the gene

  my ( $snp, $sstrand ) = @_;
  my( $fstart, $fend ) = ( $snp->start, $snp->end );
  if($fstart > $fend) { # Insertion
    $fstart = $fstart - 2 if $sstrand < 0;
  }
  my $allele = $snp->allele_string;
  
  # If gene is reverse strand we need to reverse parts of allele, i.e AGT/- should become TGA/-
  if ($sstrand < 0) {
    my @av = split(/\//, $allele);
    $allele = '';

    foreach (@av) {
      $allele .= reverse($_).'/';
    }
    $allele =~ s/\/$//;
  }

  # if snp is on reverse strand - flip the bases
  $allele =~ tr/ACGTacgt/TGCAtgca/ if $snp->strand < 0;
  return ($fstart, $allele);
}

###### SEQUENCE ALIGN SLICE ########################################################
sub sequence_markup_options {
  my( $panel, $object ) =@_;
    $panel->add_row( 'Genomic Location and <br/>Markup options', "<div>@{[ $panel->form( 'markup_options' )->render ]}</div>" );
  return 1;
}
      
sub sequence_markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'markup_options', "/@{[$object->species]}/sequencealignview", 'get' );
  $form = sequence_options_form($panel, $object, $form, "exons");
  $form = alignment_options_form($panel, $object, $form );
  $form = individuals_options_form($panel, $object, $form );
  $form->add_element(
	                'type'  => 'Submit', 'value' => 'Update'
  );

  return $form;
}

sub sequence_options_form {
  my( $panel, $object, $form, $exon_type ) = @_;

      # make array of hashes for dropdown options
  my ($region_name, @rest) = split /:/, $object->slice->name;
  $form->add_element(
    'type' => 'String', 'required' => 'yes',
    'label' => "\u$region_name Name",  'name' => 'region',
    'value' => $object->seq_region_name,# #param('region')
    'size' => 10,
    'style' => 'width:30px',
  );

  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "Start",  'name' => 'vc_start',
    'value' => $object->seq_region_start #$object->param('vc_start')
  );
  
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "End",  'name' => 'vc_end',
    'value' => $object->seq_region_end #$object->param('vc_end')
  );
  
  my $strand = [
   { 'value' =>'1' , 'name' => 'Forward' },
   { 'value' =>'-1' , 'name' => 'Reverse' },
  ];
  
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'strand',
    'label'    => 'Strand',
    'values'   => $strand,
    'value'    => $object->seq_region_strand #$object->param('strand'),
  );


  my $exon_ori = [
    { 'value' =>'off' , 'name' => 'None' },
    { 'value' =>'same' , 'name' => 'Same orientation exons only' },
    { 'value' =>'rev' , 'name' => 'Reverse orientation exons only' },
    { 'value' =>'all' , 'name' => 'All exons' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => "Exons to highlight",
    'values'   => $exon_ori,
    'value'    => $object->param('exon_ori')
  );

  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    my $snp_display = [
      { 'value' =>'snp' , 'name' => 'Yes' },
      { 'value' =>'snp_link' , 'name' => 'Yes and show links' },
      { 'value' =>'off' , 'name' => 'No' },
    ];

    $form->add_element(
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Highlight variations',
      'values'   => $snp_display,
      'value'    => $object->param('snp_display')
    );
  }

  my $line_numbering = [
    { 'value' =>'sequence' , 'name' => 'Relative to this sequence' },
    { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
    { 'value' =>'off'      , 'name' => 'None' },
  ];

  $form->add_element(
             'type'     => 'DropDown', 'select'   => 'select',
	     'required' => 'yes',      'name'     => 'line_numbering',
	     'label'    => 'Line numbering',
	     'values'   => $line_numbering,
	     'value'    => $object->param('line_numbering')
	     );

   return $form;
}

sub alignment_options_form {
  my( $panel, $object, $form ) = @_;

    $form->add_element(
        'type' => 'NonNegInt', 'required' => 'yes',
	'label' => "Alignment width",  'name' => 'display_width',
	'value' => $object->param('display_width'),
	'notes' => 'Number of bp per line in alignments'
	);


	my $match_display = [
	{ 'value' =>'off' , 'name' => 'Show all' },
	{ 'value' =>'dot' , 'name' => 'Replace matching bp with dots' },
	];
	$form->add_element(
	'type'     => 'DropDown', 'select'   => 'select',
	'required' => 'yes',      'name'     => 'match_display',
	'label'    => 'Matching basepairs',
	'values'   => $match_display,
	'value'    => $object->param('match_display'),
	);

	my $codons_display = [
	{ 'value' =>'all' , 'name' => 'START/STOP codons' },
	{ 'value' =>'off' , 'name' => "Do not show codons" },
	];
	$form->add_element(
	'type'     => 'DropDown', 'select'   => 'select',
	'required' => 'yes',      'name'     => 'codons_display',
	'label'    => 'Codons',
	'notes'    => 'Displayed only for the highlighted exons',
	'values'   => $codons_display,
	'value'    => $object->param('codons_display'),
	);

	my $title_display = [
	{ 'value' =>'all' , 'name' => 'Include `title` tags' },
	{ 'value' =>'off' , 'name' => 'None' },
	];
	$form->add_element(
	'type'     => 'DropDown', 'select'   => 'select',
	'required' => 'yes',      'name'     => 'title_display',
	'label'    => 'Title display',
	'values'   => $title_display,
	'value'    => $object->param('title_display'),
	'notes'    => "On mouse over displays exon IDs, length of insertions and SNP\'s allele",
	);

	return $form;
}

sub individuals_options_form {
  my( $panel, $object, $form ) = @_;

  my $species =  $object->species_defs->SPECIES_COMMON_NAME || $object->species;
  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );
  my %selected_species = map { $_ => 1} $object->param('individuals');

  my %reseq_strains;
  map { $reseq_strains{$_->name} = 1; } (  $refslice->get_individuals('reseq') );
  my $golden_path = $refslice->get_individuals('reference');
  my $individuals = {};

  foreach ( $refslice->get_individuals('display') ) {
    my $key = $_ eq $golden_path   ? 'ref' :
    $reseq_strains{$_} ? 'reseq' : 'other';
    if ( $selected_species{$_} ) {
      push @{$individuals->{$key}}, {'value' => $_, 'name'=> $_, 'checked'=>'yes'};
    } else {
      push @{$individuals->{$key}}, {'value' => $_, 'name'=> $_};
    }
  }

  my $strains =  $object->species_defs->translate( 'strain' );
  $form->add_element(
	'type'     => 'NoEdit',
	'name'     => 'reference_individual',
	'label'    => "Reference $strains:",
	'value'    => "$golden_path"
  ) if $individuals->{'ref'};

  $strains .= "s";


  if ($individuals->{'reseq'}) {  
    $form->add_element(
      'type'     => 'MultiSelect',
      'name'     => 'individuals',
      'label'    => "Resequenced $species $strains",
      'values'   => $individuals->{'reseq'},
      'value'    => $object->param('individuals'),
    );
 
=pod
## This kind of thing needs to be done by some generic mechanism 
    $form->add_element(
      'type'  => 'Button', 'value' => "Deselect all $strains", 'onclick' =>"deselectAll('individuals')"
    );

    $form->add_element(
      'type'  => 'Button', 'value' => "Select all $strains", 'onclick' =>"selectAll('individuals')"
    );
=cut
  }
  return $form;
}
					      


sub sequencealignview {

  ### SequenceAlignView
  ### Returns 1

  my( $panel, $object ) = @_;
  my $width = $object->param("display_width") || 60;
  #Get reference slice
  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );


  my @individuals =  $refslice->param('individuals');
  # Get slice for each display strain
  my @individual_slices;
  foreach my $individual ( @individuals ) {
    next unless $individual;
    my $slice =  $refslice->Obj->get_by_strain( $individual );
    next unless $slice;
    push @individual_slices,  $slice;
  }

  unless (scalar @individual_slices) {
    my $strains = ($object->species_defs->translate('strain') || 'strain') . "s";
    if ( $refslice->get_individuals('reseq') ) {
      $panel->add_row( 'Marked up sequence', qq(Please select $strains to display from the panel above));
    } else {
      $panel->add_row( 'Marked up sequence', qq(No resequenced $strains available for these species));
    }
    return 1;
  }

  # Get align slice
  my $align_slice = Bio::EnsEMBL::AlignStrainSlice->new(-SLICE => $refslice->Obj,
                                                        -STRAINS => \@individual_slices);
  
  # Get aligned strain slice objects
  my $sliceArray = $align_slice->get_all_Slices();
  sequence_markup_and_render( $panel, $object, $sliceArray);

  return 1;
}

sub sequence_markup_and_render {
  ### SequenceAlignView
  my ( $panel, $object, $sliceArray ) = @_;

  my %sliceHash;
  # Initialize bins
  my ($max_values, $consArray) =  sequence_markupInit($object, $sliceArray, \%sliceHash);
 
  # Display the legend
  my $key_tmpl = qq(<p><code><span class="%s">%s</span></code> %s</p>\n);
  my $KEY = '';
  
  if ($sliceArray->[0]->isa("Bio::EnsEMBL::StrainSlice")) {
    $KEY .= qq{ ~&nbsp;&nbsp; No resequencing coverage at this position };
  }

  if( ($object->param( 'match_display' ) ne 'off')) {
    $KEY .= sprintf( $key_tmpl, 'nc', '', " * Basepairs in secondary strains matching the reference strain are replaced with dots");
    $KEY .= sprintf( $key_tmpl, 'nt', "THIS STYLE:", "Resequencing coverage" );
  }

  if( ($object->param( 'conservation' ) ne 'off') && markupConservation($object, \%sliceHash, $consArray)){
    $KEY .= sprintf( $key_tmpl, 'nc', "THIS STYLE:", "Location of conserved regions (where >50% of bases in alignments match) ");
  }

  if(  $object->param( 'exon_ori' ) ne 'off' ){
    if( ($object->param( 'exon_mark' ) eq 'capital')) {
      $KEY .= sprintf( $key_tmpl, 'nc', '', " * Exons are marked by capital letters.");
    } else {
      $KEY .= sprintf( $key_tmpl, 'e', "THIS STYLE:", "Location of selected exons ");
    }
    sequence_markupExons($object, \%sliceHash);
    
    if(  $object->param( 'codons_display' ) ne 'off' ){
      sequence_markupCodons($object, \%sliceHash);
      $KEY .= sprintf( $key_tmpl, 'eo', "THIS STYLE:", "Location of START/STOP codons ");
    }
  }


  if( $object->param( 'snp_display' )  ne 'off'){
    markupSNPs($object, \%sliceHash);
    $KEY .= sprintf( $key_tmpl, 'ns', "THIS STYLE:", "Location of SNPs" );
    $KEY .= sprintf( $key_tmpl, 'nd', "THIS STYLE:", "Location of deletions" );
  }


  if ($object->param('line_numbering') eq 'slice' &&  $object->param("RGselect") ) {
     $KEY .= qq{ NOTE:     For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line };
  }
       
  my $html = sequence_generateHTML($object, \%sliceHash, $max_values);

  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );
  my $gp = $refslice->get_individuals('reference');
  
 # Add a section holding the names of the displayed slices
  my $Chrs = "<table>";
  foreach my $display_name (sort( $object->species, grep {$_ ne $object->species } keys %sliceHash ) ) {
    next unless  $object->species_defs->valid_species($display_name);

    # TO ADD : For the strains, work out the original species and add link for that instead
    $Chrs .= qq{<tr><th>$display_name &gt;&nbsp;</th>};
    my $slices = $sliceHash{$display_name}{slices};
  
    # If page is based on strains, use the URL species
    unless ($slices ) {
      $slices = $sliceHash{$gp}{slices};
    }

    foreach my $loc (@$slices) {
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $loc);
      $Chrs .= qq{<td><a href="/$display_name/contigview?l=$region:$start-$end">$loc</a></td>};
    }
    $Chrs .= "</tr>";
  }

  $Chrs .= "</table>";
  $panel->add_row( 'Marked up sequence', qq(
					     $KEY
					         $Chrs
						      <pre>\n$html\n</pre>
  ) );

  return 1;
}

sub sequence_generateHTML {
  my ($object, $hRef, $max_values) = @_;

  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );
  my @linenumbers = $refslice->line_numbering;
  $linenumbers[0] -- if @linenumbers;

  my $BR = '###';
  my $width = $object->param("display_width") || 60;
  my $line_numbering = $object->param('line_numbering');
  my $reference_name = $refslice->get_individuals('reference');
  my $flag_done_reference = 0;
  foreach my $display_name ($reference_name, (sort keys %$hRef)) {
    next unless $hRef->{$display_name};
    if ($display_name eq $reference_name) {
      next if $flag_done_reference;
      $flag_done_reference = 1 ;
    }

    my $species_html = add_text($object, $hRef, $line_numbering, $width, $max_values, \@linenumbers, $display_name, $BR);

    # Now $species_html holds ready html for the $species
    # To display multiple species aligned line by line here we split the species html on $BR symbol
    # so later we can pick the html line by line from each species in turn
    @{$hRef->{$display_name}->{html}} = split /$BR/, $species_html;
  }  # end foreach display name

  my $html = '';
  if (scalar(keys %$hRef) > 1) {
    while (1) {
      my $line_html = '';
      if ($hRef->{$reference_name}) {
	$line_html .= shift @{$hRef->{$reference_name}->{html} || [] };
      }
      foreach my $display_name (sort keys %{$hRef}) {
	next if $display_name eq $reference_name;
        $line_html .= shift @{$hRef->{$display_name}->{html}};
      }
      $html .= "$line_html\n";
      last if (!$line_html);
    }
  } else {
    foreach  (keys %{$hRef}) {
      $html .= join '', @{$hRef->{ $_ }->{html}};
    }
  }

  return $html;
}


sub sequence_markupInit {

  ### Returns hashref - key value pairs of the maximum length of sequence position, sequence_region_name
  ### abbreviated name and display name
  ### Returns arrayref of conservation

  my ($object, $slices, $hRef) = @_;

  my @conservation;
  my $max_position     = 0;
  my $max_label        = -1;
  my $max_abbr         = 0;

  my $slice_length = length($slices->[0]->seq) + 1 ;
  my $width = $object->param("display_width") || 60;

  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );
  my $gp = $refslice->get_individuals('reference');
  my @refseq = unpack("A1" x (length($refslice->Obj->seq)), $refslice->Obj->seq);
       
  # An AlignSlice is made up of at least one AlignSlice::Slice for each 
  # species.  The reference species will only have one AlignSlice::Slice
  foreach my $slice (@$slices) {
    my $sequence = $slice->seq(1);
    my $display_name = $slice->can('display_Slice_name') ? $slice->display_Slice_name : $object->species;

    my @subslices;
    if ( $slice->can('get_all_underlying_Slices') ) {
      @subslices = @{$slice->get_all_underlying_Slices};
    }
    else {
      @subslices = ($slice);
    }

    foreach my $uSlice ( @subslices ) {
      next if ($uSlice->seq_region_name eq 'GAP');
      push @{$hRef->{$display_name}->{slices}}, $uSlice->name;
      if ( (my $label_length = length($uSlice->seq_region_name)) > $max_label) {
	$max_label = $label_length;
      }
      $max_position = $uSlice->start if ($uSlice->start > $max_position);
      $max_position = $uSlice->end   if ($uSlice->end   > $max_position);
    }

    # Get abbreviated species name (first letters of genus, first 3 of species)
    my $abbr = $object->species_defs->get_config($display_name, "SPECIES_ABBREVIATION") || $display_name;
    $hRef->{$display_name}->{display_name} = $display_name;
    $hRef->{$display_name}->{abbreviation} = $abbr;
    $hRef->{$display_name}->{slice} = $slice;
    $hRef->{$display_name}->{sequence} = $sequence . ' ';
    $hRef->{$display_name}->{slice_length} = $slice_length;


    # Maximum lengths
    $max_abbr         = length($abbr) if length($abbr) > $max_abbr;

    # Now put some initial sequence marking
    my @markup_bins = ({ 'pos' => $slice_length, 'mark' => 1 });     # End seq, end of final bin

    # Split the sequence into lines of $width bp length.
    # Mark start and end of each line
    my $bin = 0;
    my $num_of_bins = int(($slice_length-1) / $width);

    while ($bin < $num_of_bins ) {
      my $pp = $bin * $width + 1;
      push @markup_bins, { 'pos' => $pp };
      push @markup_bins, { 'pos' => $pp+$width-1, 'mark' => 1 }; # position for end of line
      $bin ++;
    }
    push @markup_bins, { 'pos' => $bin * $width + 1 }; # start of last bin

    # Markup inserts
    while ($sequence =~ m/(\-+)[\w\s]/gc) {
      my $txt = length($1)." bp";  # length of insertion ie. ----
      push @markup_bins, { 'pos' => pos($sequence)-length($1),
			   'mask' => $ins_On,  'text' => $txt };
      push @markup_bins, { 'pos' => pos($sequence), 
			   'mask' => -$ins_On, 'text' => $txt };
    }

    $hRef->{$display_name}->{markup} = \@markup_bins;

    if (($object->param('match_display') ne 'off') && ($display_name ne $gp)) {
      while ($sequence =~ m/([^~]+)/g) {
        my $s = pos($sequence)+1;
	push @markup_bins, { 'pos' => $s-length($1),
	                     'mask' => $reseq_On};
        push @markup_bins, { 'pos' => $s,
			     'mask' => -$reseq_On };
      }
    }
									      
    # And in case the conservation markup is switched on - get conservation scores for each 
    # basepair in the alignment.
    # In future the conservation scores will come out of a database and this will be removed
    if ( $object->param("conservation") ne 'off') {
      my $idx = 0;
      foreach my $s (split(//, $sequence)) {
        $conservation[$idx++]->{uc($s)} ++;
      }
    }
    if ( $object->param("match_display") ne 'off') {
      if ($display_name eq $gp) {
	 $hRef->{$display_name}->{dotted_sequence} = $hRef->{$display_name}->{sequence} ;
	  next;
      }
      my @cmpseq = unpack("A1" x (length($sequence)), $sequence);
      my $idx = 0;
      foreach my $s (@refseq) {
	if ($s eq $cmpseq[$idx]) {
	  $cmpseq[$idx] = '.';
        }
        $idx++;
      }
      $hRef->{$display_name}->{dotted_sequence} = pack("A1" x scalar(@cmpseq), @cmpseq) . ' ';
    }
  } # end foreach slice

  my $max_values = {
		  max_position_length => length($max_position),
		  max_label        => $max_label,
		  max_abbr         => $max_abbr +2,
		 };
  return ($max_values, \@conservation);
}
sub dump_hash {
  my $h = shift;
  my @keylist = sort keys (%$h);
  foreach my $key (@keylist) {
     warn "$key => $h->{$key} \n";
  }
}

sub sequence_markupExons {
  my ($object, $hRef) = @_;

  my $ori = $object->param('exon_ori') || 'off';
  return unless $ori ne 'off';

  my $width = $object->param("display_width") || 60;
  foreach my $display_name (keys %$hRef) {
    my $slice =  $hRef->{$display_name}->{slice};
    my $slice_length =  $hRef->{$display_name}->{slice_length};
    my $sequence =   ($object->param( 'exon_mark' ) eq 'capital') ? lc($hRef->{$display_name}->{sequence}) : $hRef->{$display_name}->{sequence};
    my @exons;

    my $exontype = ''; #$object->param( 'exon_display' );
    @exons = ($display_name eq $object->species) ?
      map  { @{$_->get_all_Exons } } grep { $_->stable_id eq $object->stable_id } @{$slice->get_all_Genes('', $exontype)} :
      map  { @{$_->get_all_Exons } } @{$slice->get_all_Genes('', $exontype)} ;

    if( $ori eq 'same' ) {
      @exons = grep{$_->strand > 0} @exons; # Only exons which are on the same strand as the slice
    } elsif( $ori eq 'rev' ){
      @exons = grep{$_->strand < 0} @exons; # Only exons which are on the opposite strand to the slice
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

      if( ($object->param( 'exon_mark' ) eq 'capital')) {
        substr($sequence, $start -1, ($end - $start + 1)) = uc(substr($sequence, $start - 1, ($end - $start + 1)));
      } else {
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $exon_On, 'text' => $e->stable_id };
        push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => -$exon_On, 'text' => $e->stable_id  };
        my $bin = int($start / $width);
        my $num_of_bins = int(($end-1) / $width);

# Mark again the start of each line that the exon covers with exon style
        while ($bin < $num_of_bins) {
          $bin ++;
          my $pp = $bin * $width;
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp, 'mask' => -$exon_On, 'mark' => 1, 'text' =>  $e->stable_id };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $pp+1, 'mask' => $exon_On, 'text' => $e->stable_id };
        }
      }
    }

    $hRef->{$display_name}->{sequence}= $sequence if ($object->param( 'exon_mark' ) eq 'capital');
  }
}

sub sequence_markupCodons {
  my ($object, $hRef) = @_;

  my $ori = $object->param('exon_ori') || 'off';
  return unless $ori ne 'off';

  foreach my $display_name (keys %$hRef) {
    my $sequence = $hRef->{$display_name}->{sequence};
    my $slice =  $hRef->{$display_name}->{slice};
    my $slice_length =  $hRef->{$display_name}->{slice_length};

    my @transcripts =  map  { @{$_->get_all_Transcripts } } @{$slice->get_all_Genes()} ;

    if( $ori eq 'same' ) {
      @transcripts = grep{$_->strand > 0} @transcripts; # Only transcripts which are on the same strand as the slice
    } elsif( $ori eq 'rev' ){
      @transcripts = grep{$_->strand < 0} @transcripts; # Only transcripts which are on the opposite strand to the slice
    }
    
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
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
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
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }  # end foreach $t
    } else { # Normal Slice
      foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
        my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
	if ($start < 1) {
	  $start = 1;
        }
        if ($end > $slice_length) {
           $end = $slice_length-1;
        }

        if ((my $x = $start) > -2) {
          $x = 1 if ($x < 1);
          my $txt = sprintf("START(%s)",$t->stable_id);
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $start + 3, 'mask' => - $codon_On, 'text' => $txt  };
        }

        if ((my $x = $end) < $slice_length) {
          $x -= 2;
          $x = 1 if ($x < 1);
          my $txt = sprintf("STOP(%s)",$t->stable_id);
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $x, 'mask' => $codon_On, 'text' => $txt };
          push @{$hRef->{$display_name}->{markup}}, { 'pos' => $end+1, 'mask' => - $codon_On, 'text' => $txt  };
        }
      }
    }
  }
}

1;

