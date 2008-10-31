package EnsEMBL::Web::Component::Gene::GeneSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $html;
  my $object = $self->object;

  my $slice   = $object->get_slice_object(); # Object for this section is the slice
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';

  # Return all variation features on slice if param('snp display');
  my $snps  = $slice->param( 'snp_display' )  =~ /snp/ ? $slice->snp_display()  : [];

  # Return additional specific exons as chosen in form by user
  my $other_exons = $slice->param( 'exon_display' ) ne 'off' ? $slice->exon_display() : [];

  # Return all exon features on gene
  my $gene_exons = $slice->param( 'exon_display' ) ne 'off' ? $slice->highlight_display( $object->Obj->get_all_Exons ) : [];

  # Create bins for sequence markup --------------------------------------
  my @bin_locs = @{ $self->bin_starts($slice, $gene_exons, $other_exons, $snps) };
  my %bin_idx; # A hash index of bin start locations vs pos in index

  my @bin_markup;
  for( my $i=0; $i<@bin_locs; $i++ ){
    my $bin_start  = $bin_locs[$i];
    my $bin_end    = $bin_locs[$i+1] || last;
    my $bin_length = $bin_end - $bin_start;
    $bin_idx{$bin_start} = $i;
    $bin_markup[$i] = [ $bin_length, {} ]; # Init bin, and flag as empty
  }

  # Define a formatting styles. These correspond to name/value pairs ---------------
  # in HTML style attributes
  my %styles = (
      DEFAULT =>{},
      ## exon    => { 'color' => 'darkred',  'font-weight' =>'bold' },
      ## high2   => { 'color' => 'darkblue', 'font-weight' =>'bold' },
      ## high1   => { 'background-color' => 'blanchedalmond' },
      other_exon => { 'background-color' => 'blanchedalmond' },
      gene_exon  => { 'color' => 'darkred',  'font-weight' =>'bold'},
      snp        => { 'background-color' => '#caff70'        },
      snpexon    => { 'background-color' => '#7fff00'        }
  );

  my $KEY = '';
  my $style_tmpl = qq(<span style="%s" title="%s">%s</span>);
  my $key_tmpl = qq(<p><tt>$style_tmpl</tt> %s</p>);

  if( @$gene_exons ){
    my $type = $gene_exons->[0]->isa('Bio::EnsEMBL::Exon') ? 'exons' : 'features';
    my %istyles = %{$styles{gene_exon}};
    my $genename = $object->Obj->stable_id;
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of $genename $type" )
  }

  if( @$other_exons ){
    my %istyles = %{$styles{other_exon}};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    my $selected =  ucfirst($slice->param( 'exon_display' ));
    $selected = $sitetype if $selected eq 'Core';
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of $selected exons ");
  }

  if( @$snps ){
    my %istyles = %{$styles{snp}};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $KEY .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", "Location of SNPs" )
  }

  # Populate bins with exons ----------------------------
  $self->populate_bins($other_exons, $slice, \%bin_idx, \@bin_markup, \%styles, "other_exon");
  $self->populate_bins($gene_exons, $slice, \%bin_idx, \@bin_markup, \%styles, "gene_exon");

  # Populate bins with SNPs -----------------------------
  my %snpstyles = %{$styles{snp}};
  my %snpexonstyles = %{$styles{snpexon}};
  my $sstrand = $slice->Obj->strand; # SNP strand bug has been fixed in snp_display function
  
  foreach my $snp( @$snps ){
    my ( $fstart, $allele ) = $self->sort_out_snp_strand($snp, $sstrand);
    my $idx_start = $bin_idx{$fstart};
    my $bin = $bin_markup[$idx_start];
    my %usestyles = ( $bin->[1]->{'background-color'} ?  %snpexonstyles : %snpstyles );
    map{ $bin->[1]->{$_} = $usestyles{$_} } keys %usestyles;

    $bin->[2] = $allele || '';
    $bin->[3] = ($snp->end > $snp->start) ? 'ins' : 'del';
    $bin->[4] = $snp->{variation_name};
    $bin->[5] = $self->ambiguity_code($allele);
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
  my $seq     = $slice->Obj->seq;
  my $linelength  = 60; # TODO: retrieve with method?
  my $length = length( $seq );
  my @linenumbers = $slice->line_numbering();
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
      my( $n, $tmpl, $title, $type, $snp_id, $ambiguity ) = @$markup; # Length and template of markup
      if ($slice->param('snp_display') eq 'snp_link' && defined($type)) {
        # atm, it can only be 'ins' or 'del' to indicate the type of a variation
        # in case of deletion we highlight flanked bases, and actual region where some bases are missing located at the right flank
        my $ind = ($type eq 'ins') ? $i+$j : $i+$j+1;
        $ind += $linenumbers[0]-1 if $object->param('line_numbering') eq 'slice';
        push @var_list, qq(<a href="/@{[$object->species]}/Variation/Summary?v=$snp_id;vdb=variation">$ind:$title</a>);
      }
      if( ! $n ){ next }
      if( $n > $linelength-$j ){ # Markup extends over line end. Trim for next
        unshift( @bin_markup, [ $n-($linelength-$j), $tmpl ] );
        $n = $linelength-$j;
      }
      my $snp_base = $ambiguity ||  substr( $seq, $i+$j, $n);
      $markedup_seq .= sprintf( $tmpl, $snp_base) ;
      $j += $n;
    }
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
      $markedup_seq .= " ".join(qq{;&nbsp;}, @var_list);
    }
    $markedup_seq .= "\n";
  }
  $html = qq(<p>$KEY</p>);
  $html .= "<pre>&gt;@{[ $slice->Obj->name ]}\n$markedup_seq</pre>";

  return $html;
}

sub bin_starts {
  ### Sequence markup uses a 'variable-length bin' approach.
  ### Each bin has a format.
  ### A feature can span multiple bins.
  ### Allows for feature overlaps - combined formats.
  ### Bins start at feature starts, and end at feature ends + 1
  ### Allow for cigar strings - these split alignments into 'mini-features'
  my $self = shift;
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

    foreach my $seg(  @{ $self->cigar_segments($feat) } ) {
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
  my $self = shift;
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
  ### Code to mark up the exons in each bin
  my $self = shift;
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

    foreach my $seg(  @{ $self->cigar_segments($feat) }  ){
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
      }
    }
  }
  return 1;
}

#----------------------------------------------------------------------

sub sort_out_snp_strand {
  ### Arg: variation object
  ### Arg: slice strand
  ### Returns the start of the snp relative to the gene
  ### Returns the snp alleles relative to the orientation of the gene

  my $self = shift;
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

