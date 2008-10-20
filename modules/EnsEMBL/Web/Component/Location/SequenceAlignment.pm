package EnsEMBL::Web::Component::Location::SequenceAlignment;

use strict;
use warnings;
use Bio::EnsEMBL::AlignStrainSlice;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

my ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On, $reseq_On) = (1, 16, 32, 64, 128, 256, 512);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $width = $object->param("display_width") || 60;
  #Get reference slice
  my $refslice = new EnsEMBL::Web::Proxy::Object( 'Slice', $object->slice, $object->__data );

  my @individuals;
  my $sp = $object->species;
  my $var_hash = $object->species_defs->databases->{'DATABASE_VARIATION'};
  foreach (qw(DEFAULT_STRAINS DISPLAY_STRAINS)) {
      my $set = $var_hash->{$_};
      foreach my $ind (@{$set}) {
	  push @individuals, $ind if ($object->param($ind) eq 'yes');
      }
  }

  # Get slice for each selected display strain
  my @individual_slices;
  foreach my $individual ( @individuals ) {
    next unless $individual;
    my $slice =  $refslice->Obj->get_by_strain( $individual );
    next unless $slice;
    push @individual_slices,  $slice;
  }

  my $html;
  unless (scalar @individual_slices) {
    my $strains = ($object->species_defs->translate('strain') || 'strain') . "s";
    if ( $refslice->get_individuals('reseq') ) {
      $html = qq(Please select $strains to display from the 'Configure this page' link to the left);
    } else {
      $html = qq(No resequenced $strains available for this species);
    }
    return $html;
  }

  # Get align slice
  my $align_slice = Bio::EnsEMBL::AlignStrainSlice->new(-SLICE => $refslice->Obj,
                                                        -STRAINS => \@individual_slices);
  
  # Get aligned strain slice objects
  my $sliceArray = $align_slice->get_all_Slices();
  $html = sequence_markup_and_render( $object, $sliceArray);

  return $html;
}

sub sequence_markup_and_render {
  ### SequenceAlignView
  my ( $object, $sliceArray ) = @_;

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

  if( $object->param( 'snp_display' )  ne 'off') {
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
      $Chrs .= qq{<td><a href="/$display_name/Location/View?r=$region:$start-$end">$loc</a></td>};
    }
    $Chrs .= "</tr>";
  }

  $Chrs .= "</table>";
  return qq($KEY $Chrs <pre>\n$html\n</pre>);

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


1;
