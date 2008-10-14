package EnsEMBL::Web::Component::Location::VariationAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

our ($exon_On, $cs_On, $snp_On, $snp_Del, $ins_On, $codon_On, $reseq_On) = (1, 16, 32, 64, 128, 256, 512);

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


  my @individuals =  $refslice->param('individuals');
  # Get slice for each display strain
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
      $html = qq(Please select $strains to display from the panel above);
    } else {
      $html = qq(No resequenced $strains available for these species);
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

sub dump_hash {
}

1;
