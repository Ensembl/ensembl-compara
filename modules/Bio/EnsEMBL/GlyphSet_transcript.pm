package Bio::EnsEMBL::GlyphSet_transcript;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
no warnings "uninitialized";

use Time::HiRes;

sub text_label { return undef; } 
sub gene_text_label { return undef; } 

sub features { return []; }

sub href { return undef; }
sub gene_href { return undef; }

## Let us define all the renderers here...
## ... these are just all wrappers - the parameter is 1 to draw labels
## ... 0 otherwise...

sub render_gene_label            { my $self = shift; $self->render_genes(1); }
sub render_gene_nolabel          { my $self = shift; $self->render_genes(0); }
sub render_collapsed_label       { my $self = shift; $self->render_collapsed(1); }
sub render_collapsed_nolabel     { my $self = shift; $self->render_collapsed(0); }
sub render_transcript_label      { my $self = shift; $self->render_transcripts(1); }
sub render_transcript            { my $self = shift; $self->render_transcripts(1); }
sub render_normal                { my $self = shift; $self->render_transcripts(1); }
sub render_transcript_nolabel    { my $self = shift; $self->render_transcripts(0); }
sub render_as_transcript_label   { my $self = shift; $self->render_alignslice_transcript(1); }
sub render_as_transcript_nolabel { my $self = shift; $self->render_alignslice_transcript(0); }
sub render_as_collapsed_label    { my $self = shift; $self->render_alignslice_collapsed(1); }
sub render_as_collapsed_nolabel  { my $self = shift; $self->render_alignslice_collapsed(0); }


sub render_collapsed {
  my ($self, $labels) = @_;

  return $self->render_text('transcript', 'collapsed') if $self->{'text_export'};
  
  my $config           = $self->{'config'};
  my $container        = $self->{'container'}{'ref'} || $self->{'container'};
  my $length           = $container->length;
  my $selected_db      = $self->core('db');
  my $selected_gene    = $self->core('g');
  my $pix_per_bp       = $self->scalex;
  my $strand           = $self->strand;
  my $strand_flag      = $self->my_config('strand');
  my $db               = $self->my_config('db');
  my $show_labels      = $self->my_config('show_labels');
  my $previous_species = $self->my_config('previous_species');
  my $next_species     = $self->my_config('next_species');
  my $link             = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $y                = 0;
  my $h                = 8;
  my $join_z           = -10;
  my $join_col1        = 'blue';
  my $join_col2        = 'chocolate1';
  my $transcript_drawn = 0;
  my %used_colours;
  
  my ($fontname, $fontsize) = $self->get_font_details('outertext');
  
  $self->_init_bump; 
  
  my ($txt, $bit, $w, $th) = $self->get_text_width(0, 'Xg', 'Xg', 'ptsize' => $fontsize, 'font' => $fontname);
  
  # For alternate splicing diagram only draw transcripts in gene
  foreach my $gene (@{$self->features}) {
    my $gene_strand = $gene->strand;
    
    next if $gene_strand != $strand && $strand_flag eq 'b';
    
    # Get all the exons which overlap the region for this gene
    my @exons = map { $_->start > $length || $_->end < 1 ? () : $_ } map { @{$_->get_all_Exons} } @{$gene->get_all_Transcripts};
    
    next unless @exons;
    
    $transcript_drawn = 1;
    
    my $gene_stable_id = $gene->stable_id;
    my $gene_key       = $self->gene_key($gene);
    my $colour         = $self->my_colour($gene_key);
    my $label          = $self->my_colour($gene_key, 'text');
    my $highlight      = $selected_db eq $db && $selected_gene eq $gene_stable_id && $gene_stable_id ? 'highlight1' : undef;
    
    $used_colours{$label} = $colour;
    
    my $composite = $self->Composite({
      y      => $y,
      height => $h,
      title  => $self->gene_title($gene),
      href   => $self->gene_href($gene)
    });
    
    my $composite2 = $self->Composite({ y => $y, height => $h });
    
    foreach my $exon (@exons) {
      my $s   = $exon->start;
      my $e   = $exon->end;
      
      $s = 1 if $s < 0;
      $e = $length if $e > $length;
      
      $composite2->push($self->Rect({
        x         => $s - 1,
        y         => $y,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $colour,
        absolutey => 1
      }));
    }
    
    my $start = $gene->start < 1 ? 1 : $gene->start;
    my $end   = $gene->end > $length ? $length : $gene->end;
    
    $composite2->push($self->Rect({
      x         => $start, 
      y         => int($y + $h/2), 
      width     => $end - $start + 1,
      height    => 0, 
      colour    => $colour, 
      absolutey => 1
    }));
    
    if ($link) {
      my @gene_tags;
      
      if ($gene_stable_id) {
        my $alt_alleles = $gene->get_all_alt_alleles;
        
        if ($previous_species) {
          $self->join_tag($composite2, "$gene_stable_id:$_", 0.5, 0.5, $join_col1, 'line', $join_z) for $self->get_homologous_gene_ids($gene, $previous_species);
          push @gene_tags, map { join '=', $_->stable_id, $gene_stable_id } @$alt_alleles;
        }
        
        if ($next_species) {
          $self->join_tag($composite2, "$_:$gene_stable_id", 0.5, 0.5, $join_col1, 'line', $join_z) for $self->get_homologous_gene_ids($gene, $next_species);
          push @gene_tags, map { join '=', $gene_stable_id, $_->stable_id } @$alt_alleles;
        }
      }
      
      # join alt_alleles
      $self->join_tag($composite2, $_, 0.5, 0.5, $join_col2, 'line', $join_z) for @gene_tags;
    }
    
    $composite->push($composite2);
    
    my $bump_height = $h + 2;
    
    if ($show_labels ne 'off' && $labels) {
      if (my $text_label = $self->gene_text_label($gene)) {
        my @lines = split "\n", $text_label;
        $lines[0] = "< $lines[0]" if $strand < 1;
        $lines[0] = "$lines[0] >" if $strand >= 1;
        
        for (my $i = 0; $i < @lines; $i++){
          my $line = "$lines[$i] ";
          my ($txt, $bit, $w,$th2) = $self->get_text_width(0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname);
          
          $composite->push($self->Text({
            x         => $composite->x,
            y         => $y + $h + $i * ($th + 1),
            height    => $th,
            width     => $w / $pix_per_bp,
            font      => $fontname,
            ptsize    => $fontsize,
            halign    => 'left',
            colour    => $colour,
            text      => $line,
            absolutey => 1
          }));
          
          $bump_height += $th + 1;
        }
      }
    }
    
    # bump
    my $bump_start = int($composite->x * $pix_per_bp);
    my $bump_end = $bump_start + int($composite->width * $pix_per_bp) + 1;
    
    my $row = $self->bump_row($bump_start, $bump_end);
    
    # shift the composite container by however much we're bumped
    $composite->y($composite->y - $strand * $bump_height * $row);
    $composite->colour($highlight) if defined $highlight;
    $self->push($composite);
  }

  if ($transcript_drawn) {
    my $type = $self->my_config('name');
    my %legend_old = @{$config->{'legend_features'}{$type}{'legend'}||[]};
    
    $used_colours{$_} = $legend_old{$_} for keys %legend_old;
    
    my @legend = %used_colours;
    
    $config->{'legend_features'}{$type} = {
      priority => $self->_pos,
      legend   => \@legend
    };
  } elsif ($config->get_parameter('opt_empty_tracks') != 0) {
    $self->errorTrack(sprintf 'No %s in this region', $self->error_track_name);
  }
}

sub render_transcripts {
  my ($self, $labels) = @_;

  return $self->render_text('transcript') if $self->{'text_export'};
  
  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $selected_db       = $self->core('db');
  my $selected_gene     = $self->core('g');
  my $selected_trans    = $self->core('t');
  my $pix_per_bp        = $self->scalex;
  my $strand            = $self->strand;
  my $strand_flag       = $self->my_config('strand');
  my $db                = $self->my_config('db');
  my $show_labels       = $self->my_config('show_labels');
  my $previous_species  = $self->my_config('previous_species');
  my $next_species      = $self->my_config('next_species');
  my $link              = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $target            = $self->get_parameter('single_Transcript');
  my $target_gene       = $self->get_parameter('single_Gene');
  my $y                 = 0;
  my $h                 = $self->my_config('height') || ($target ? 30 : 8); # Single transcript mode - set height to 30 - width to 8
  my $join_z            = -10;
  my $join_col1         = 'blue';
  my $join_col2         = 'chocolate1';
  my $transcript_drawn  = 0;
  my $non_coding_height = ($self->my_config('non_coding_scale')||0.75) * $h;
  my $non_coding_start  = ($h - $non_coding_height) / 2;
  my %used_colours;
  
  my ($fontname, $fontsize) = $self->get_font_details('outertext');
  
  $self->_init_bump;
  
  my ($txt, $bit, $w, $th) = $self->get_text_width(0, 'Xg', 'Xg', 'ptsize' => $fontsize, 'font' => $fontname);
  
  # For alternate splicing diagram only draw transcripts in gene
  foreach my $gene (@{$self->features}) {
    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    
    next if $gene_strand != $strand && $strand_flag eq 'b'; # skip features on wrong strand
    next if $target_gene && $gene_stable_id ne $target_gene;
    
    my %tags;
    my @gene_tags;
    my $tsid;
    
    if ($link && $gene_stable_id) {
      my $alt_alleles = $gene->get_all_alt_alleles;
      my $alltrans    = $gene->get_all_Transcripts; # vega stuff to link alt-alleles on longest transcript
      my @s_alltrans  = sort { $a->length <=> $b->length } @$alltrans;
      my $long_trans  = pop @s_alltrans;
      my @transcripts;
      
      $tsid = $long_trans->stable_id;
      
      foreach my $gene (@$alt_alleles) {
        my $vtranscripts = $gene->get_all_Transcripts;
        my @sorted_trans = sort { $a->length <=> $b->length } @$vtranscripts;
        push @transcripts, (pop @sorted_trans);
      }
      
      if ($previous_species) {
        my ($sid, $pid, $homologues, $homologue_genes) = $self->get_homologous_peptide_ids_from_gene($gene, $previous_species);
        
        push @{$tags{$sid}}, map "$_:$pid", @$homologues if $sid && $pid;
        push @{$tags{$sid}}, map "$gene_stable_id:$_", @$homologue_genes if $sid;
        push @gene_tags, map { join '=', $_->stable_id, $tsid } @transcripts;
      }
      
      if ($next_species) {
        my ($sid, $pid, $homologues, $homologue_genes) = $self->get_homologous_peptide_ids_from_gene($gene, $next_species);
        
        push @{$tags{$sid}}, map "$pid:$_", @$homologues if $sid && $pid;
        push @{$tags{$sid}}, map "$_:$gene_stable_id", @$homologue_genes if $sid;
        push @gene_tags, map { join '=', $tsid, $_->stable_id } @transcripts;
      }
    }
    
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      my $transcript_stable_id = $transcript->stable_id;
      
      next if $transcript->start > $length || $transcript->end < 1;
      
      my @exons = sort { $a->start <=> $b->start } grep { $_ } @{$transcript->get_all_Exons}; # sort exons on their start coordinate 
      
      next unless scalar @exons; # Skip if no exons for this transcript
      next if @exons[0]->strand != $gene_strand && $self->{'do_not_strand'} != 1; # If stranded diagram skip if on wrong strand
      next if $target && $transcript->stable_id ne $target; # For exon_structure diagram only given transcript
      
      $transcript_drawn = 1;        

      my $composite = $self->Composite({
        y      => $y,
        height => $h,
        title  => $self->title($transcript, $gene),
        href   => $self->href($gene, $transcript)
      });

      my $colour_key = $self->transcript_key($transcript, $gene);
      my $colour     = $self->my_colour($colour_key);
      my $label      = $self->my_colour($colour_key, 'text');
      my $highlight  = $selected_db eq $db && $transcript_stable_id ? (
        $selected_trans eq $transcript_stable_id ? 'highlight2' :
        $selected_gene  eq $gene_stable_id       ? 'highlight1' : undef 
      ) : undef;
      
      $highlight = $self->my_colour('ccds_hi') || 'lightblue1' if $transcript->get_all_Attributes('ccds')->[0]; # use another highlight colour if the trans has got a CCDS attrib

      ($colour, $label) = ('orange', 'Other') unless $colour;
      $used_colours{$label} = $colour;
      
      my $coding_start = defined $transcript->coding_region_start ? $transcript->coding_region_start : -1e6;
      my $coding_end   = defined $transcript->coding_region_end   ? $transcript->coding_region_end   : -1e6;
      
      my $composite2 = $self->Composite({ y => $y, height => $h });
            
      if ($transcript->translation) {
        $self->join_tag($composite2, $_, 0.5, 0.5, $join_col1, 'line', $join_z) for @{$tags{$transcript->translation->stable_id}||[]};
      }
      
      if ($transcript->stable_id eq $tsid) {
        $self->join_tag($composite2, $_, 0.5, 0.5, $join_col2, 'line', $join_z) for @gene_tags;
      }
      
      for (my $i = 0; $i < @exons; $i++) {
        my $exon = @exons[$i];
        
        next unless defined $exon; # Skip this exon if it is not defined (can happen w/ genscans) 
        
        my $next_exon = ($i < $#exons) ? @exons[$i+1] : undef; # First draw the exon
        
        last if $exon->start > $length; # We are finished if this exon starts outside the slice
        
        my ($box_start, $box_end);
        
        # only draw this exon if is inside the slice
        if ($exon->end > 0) { 
          # calculate exon region within boundaries of slice
          $box_start = $exon->start;
          $box_start = 1 if $box_start < 1 ;
          $box_end = $exon->end;
          $box_end = $length if $box_end > $length;
          
          # The start of the transcript is before the start of the coding
          # region OR the end of the transcript is after the end of the
          # coding regions.  Non coding portions of exons, are drawn as
          # non-filled rectangles
          # Draw a non-filled rectangle around the entire exon
          if ($box_start < $coding_start || $box_end > $coding_end) {
            $composite2->push($self->Rect({
              x            => $box_start - 1 ,
              y            => $y + $non_coding_start,
              width        => $box_end - $box_start + 1,
              height       => $non_coding_height,
              bordercolour => $colour,
              absolutey    => 1
             }));
           }
           
           # Calculate and draw the coding region of the exon
           my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
           my $filled_end   = $box_end > $coding_end ? $coding_end : $box_end;
           
           # only draw the coding region if there is such a region
           if ($filled_start <= $filled_end ) {
              # Draw a filled rectangle in the coding region of the exon
              $composite2->push($self->Rect({
                x         => $filled_start - 1,
                y         => $y,
                width     => $filled_end - $filled_start + 1,
                height    => $h,
                colour    => $colour,
                absolutey => 1
              }));
          }
        }
        
        # we are finished if there is no other exon defined
        last unless defined $next_exon;

        my $intron_start = $exon->end + 1; # calculate the start and end of this intron
        my $intron_end = $next_exon->start - 1;
        
        next if $intron_end < 0;         # grab the next exon if this intron is before the slice
        last if $intron_start > $length; # we are done if this intron is after the slice
        
        # calculate intron region within slice boundaries
        $box_start = $intron_start < 1 ? 1 : $intron_start;
        $box_end   = $intron_end > $length ? $length : $intron_end;
        
        my $intron;
        
        if ($box_start == $intron_start && $box_end == $intron_end) {
          # draw an wholly in slice intron
          $composite2->push($self->Intron({
            x         => $box_start - 1,
            y         => $y,
            width     => $box_end - $box_start + 1,
            height    => $h,
            colour    => $colour,
            absolutey => 1,
            strand    => $strand
          }));
        } else { 
          # else draw a "not in slice" intron
          $composite2->push($self->Line({
            x         => $box_start - 1 ,
            y         => $y + int($h/2),
            width     => $box_end - $box_start + 1,
            height    => 0,
            absolutey => 1,
            colour    => $colour,
            dotted    => 1
          }));
        }
      }
      
      $composite->push($composite2);
      
      my $bump_height = 1.5 * $h;
      
      if ($show_labels ne 'off' && $labels) {
        if (my $text_label = $self->text_label($gene, $transcript)) {
          my @lines = split "\n", $text_label; 
          $lines[0] = "< $lines[0]" if $strand < 1;
          $lines[0] = "$lines[0] >" if $strand >= 1;
          
          for (my $i = 0; $i < @lines; $i++) {
            my $line = "$lines[$i] ";
            my ($txt, $bit, $w, $th2) = $self->get_text_width(0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname);
            
            $composite->push($self->Text({
              x         => $composite->x,
              y         => $y + $h + $i*($th+1),
              height    => $th,
              width     => $w / $pix_per_bp,
              font      => $fontname,
              ptsize    => $fontsize,
              halign    => 'left', 
              colour    => $colour,
              text      => $line,
              absolutey => 1
            }));
            
            $bump_height += $th + 1;
          }
        }
      }

      # bump
      my $bump_start = int($composite->x * $pix_per_bp);
      my $bump_end = $bump_start + int($composite->width * $pix_per_bp) + 1;
      my $row = $self->bump_row($bump_start, $bump_end);
      
      # shift the composite container by however much we're bumped
      $composite->y($composite->y - $strand * $bump_height * $row);
      $composite->colour($highlight) if defined $highlight && !defined $target;
      $self->push($composite);
    }
  }
  
  if ($transcript_drawn) {
    my $type = $self->_type;
    my %legend_old = @{$config->{'legend_features'}{$type}{'legend'}||[]};
    
    $used_colours{$_} = $legend_old{$_} for keys %legend_old;

    my @legend = %used_colours;
    
    $config->{'legend_features'}->{$type} = {
      priority => $self->_pos,
      legend   => \@legend
    };
  } elsif ($config->get_parameter('opt_empty_tracks') != 0) {
    $self->errorTrack(sprintf 'No %s in this region', $self->error_track_name);
  }
}

sub render_alignslice_transcript {
  my ($self, $labels) = @_;

  return $self->render_text('transcript') if $self->{'text_export'};

  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $selected_db       = $self->core('db');
  my $selected_gene     = $self->core('g');
  my $selected_trans    = $self->core('t');
  my $pix_per_bp        = $self->scalex;
  my $strand            = $self->strand;
  my $strand_flag       = $self->my_config('strand');
  my $db                = $self->my_config('db');
  my $show_labels       = $self->my_config('show_labels');
  my $target            = $self->get_parameter('single_Transcript');
  my $target_gene       = $self->get_parameter('single_Gene');
  my $y                 = 0;
  my $h                 = $self->my_config('height') || ($target ? 30 : 8); # Single transcript mode - set height to 30 - width to 8
  my $mcolour           = 'green'; # Colour to use to display missing exons
  my $transcript_drawn  = 0;
  my %used_colours;

  my ($fontname, $fontsize) = $self->get_font_details('outertext');
  
  $self->_init_bump;
  
  foreach my $gene (@{$self->features}) {
    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    
    next if $gene_strand != $strand && $strand_flag eq 'b'; # skip features on wrong strand
    next if $target_gene && $gene_stable_id ne $target_gene;
    
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      next if $transcript->start > $length || $transcript->end < 1;
      
      my @exons = $self->map_AlignSlice_Exons($transcript, $length);
      
      next if scalar @exons == 0;
      
      # For exon_structure diagram only given transcript
      next if $target && $transcript->stable_id ne $target;
      
      $transcript_drawn = 1;
      
      my $composite = $self->Composite({ 
        y      => $y, 
        height => $h,
        title  => $self->title($transcript, $gene),
        href   => $self->href($gene, $transcript)
      });
      
      my $transcript_stable_id = $transcript->stable_id;
      
      my $colour_key = $self->transcript_key($transcript, $gene);    
      my $colour     = $self->my_colour($colour_key);
      my $label      = $self->my_colour($colour_key, 'text');
      
      my $highlight = $selected_db eq $db && $transcript_stable_id ? (
        $selected_trans eq $transcript_stable_id ? 'highlight2' : 
        $selected_gene  eq $gene_stable_id       ? 'highlight1' : undef 
      ) : undef;
      
      ($colour, $label) = ('orange', 'Other') unless $colour;
      $used_colours{$label} = $colour; 
      
      my $coding_start = defined $transcript->coding_region_start ? $transcript->coding_region_start :  -1e6;
      my $coding_end   = defined $transcript->coding_region_end   ? $transcript->coding_region_end   :  -1e6;

      my $composite2 = $self->Composite({ y => $y, height => $h });
      
      # now draw exons
      for (my $i = 0; $i < scalar @exons; $i++) {
        my $exon = @exons[$i];
        
        next unless defined $exon; # Skip this exon if it is not defined (can happen w/ genscans) 
        last if $exon->start > $length; # We are finished if this exon starts outside the slice
        
        my ($box_start, $box_end);
        
        # only draw this exon if is inside the slice
        if ($exon->end > 0) { # calculate exon region within boundaries of slice
          $box_start = $exon->start;
          $box_start = 1 if $box_start < 1 ;
          $box_end = $exon->end;
          $box_end = $length if $box_end > $length;
          
          # The start of the transcript is before the start of the coding
          # region OR the end of the transcript is after the end of the
          # coding regions.  Non coding portions of exons, are drawn as
          # non-filled rectangles
          # Draw a non-filled rectangle around the entire exon
          if ($box_start < $coding_start || $box_end > $coding_end) {
            $composite2->push($self->Rect({
              x            => $box_start - 1,
              y            => $y + $h/8,
              width        => $box_end - $box_start + 1,
              height       => 3 * $h/4,
              bordercolour => $colour,
              absolutey    => 1
            }));
          }
          
          # Calculate and draw the coding region of the exon
          my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
          my $filled_end   = $box_end > $coding_end     ? $coding_end   : $box_end;
          # only draw the coding region if there is such a region
          
          # Draw a filled rectangle in the coding region of the exon
          if ($filled_start <= $filled_end) {
            $composite2->push($self->Rect({
              x         => $filled_start - 1,
              y         => $y,
              width     => $filled_end - $filled_start + 1,
              height    => $h,
              colour    => $colour,
              absolutey => 1
            }));
          }
        } 
        
        my $next_exon = $i < $#exons ? @exons[$i+1] : undef;
        
        last unless defined $next_exon; # we are finished if there is no other exon defined

        my $intron_start = $exon->end + 1; # calculate the start and end of this intron
        my $intron_end = $next_exon->start - 1;
        
        next if $intron_end < 0;         # grab the next exon if this intron is before the slice
        last if $intron_start > $length; # we are done if this intron is after the slice
          
        # calculate intron region within slice boundaries
        $box_start = $intron_start < 1 ? 1 : $intron_start;
        $box_end   = $intron_end > $length ? $length : $intron_end;
        
        my $intron;
        
        # Usual stuff if it is not missing exon
        if ($exon->{'exon'}->{'etype'} ne 'M') {
          if ($box_start == $intron_start && $box_end == $intron_end) {
            # draw an wholly in slice intron
            $composite2->push($self->Intron({
              x         => $box_start - 1,
              y         => $y,
              width     => $box_end - $box_start + 1,
              height    => $h,
              colour    => $colour,
              absolutey => 1,
              strand    => $strand
            }));
          } else {
            # else draw a "not in slice" intron
            $composite2->push($self->Line({
              x         => $box_start - 1,
              y         => $y + int($h/2),
              width     => $box_end-$box_start + 1,
              height    => 0,
              absolutey => 1,
              colour    => $colour,
              dotted    => 1
            }));
          }
        } else {
          # Missing exon - draw a dotted line
          $composite2->push($self->Line({
            x         => $box_start - 1,
            y         => $y + int($h/2),
            width     => $box_end-$box_start + 1,
            height    => 0,
            absolutey => 1,
            colour    => $mcolour,
            dotted    => 1
          }));
        }
      }
      
      $composite->push($composite2);
      
      my $bump_height = 1.5 * $h;
      
      if ($show_labels ne 'off' && $labels) {
        if (my $text_label = $self->text_label($gene, $transcript)) {
          my @lines = split "\n", $text_label;
          
          for (my $i = 0; $i < scalar @lines; $i++) {
            my $line = $lines[$i];
            my ($txt, $bit, $w, $th) = $self->get_text_width(0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname);
            
            $composite->push($self->Text({
              x         => $composite->x,
              y         => $y + $h + $i * ($th + 1),
              height    => $th,
              width     => $w / $pix_per_bp,
              font      => $fontname,
              ptsize    => $fontsize,
              halign    => 'left',
              colour    => $colour,
              text      => $line,
              absolutey => 1
            }));
            
            $bump_height += $th + 1;
          }
        }
      }
      
      # bump
      my $bump_start = int($composite->x * $pix_per_bp);
      my $bump_end = $bump_start + int($composite->width * $pix_per_bp) + 1;
      
      my $row = $self->bump_row($bump_start, $bump_end);
      
      # shift the composite container by however much we've bumped
      $composite->y($composite->y - $strand * $bump_height * $row);
      $composite->colour($highlight) if defined $highlight && !defined $target;
      $self->push($composite);
      
      if ($target) {
        # check the strand of one of the transcript's exons
        my ($trans_exon) = @{$transcript->get_all_Exons};
        
        if ($trans_exon->strand == 1) {
          $self->push($self->Line({
            x         => 0,
            y         => -4,
            width     => $length,
            height    => 0,
            absolutey => 1,
            colour    => $colour
          }));
          
          $self->push($self->Poly({
            points    => [
               $length - 4/$pix_per_bp, -2,
               $length,                 -4,
               $length - 4/$pix_per_bp, -6
            ],
            absolutey => 1,
            colour    => $colour
          }));
        } else {
          $self->push($self->Line({
            x         => 0,
            y         => $h + 4,
            width     => $length,
            height    => 0,
            absolutey => 1,
            colour    => $colour
          }));
            
          $self->push($self->Poly({
            points    => [ 
              4/$pix_per_bp, $h + 6,
              0,             $h + 4,
              4/$pix_per_bp, $h + 2
            ],
            absolutey => 1,
            colour    => $colour
          }));
        }
      }  
    }
  }
  
  if ($transcript_drawn) {
    my $type = $self->_type;
    my @legend = %used_colours;
    
    $config->{'legend_features'}->{$type} = {
      priority => $self->_pos,
      legend   => \@legend
    };
  } elsif ($config->get_parameter('opt_empty_tracks') != 0) {
    $self->errorTrack(sprintf 'No %s in this region', $self->error_track_name);
  }
}

sub render_alignslice_collapsed {
  my ($self, $labels) = @_;
  
  return $self->render_text('transcript') if $self->{'text_export'};

  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $selected_db       = $self->core('db');
  my $selected_gene     = $self->core('g');
  my $pix_per_bp        = $self->scalex;
  my $strand            = $self->strand;
  my $strand_flag       = $self->my_config('strand');
  my $db                = $self->my_config('db');
  my $show_labels       = $self->my_config('show_labels');
  my $y                 = 0;
  my $h                 = 8;
  my $transcript_drawn  = 0;
  my %used_colours;
  
  my ($fontname, $fontsize) = $self->get_font_details('outertext');
  
  $self->_init_bump;
  
  foreach my $gene (@{$self->features}) {
    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->stable_id;
    
    next if $gene_strand != $strand && $strand_flag eq 'b';
    
    my $composite = $self->Composite({ 
      y      => $y, 
      height => $h,
      title  => $self->gene_title($gene),
      href   => $self->gene_href($gene)
    });
    
    my $colour_key = $self->gene_key($gene);    
    my $colour     = $self->my_colour($colour_key);
    my $label      = $self->my_colour($colour_key, 'text');
    my $highlight    = $selected_db eq $db && $selected_gene eq $gene_stable_id && $gene_stable_id ? 'highlight1' : undef;
    
    ($colour, $label) = ('orange', 'Other') unless $colour;
    
    $used_colours{$label} = $colour;
    
    my @exons;
    
    # In compact mode we 'collapse' exons showing just the gene structure, i.e overlapping exons/transcripts will be merged
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      next if $transcript->start > $length ||  $transcript->end < 1;
      push @exons, $self->map_AlignSlice_Exons($transcript, $length);
    }
    
    next unless @exons;
    
    my $composite2 = $self->Composite({ y => $y, height => $h });
    
    # All exons in the gene will be connected by a simple line which starts from a first exon if it within the viewed region, otherwise from the first pixel. 
    # The line ends with last exon of the gene or the end of the image
    my $start = $exons[0]->{'exon'}->{'etype'} eq 'B' ? 1 : 0;       # Start line from 1 if there are preceeding exons    
    my $end  = $exons[-1]->{'exon'}->{'etype'} eq 'A' ? $length : 0; # End line at the end of the image if there are further exons beyond the region end
    
    # Get only exons in view
    my @exons_in_view = grep { $_->{'exon'}->{'etype'} =~ /[NM]/} @exons;
    
    # Set start and end of the connecting line if they are not set yet
    $start ||= $exons_in_view[0]->start;
    $end   ||= $exons_in_view[-1]->end;
    
    # Draw exons
    foreach my $exon (@exons_in_view) {
      my $s = $exon->start;
      my $e = $exon->end;
      
      $s = 1 if $s < 0;
      $e = $length if $e > $length;
      
      $transcript_drawn = 1;
      
      $composite2->push($self->Rect({
        x         => $s - 1, 
        y         => $y, 
        height    => $h,
        width     => $e - $s + 1,
        colour    => $colour, 
        absolutey => 1
      }));
    }
    
    # Draw connecting line
    $composite2->push($self->Rect({
      x         => $start, 
      y         => int($y + $h/2), 
      height    => 0, 
      width     => $end - $start + 1,
      colour    => $colour, 
      absolutey => 1
    }));
    
    $composite->push($composite2);
    
    my $bump_height = $h + 2;
    
    if ($show_labels ne 'off' && $labels) {
      if (my $text_label = $self->gene_text_label($gene)) {
        my @lines = split "\n", $text_label;
        $lines[0] = "< $lines[0]" if $strand < 1;
        $lines[0] = "$lines[0] >" if $strand >= 1;
        
        for (my $i = 0; $i < scalar @lines; $i++){
          my $line = "$lines[$i] ";
          my ($txt, $bit, $w, $th) = $self->get_text_width(0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname);
          
          $composite->push($self->Text({
            x         => $composite->x,
            y         => $y + $h + $i*($th + 1),
            height    => $th,
            width     => $w / $pix_per_bp,
            font      => $fontname,
            ptsize    => $fontsize,
            halign    => 'left',
            colour    => $colour,
            text      => $line,
            absolutey => 1
          }));
          
          $bump_height += $th + 1;
        }
      }
    }
    
    # bump
    my $bump_start = int($composite->x * $pix_per_bp);
    my $bump_end = $bump_start + int($composite->width * $pix_per_bp) + 1;
    
    my $row = $self->bump_row($bump_start, $bump_end);
    
    # shift the composite container by however much we're bumped
    $composite->y($composite->y - $strand * $bump_height * $row);
    $composite->colour($highlight) if defined $highlight;
    $self->push($composite);
  }
  
  if ($transcript_drawn) {
    my $type = $self->_type;
    my @legend = %used_colours;
    
    $config->{'legend_features'}->{$type} = {
      priority => $self->_pos,
      legend   => \@legend
    };
  } elsif ($config->get_parameter('opt_empty_tracks') != 0) {
    $self->errorTrack(sprintf 'No %s in this region', $self->error_track_name);
  }
}

sub render_genes {
  my $self = shift;

  return $self->render_text('gene') if $self->{'text_export'};
  
  my $container        = $self->{'container'}{'ref'} || $self->{'container'};
  my $length           = $container->length;
  my $selected_gene    = $self->core('g');
  my $pix_per_bp       = $self->scalex;
  my $strand           = $self->strand;
  my $strand_flag      = $self->my_config('strand');
  my $database         = $self->my_config('db');
  my $max_length       = $self->my_config('threshold') || 1e6;
  my $max_length_nav   = $self->my_config('navigation_threshold') || 50e3;
  my $label_threshold  = $self->my_config('label_threshold') || 50e3;
  my $navigation       = $self->my_config('navigation') || 'on';
  my $previous_species = $self->my_config('previous_species');
  my $next_species     = $self->my_config('next_species');
  my $link             = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $h                = 8;
  my $join_z           = -10;
  my $join_col         = 'blue';
  
  my ($fontname, $fontsize) = $self->get_font_details('outertext');

  $self->_init_bump;
  
  if ($length > $max_length * 1001) {
    $self->errorTrack('Genes only displayed for less than $max_length Kb.');
    return;
  }
  
  my $show_navigation = $navigation eq 'on' && $length < $max_length_nav * 1001;
  my $offset = $container->start - 1;
  my %gene_objs;
  my $F = 0;
  my $used_colours = {};
  my $flag = 0;
  my @genes_to_label;
  
  foreach my $gene (@{$self->features}) {
    my $gene_strand = $gene->strand;
    
    next if $gene_strand != $strand && $strand_flag eq 'b';
    
    my $gene_key       = $self->gene_key($gene);
    my $gene_col       = $self->my_colour($gene_key);
    my $gene_type      = $self->my_colour($gene_key, 'text');
    my $label          = $gene->external_name || $gene->stable_id;
    my $gene_stable_id = $gene->stable_id;
    my $high           = $gene_stable_id eq $selected_gene;
    my $start          = $gene->start;
    my $end            = $gene->end;
    
    my ($chr_start, $chr_end) = $self->slice2sr($start, $end);
    
    next if $end < 1 || $start > $length;
    
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    
    my $rect = $self->Rect({
      x         => $start - 1,
      y         => 0,
      width     => $end - $start + 1,
      height    => $h,
      colour    => $gene_col,
      absolutey => 1,
      title     => ($gene->external_name ? $gene->external_name . '; ' : '') .
                   "Gene: $gene_stable_id; Location: " .
                   $gene->seq_region_name . ':' . $gene->seq_region_start . '-' . $gene->seq_region_end
    });
    
    if ($show_navigation) {
      $rect->{'href'} = $self->_url({
        species => $self->species,
        type    => 'Gene',
        action  => 'Summary',
        g       => $gene_stable_id,
        db      => $database
      });
    }
    
    push @genes_to_label, {
      start     => $start,
      label     => $label,
      end       => $end,
      href      => $rect->{'href'},
      title     => $rect->{'title'},
      gene      => $gene,
      col       => $gene_col,
      highlight => $high
    };
    
    my $bump_start = int($rect->x * $pix_per_bp);
    my $bump_end = $bump_start + int($rect->width * $pix_per_bp) + 1;
    my $row = $self->bump_row($bump_start, $bump_end);
    
    $rect->y($rect->y + (6 * $row));
    $rect->height(4);
    
    if ($link) {
      if ($previous_species) {
        $self->join_tag($rect, "$gene_stable_id:$_", 0.5, 0.5, $join_col, 'line', $join_z) for $self->get_homologous_gene_ids($gene, $previous_species);
      }
      
      if ($next_species) {
        $self->join_tag($rect, "$_:$gene_stable_id", 0.5, 0.5, $join_col, 'line', $join_z) for $self->get_homologous_gene_ids($gene, $next_species);
      }
    }
    
    $self->push($rect);
    
    if ($high) {
      $self->unshift($self->Rect({
        x         => ($start - 1) - 1/$pix_per_bp,
        y         => $rect->y - 1,
        width     => ($end - $start + 1) + 2/$pix_per_bp,
        height    => $rect->height + 2,
        colour    => 'highlight2',
        absolutey => 1
      }));
    }
    
    $flag = 1;
  }
  
  # Now we need to add the label track, followed by the legend
  if ($flag) {
    my $gl_flag = $self->get_parameter('opt_gene_labels');
    $gl_flag = 1 unless defined $gl_flag;
    $gl_flag = shift if @_;
    $gl_flag = 0 if $label_threshold * 1001 < $length;
    
    if ($gl_flag) {
      my $start_row = $self->_max_bump_row + 1;
      
      $self->_init_bump;
      
      my ($a, $b, $c, $H) = $self->get_text_width(0, 'X_y', '', 'font' => $fontname, 'ptsize' => $fontsize);

      foreach my $gr (@genes_to_label) {
        my ($txt, $part, $W, $H2) = $self->get_text_width(0, "$gr->{'label'} ", '', 'font' => $fontname, 'ptsize' => $fontsize);
        
        my $tglyph = $self->Text({
          x         => ($gr->{'start'} - 1) + 4/$pix_per_bp,
          y         => 0,
          height    => $H,
          width     => $W / $pix_per_bp,
          font      => $fontname,
          halign    => 'left',
          ptsize    => $fontsize,
          colour    => $gr->{'col'},
          text      => "$gr->{'label'} ",
          title     => $gr->{'title'},
          href      => $gr->{'href'},
          absolutey => 1
        });
        
        my $bump_start = int($tglyph->{'x'} * $pix_per_bp) - 4;
        my $bump_end = $bump_start + int($tglyph->width * $pix_per_bp) + 1;
        
        my $row = $self->bump_row($bump_start, $bump_end);
        
        $tglyph->y($tglyph->{'y'} + $row * (2 + $H) + ($start_row - 1) * 6);
        
        # Draw little taggy bit to indicate start of gene
        $self->push(
          $tglyph,
          $self->Rect({
            x            => $gr->{'start'} - 1,
            y            => $tglyph->y + 2,
            width        => 0,
            height       => 4,
            bordercolour => $gr->{'col'},
            absolutey    => 1
          }),
          $self->Rect({
            x            => $gr->{'start'} - 1,
            y            => $tglyph->y + 2 + 4,
            width        => 3 / $pix_per_bp,
            height       => 0,
            bordercolour => $gr->{'col'},
            absolutey    => 1
          })
        );
        
        if ($gr->{'highlight'}) {
          $self->unshift($self->Rect({
            x         => ($gr->{'start'} - 1) - 1/$pix_per_bp,
            y         => $tglyph->y + 1,
            width     => ($tglyph->width + 1) + 2/$pix_per_bp,
            height    => $tglyph->height + 2,
            colour    => 'highlight2',
            absolutey => 1
          }));
        }
      }
    }
  }
}

sub render_text {
  my $self = shift;
  my ($feature_type, $collapsed) = @_;
  
  my $container   = $self->{'container'}{'ref'} || $self->{'container'};
  my $length      = $container->length;
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand') || 'b';
  my $target      = $self->get_parameter('single_Transcript');
  my $target_gene = $self->get_parameter('single_Gene');
  my $export;
  
  foreach my $gene (@{$self->features}) { # For alternate splicing diagram only draw transcripts in gene
    my $gene_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    
    next if $target_gene && $gene_id ne $target_gene;
    
    my $gene_type = $gene->status . '_' . $gene->biotype;
    my $gene_name = $gene->can('display_xref') && $gene->display_xref ? $gene->display_xref->display_id : undef;
    
    if ($feature_type eq 'gene') {
      $export .= $self->_render_text($gene, 'Gene', { 
        headers => [ 'gene_id', 'gene_name', 'gene_type' ],
        values  => [ $gene_id, $gene_name, $gene_type ]
      });
    } else {
      my $exons = {};
      
      foreach my $transcript (@{$gene->get_all_Transcripts}) {      
        next if $transcript->start > $length || $transcript->end < 1;
        
        my $transcript_id = $transcript->stable_id;
        
        next if $target && ($transcript_id ne $target); # For exon_structure diagram only given transcript
        
        my $transcript_name = 
          $transcript->can('display_xref') && $transcript->display_xref ? $transcript->display_xref->display_id : 
          $transcript->can('analysis') && $transcript->analysis ? $transcript->analysis->logic_name : 
          undef;
        
        foreach (sort { $a->start <=> $b->start } @{$transcript->get_all_Exons}) {
          next if $_->start > $length || $_->end < 1;
          
          if ($collapsed) {
            my $stable_id = $_->stable_id;
            
            next if $exons->{$stable_id};
            
            $exons->{$stable_id} = 1;
          }
           
          $export .= $self->export_feature($_, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type);
        }
      }
    }
  }
  
  return $export;
}

#============================================================================#
#
# The following three subroutines are designed to get homologous peptide ids
# 
#============================================================================#

# Get homologous gene ids for given gene
sub get_homologous_gene_ids {
  my ($self, $gene, $species) = @_;
  
  my $compara_db = $gene->adaptor->db->get_adaptor('compara');
  return unless $compara_db;
  
  my $ma = $compara_db->get_MemberAdaptor;
  return unless $ma;
  
  my $qy_member = $ma->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
  return unless defined $qy_member;
  
  my $ha = $compara_db->get_HomologyAdaptor;
  my @homologues;
  
  foreach my $homology (@{$ha->fetch_all_by_Member_paired_species($qy_member, $species)}) {
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @$member_attribute;
      
      next if $member->stable_id eq $qy_member->stable_id;
      
      push @homologues, $member->stable_id;
    }
  }
  
  return @homologues;
}

# Get homologous protein ids for given gene
sub get_homologous_peptide_ids_from_gene {
  my ($self, $gene, $species) = @_;
  
  my $compara_db = $gene->adaptor->db->get_adaptor('compara');
  return unless $compara_db;
  
  my $ma = $compara_db->get_MemberAdaptor;
  return unless $ma;
  
  my $qy_member = $ma->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
  return unless defined $qy_member;
  
  my $ha = $compara_db->get_HomologyAdaptor;
  my @homologues;
  my @homologue_genes;
  
  my $stable_id = undef;
  my $peptide_id = undef;
  
  foreach my $homology (@{$ha->fetch_by_Member_paired_species($qy_member, $species)}) {
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @$member_attribute;
      
      if ($member->stable_id eq $qy_member->stable_id) {
        unless ($stable_id) {
          my $T = $ma->fetch_by_dbID($peptide_id = $attribute->peptide_member_id);
          $stable_id = $T->stable_id;
        }
      } else {
        push @homologues, $attribute->peptide_member_id;
        push @homologue_genes, $member->stable_id;
      }
    }
  }
  
  return ($stable_id, $peptide_id, \@homologues, \@homologue_genes);
}

#============================================================================#
#
# Helper functions....
# 
#============================================================================#

sub map_AlignSlice_Exons {
  my ($self, $transcript, $length) = @_;
  
  my @as_exons;
  my @exons;
  my $m_flag = 0; # Indicates that if an exons start is undefined it is missing exon
  my $exon_type = 'B';
  my $fstart = 0; # Start value for B exons
  
  # get_all_Exons returns all exons of AlignSlice including missing exons 
  # (they are located in primary species but not in secondary - we still get them for secondary species but
  #  without coordinates)
  # Here we mark all exons in following way for future display  
  # B - exons that are located in front of viewed region
  # A - exons that are located behind the viewed region
  # N - normal exons
  # M - exons that are between normal exons
  
  # First we preceeding, normal and missing exons (these will include A exons)
  foreach my $ex (@{$transcript->get_all_Exons}) {
    if ($ex->start) {
      $m_flag = 1;
      $exon_type = 'N';
      $fstart = $ex->end;
    } elsif ($m_flag) {
      $exon_type = 'M';
    }
    
    $ex->{'exon'}->{'etype'} = $exon_type;
    $ex->{'exon'}->{'fstart'} = $fstart if $exon_type eq 'M';
    
    push @as_exons, $ex;
  }
  
  # Now mark A exons
  $exon_type = 'A';
  $m_flag = 0; # Reset missing exon flag
  
  $fstart = $length + 2; # Start value for A exons (+2 to get it outside visible area)
  
  foreach my $ex (reverse @as_exons) {
    if ($ex->start) {
      $m_flag = 1;
      $fstart = $ex->start;
    } else {
      if (!$m_flag) {
        $ex->{'exon'}->{'etype'} = $exon_type;
        $ex->start($fstart);
        $ex->end($fstart);
      } else {
        $ex->start($ex->{'exon'}->{'fstart'} + 1);
        $ex->end($ex->{'exon'}->{'fstart'} + 1);
        
        if ($ex->{'exon'}->{'etype'} eq 'B') {
          $fstart = -1;
          $ex->start($fstart);
          $ex->end($fstart);
        } elsif ($ex->{'exon'}->{'etype'} eq 'M') {
          $ex->{'exon'}->{'fend'} = $fstart;
        }
      }
    }
      
    push @exons, $ex;
  }
    
  return reverse @exons;
}

# Generate title tag which will be used to render z-menu
sub title {
  my ($self, $transcript, $gene) = @_;
  
  my $title = 'Transcript: ' . $transcript->stable_id;
  $title .= '; Gene: ' . $gene->stable_id if $gene->stable_id;
  $title .= '; Location: ' . $transcript->seq_region_name . ':' . $transcript->seq_region_start . '-' . $transcript->seq_region_end;
  
  return $title
}

# Generate title tag for gene which will be used to render z-menu
sub gene_title {
  my ($self, $gene) = @_;
  
  my $title = 'Gene: ' . $gene->stable_id;
  $title .= '; Location: ' . $gene->seq_region_name . ':' . $gene->seq_region_start . '-' . $gene->seq_region_end;
  
  return $title;
}

1;
