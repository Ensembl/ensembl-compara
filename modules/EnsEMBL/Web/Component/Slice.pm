package EnsEMBL::Web::Component::Slice;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
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
