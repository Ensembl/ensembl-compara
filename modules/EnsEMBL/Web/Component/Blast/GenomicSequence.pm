package EnsEMBL::Web::Component::Blast::Alignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $ticket = $object->param('ticket');
  my $species = $object->param('species');
  my $run = $object->retrieve_runnable;
  my $hit = $object->retrieve_hit;
  my $hsp = $object->retrieve_hsp;

  $object->param('species')       || return "No species";
  $hsp->can('genomic_hit')        || return "HSP cannot genomic_hit";
  my $feature = $hsp->genomic_hit || return "No genomic_hit";

  my @coord_systems = keys @{$object->fetch_coord_systems};
  @coord_systems = grep{ $hsp->genomic_hit($_) } @coord_systems;

  # check we're using a coordinate system that is valid for this HSP
  # It's quite possible (due to CGI param freezing) that the CGI param
  # might not be valid for the current HSP, but was for the previous one
  # viewed.
  my $csystem = $object->param('display_csystem');
  $csystem = $coord_systems[0] unless $hsp->genomic_hit($csystem);

  ## TODO: Configuration form needs to go in ViewConfig

  ## Define a formatting styles. These correspond to name/value pairs
  ## in HTML style attributes
  my $style_tmpl = qq(<span style="%s" title="%s">%s</span>);
  my %styles = ( DEFAULT =>{},
                 blast_s =>{'color'           =>'darkred',
                            'font-weight'     =>'bold'},
                 blast   =>{'color'           =>'darkblue',
                            'font-weight'     =>'bold'},
                 exon    =>{'background-color'=>'blanchedalmond'},
                 snp     =>{'background-color'=>'#caff70'},
                 snpexon =>{'background-color'=>'#7fff00'} );

  # Print out a format key using the above styles
  my @keys = qw( blast_s blast exon snp snpexon);
  my %key_text = (blast_s=>'Location of selected alignment',
                  blast  =>'Location of other alignments',
                  exon   =>'Location of Exons',
                  snp    =>'Location of SNPs',
                  snpexon=>'Location of exonic SNPs');
  my $key_tmpl = qq(<span class="sequence"> $style_tmpl</span> %s<br>);

  foreach my $key( @keys ){
    if( ! $alignmenttype ){
       next if $key eq 'blast_s';
       next if $key eq 'blast';
    }
    if( $alignmenttype eq 'sel' ){
      next if $key eq 'blast';
    }
    if( ! $snptype ){
      next if $key eq 'snp';
      next if $key eq 'snpexon';
    }
    if( ! $exontype ){
      next if $key eq 'exon';
      next if $key eq 'snpexon';
    }

    my %istyles = %{$styles{$key}};
    my $itext   = $key_text{$key} || 'Unknown';
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    $output_string .= sprintf( $key_tmpl, $style, "", "THIS STYLE:", $itext );
  }

  # Get slice corresponding to top level and  selected coord system
  # Need to reinstate slice adaptor, as this is lost during storage
  my $db_adaptor = $object->DBConnection->get_databases_species($species, 'core')->{'core'};
  my $sl_adaptor = $db_adaptor->get_SliceAdaptor;
  my $tlfeature  = $hsp->genomic_hit;
  my $feature    = $hsp->genomic_hit($csystem);
  my $tlslice    = $tlfeature->feature_Slice();
  my $slice      = $feature->feature_Slice();
  warn ">>> $slice <<<";
  $tlslice->adaptor( $sl_adaptor );
  $slice->adaptor( $sl_adaptor );
  eval {
    my $T = $slice->get_seq_region_id;
  };
  if($@) {
    return "<p><strong>Ill defined slice</strong> - this slice does not belong to the current assembly - perhaps you are using an old blast ticket</p>";
  }
  # Apply orientation
  if( $orientation eq 'fwd' and $slice->strand < 0 ){
    $slice = $slice->invert;
    $tlslice = $tlslice->invert;
  } elsif( $orientation eq 'rev' and $slice->strand > 0 ){
    $slice = $slice->invert;
    $tlslice = $tlslice->invert;
  } elsif( $orientation eq 'hsp' and $feature->hstrand < 0 ) {
    $slice = $slice->invert;
    $tlslice = $tlslice->invert;
  }

    # Apply flanks
  $slice   = $slice->expand( $flank5, $flank3 );
  $tlslice = $tlslice->expand( $flank5, $flank3 );

  # Get slice variables here for efficiency
  my $sstrand = $slice->strand;
  my $sstart  = $slice->start;
  my $send    = $slice->end;
  my $slength = $slice->length;

  # Get all SearchFeatures for this slice from DB using BlastAdaptor
  my @alignments;
  if( $alignmenttype eq 'all' ){
    my $use_date = $hsp->use_date;
    my $bl_adaptor = $object->adaptor;
    my @hsps = @{ $bl_adaptor->get_all_HSPs( "$ticket!!$use_date",
                                             $tlslice->seq_region_name,
                                             $tlslice->start,
                                             $tlslice->end ) };
    @alignments = map{$_->genomic_hit($csystem) || ()} @hsps;
  }
  elsif( $alignmenttype eq 'sel' ){
    @alignments = ( $feature );
  }
  if( $alignmentori eq 'fwd' ){ # Only fwd strand alignments
    @alignments = grep{($_->strand * ($_->hstrand||1)) eq $slice->strand } @alignments
  } elsif(  $alignmentori eq 'rev' ){ # Only rev strand alignments
    @alignments = grep{($_->strand * ($_->hstrand||1)) ne $slice->strand } @alignments
  }

  # Get all exons for this slice
  my @exons = ();
  my @snps  = ();
  warn( "$sp - $exontype ", $slice->name );
  if( $exontype eq 'core'){
    @exons = @{$slice->get_all_Exons};
  } elsif( $exontype eq 'prediction' ){
    @exons = (
      grep{ $_->seq_region_start<=$send && $_->seq_region_end>=$sstart }
      map { @{$_->get_all_Exons } } @{$slice->get_all_PredictionTranscripts }
    );
  } elsif( $exontype eq 'vega'){
    my $db_adaptor = $object->DBConnection->get_databases_species($species, 'vega')->{'vega'};
    $slice->adaptor->db->add_db_adaptor($exontype,$db_adaptor);
    @exons = (
      grep{ $_->seq_region_start<=$send && $_->seq_region_end>=$sstart }
      map{@{$_->get_all_Exons } } @{$slice->get_all_Genes('',$exontype) }
    );
  } elsif( $exontype eq 'estgene'){
    my $db_adaptor = $object->DBConnection->get_databases_species($species, 'est')->{'est'};
    $slice->adaptor->db->add_db_adaptor($exontype,$db_adaptor);
    @exons = (
      grep{ $_->seq_region_start<=$send && $_->seq_region_end>=$sstart }
      map{@{$_->get_all_Exons } } @{$slice->get_all_Genes('',$exontype) }
    );
  }
  if( $exonori eq 'fwd' ){ # Only fwd strand exons
    @exons = grep{$_->strand > 0} @exons
  } elsif( $exonori eq 'rev' ){ #Only rev strand exons
    @exons = grep{$_->strand < 0} @exons
  }

  # Sequence markup uses a 'variable-length bin' approach.
  # Each bin has a format.
  # Allows for feature overlaps - combined formats.
  # Bins start at feature starts, and 1 + feature ends.
  # Allow for cigar strings - these split alignments into 'mini-features'.
  # A feature can span multiple bins

  # Get a unique list of all possible bin starts
  my %all_locs = ( 1=>1, $slength+1=>1 );
  foreach my $feat( @exons , @alignments ){ #
    my $cigar;
    if( $feat->can('cigar_string') ){ $cigar = $feat->cigar_string }
    $cigar ||= $feat->length . "M"; # Fake cigar; matches length of feat
    my $fstart  = $feat->seq_region_start - $sstart + 1;
    my $fstrand = $feat->seq_region_strand;
    if( $fstart > $slength+1 ){ $fstart = $slength+1 }
    $fstart > 0 ? $all_locs{$fstart} ++ : $all_locs{1} ++;
    my @segs = ( $cigar =~ /(\d*\D)/g ); # Split cigar into segments
    if( $fstrand < 1 ){ @segs = reverse( @segs ) } # if -ve ori, invert cigar
    foreach my $seg( @segs ){
      my $type = chop( $seg ); # Remove seg type - length remains
      next if( $type eq 'D' ); # Ignore deletes
      $fstart += $seg;
      if( $fstart > $slength+1 ){ $fstart = $slength+1 }
      $fstart > 0 ? $all_locs{$fstart} ++ : $all_locs{1} ++;
    }
  }
  foreach my $snp( @snps ){
    my $fstart = $snp->start;
    if( $sstrand < 0 ){ $fstart = $slength - $fstart + 1} # SNP strand bug
    $all_locs{$fstart} ++;
    $all_locs{$fstart+1} ++;
  }

  # Initialise bins; lengths and formats
  my @bin_locs = sort{ $a<=>$b } ( keys %all_locs );
  my %bin_idx; # A hash index of bin start locations vs pos in index
  my @bin_markup;
  for( my $i=0; $i<@bin_locs; $i++ ){
    my $bin_start  = $bin_locs[$i];
    my $bin_end    = $bin_locs[$i+1] || last;
    my $bin_length = $bin_end - $bin_start;
    #$bin_length || next;
    $bin_idx{$bin_start} = $i;
    $bin_markup[$i] = [ $bin_length, {} ]; # Init bin, and flag as empty
  }

  # Populate bins with exons
  my %estyles = %{$styles{exon}};
  foreach my $feat( @exons ){
    my $fstart = $feat->seq_region_start - $sstart + 1;
    my $fend   = $feat->seq_region_end - $sstart + 2;
    my $idx_start = $fstart > 0 ? $bin_idx{$fstart} : $bin_idx{1};
    my $idx_end   = ( $bin_idx{$fend} ? $bin_idx{$fend} : @bin_markup )-1;
    # Add styles + title to affected bins
    my $title = $feat->stable_id;
    foreach my $bin( @bin_markup[ $idx_start..$idx_end ] ){
      # Add styles to bins
      map{ $bin->[1]->{$_} = $estyles{$_} } keys %estyles;
      # Add stable ID to bin title
      $bin->[2] = join( ' : ', $bin->[2] || (), $title );
    }
    #map{ substr( $_->[1], 1, 1 ) = 'Y' }
    #  @bin_markup[ $idx_start..$idx_end ] # Flag matched bins!
  }
  # Populate bins with snps
  my %snpstyles = %{$styles{snp}};
  my %snpexonstyles = %{$styles{snpexon}};
  foreach my $snp( @snps ){
    my $fstart = $snp->start;
    if( $sstrand < 0 ){ $fstart = $slength - $fstart + 1 } # SNP strand bug
    my $idx_start = $bin_idx{$fstart};
    my $bin = $bin_markup[$idx_start];
    my %usestyles = ( $bin->[1]->{'background-color'} ?
                      %snpexonstyles : %snpstyles );
    map{ $bin->[1]->{$_} = $usestyles{$_} } keys %usestyles;
    my $allele = $snp->alleles;
    if( $snp->strand != $sstrand ){
      $allele = reverse( $allele );
      $allele =~ tr/ACGTacgt/TGCAtgca/;
    }
    $bin->[2] = $allele || '';
  }
  # Populate bins with blast align features
  foreach my $feat( @alignments ){
    my $fstart  = $feat->seq_region_start - $sstart + 1;
    my $fstrand = $feat->seq_region_strand;
    my @segs = ( $feat->cigar_string =~ /(\d*\D)/g ); # Segment cigar
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
      my %istyles = %{$styles{blast}};
      foreach my $bin( @bin_markup[ $idx_start..$idx_end ] ){
        map{ $bin->[1]->{$_} = $istyles{$_} } keys %istyles;
      }
      #map{ substr( $_->[1], 0, 1 ) = $type eq 'M' ? 'Y' : 'N' }
      #  @bin_markup[ $idx_start..$idx_end ] # Flag matched bins!
    }
  }
  # Populate bins with selected blast align features
  if( @alignments ){
    foreach my $feat( $feature ){
      my $fstart  = $feat->seq_region_start - $sstart + 1;
      my $fstrand = $feat->seq_region_strand;
      my @segs = ( $feat->cigar_string =~ /(\d*\D)/g ); # Segment cigar
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
        my %istyles = %{$styles{blast_s}};
        foreach my $bin( @bin_markup[ $idx_start..$idx_end ] ){
          map{ $bin->[1]->{$_} = $istyles{$_} } keys %istyles;
        }
      }
    }
  }

  # If strand is -ve ori, invert bins
  if( $sstrand < 1 ){ @bin_markup = reverse( @bin_markup ) }

  # Turn the 'bin markup' style hashes into style templates
  foreach my $bin( @bin_markup ){
    my %istyles = %{$bin->[1]};
    my $style = join( ';',map{"$_:$istyles{$_}"} keys %istyles );
    my $title = $bin->[2] || '';
    $bin->[1] = sprintf( $style_tmpl, $style, $title, '%s' );
  }

  # Create the marked-up FASTA-like string from the sequence and cigar mask
  my $seq    = $slice->seq;
  my $chars  = 60;
  my $length = length( $seq );

  my $markedup_seq = '';
  my $numlength = '';
  if( $linenums eq 'gen' ){ $numlength = length( $send ) }
  if( $linenums eq 'seq' ){ $numlength = length( $length ) }
  my $numtmpl   = "%${numlength}d ";
  my $i = 0;
  while( $i < $length ){

    if( $linenums ){ # Deal with line numbering
      my $num = $i + 1;
      if( $linenums eq 'gen' ){
        if( $sstrand > 0 ){ $num = $sstart + $num - 1 }
        else              { $num = $send   - $num + 1 }
      };
      $markedup_seq .= sprintf($numtmpl, $num )
    }
    my $j = 0;
    while( $j < $chars ){
      my $markup = shift @bin_markup|| last;
      my( $n, $tmpl ) = @$markup; # Length and template of markup
      if( ! $n ){ next }
      if( $n > $chars-$j ){ # Markup extends over line end. Adapt for next line
        unshift( @bin_markup, [ $n-($chars-$j), $tmpl ] );
        $n = $chars-$j;
      }
      $markedup_seq .= sprintf( $tmpl, substr( $seq, $i+$j, $n) );
      $j += $n;
    }
    #$markedup_seq .= "\n".substr( $seq, $i+1, $chars ); # DEBUG
    $i += $chars;
    if( $linenums ){
      my $incomplete = $chars-$j;
      $markedup_seq .= ' ' x $incomplete;
      my $num = $i - $incomplete;
      if( $linenums eq 'gen' ){
        if( $sstrand > 0 ){ $num = $sstart + $num - 1 }
        else              { $num = $send   - $num + 1 }
      };
      $markedup_seq .= " $num";
    };
    $markedup_seq .= "\n";
  }
  $html .= sprintf( qq($output_string
<pre><span class="sequence">&gt;%s
%s</span></pre>), $slice->name, $markedup_seq);

  $html .= $self->add_links('genomic');

  return $html;
}

1;
