package Bio::EnsEMBL::GlyphSet_transcript;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
no warnings "uninitialized";

use  Sanger::Graphics::Bump;

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Time::HiRes;

sub my_label { return 'Missing label'; }
sub colours { return {}; } 
sub text_label { return undef; } 
sub gene_text_label { return undef; } 
sub transcript_type { return undef; } 
sub features { return []; }
sub href { return undef; }
sub gene_href { return undef; }
sub zmenu { return undef; }
sub gene_zmenu { return undef; }
sub colour { return [ 'orange', 'Other' ]; }
sub gene_colour { my $self = shift; return $self->colour(); } 

 
sub _init {
  my ($self) = @_;
  my $strand_flag = $self->my_config('strand');

## If forced onto one strand....
  return if ( $strand_flag eq 'f' and $self->{'container'}{'strand'} != 1 ) ||
            ( $strand_flag eq 'r' and $self->{'container'}{'strand'} == 1 );

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    if( $self->my_config( 'compact' ) ) {
      $self->as_compact_init();
    } else {
      $self->as_expanded_init();
    }
  } else {
    if( $self->my_config( 'compact' ) ) {
      $self->compact_init();
    } else {
      $self->expanded_init();
    }
  }
} 

sub compact_init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $strand_flag   = $self->my_config('strand');
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};

  my $y             = 0;
  my $h             = 8;

  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list
  my @bitmap        = undef;
  my $colours       = $self->colours();
  my %used_colours  = ();
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $strand        = $self->strand();
  my $length        = $container->length;
  my $transcript_drawn = 0;

  my $gene_drawn = 0;
 
  my $compara = $Config->{'compara'};
  my $link    = $compara ? $Config->get_parameter( 'opt_join_transcript') : 0;
  my $join_col1 = 'blue';
  my $join_col2 = 'chocolate1';
  my $join_z   = -10;
  foreach my $gene ( @{$self->features()} ) { # For alternate splicing diagram only draw transcripts in gene
    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->stable_id;
    next if $gene_strand != $strand && $strand_flag eq 'b';
    $gene_drawn = 1;
## Get all the exons which overlap the region for this gene....
    my @exons = map { $_->start > $length || $_->end < 1 ? () : $_ } map { @{$_->get_all_Exons()} } @{$gene->get_all_Transcripts()};
    next unless @exons;

    my $Composite = $self->Composite({'y'=>$y,'height'=>$h, 'title' => $self->gene_title( $gene ) });
       $Composite->{'href'} = $self->gene_href( $gene, %highlights );
       $Composite->{'zmenu'} = $self->gene_zmenu( $gene ) unless $Config->{'_href_only'};
    my($colour, $label, $hilight) = $self->gene_colour( $gene, $colours, %highlights ) || ( 'orange', 'Other' );
    $used_colours{ $label } = $colour;
    my $Composite2 = $self->Composite({'y'=>$y,'height'=>$h});
    foreach my $exon (@exons) {
      my $s = $exon->start;
      my $e = $exon->end;
      $s = 1 if $s < 0;
      $e = $length if $e>$length;
      $transcript_drawn = 1;
      $Composite2->push($self->Rect({
        'x' => $s-1, 'y' => $y, 'width' => $e-$s+1,
        'height' => $h, 'colour'=>$colour, 'absolutey' => 1
      }));
    }
    my $start = $gene->start < 1 ? 1 : $gene->start;;
    my $end   = $gene->end   > $length ? $length : $gene->end;
    $Composite2->push($self->Rect({
      'x' => $start, 'width' => $end-$start+1,
      'height' => 0, 'y' => int($y+$h/2), 'colour' => $colour, 'absolutey' =>1,
    }));
    # Calculate and draw the coding region of the exon
    # only draw the coding region if there is such a region
    if($self->can('join')) {
      my @tags;
         @tags = $self->join( $gene->stable_id ) if $gene && $gene->can( 'stable_id' );
      foreach (@tags) {
        $self->join_tag( $Composite2, $_, 0, $self->strand==-1 ? 0 : 1, 'grey60' );
        $self->join_tag( $Composite2, $_, 1, $self->strand==-1 ? 0 : 1, 'grey60' );
      }
    }
    my $tsid;
    my @GENE_TAGS;
    if( $link && ( $compara eq 'primary' || $compara eq 'secondary' )) {
        if( $gene_stable_id ) {
            my $alt_alleles = $gene->get_all_alt_alleles();
            if( $Config->{'previous_species'} ) {
                foreach my $msid ( $self->get_homologous_gene_ids( $gene_stable_id, $Config->{'previous_species'} ) ) {
                    $self->join_tag( $Composite2, $Config->{'slice_id'}."#$gene_stable_id#$msid", 0.5, 0.5 , $join_col1, 'line', $join_z )}
                push @GENE_TAGS, map { $Config->{'slice_id'}. "=@{[$_->stable_id]}=$gene_stable_id" } @{$alt_alleles};
            }
            if( $Config->{'next_species'} ) {
                foreach my $msid ( $self->get_homologous_gene_ids( $gene_stable_id, $Config->{'next_species'} ) ) {
                    $self->join_tag( $Composite2, ($Config->{'slice_id'}+1)."#$msid#$gene_stable_id", 0.5, 0.5 , $join_col1, 'line', $join_z )}
                push @GENE_TAGS, map { ($Config->{'slice_id'}+1). "=$gene_stable_id=@{[$_->stable_id]}" } @{$alt_alleles};
            }
        }
    }
    #join alt_alleles
    foreach( @GENE_TAGS) {
        $self->join_tag( $Composite2, $_, 0.5, 0.5 , $join_col2, 'line', $join_z ) ;
    }

    $Composite->push($Composite2);
    my $bump_height = $h + 2;
    if( $Config->{'_add_labels'} ) {
      if(my $text_label = $self->gene_text_label($gene) ) {
        my @lines = split "\n", $text_label;
        $lines[0] = "< $lines[0]" if $strand < 1;
        $lines[0] = $lines[0].' >' if $strand >= 1;
        for( my $i=0; $i<@lines; $i++ ){
          my $line = $lines[$i].' ';
          my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname );
          $Composite->push( $self->Text({
            'x'         => $Composite->x(),
            'y'         => $y + $h + $i*($th+1),
            'height'    => $th,
            'width'     => $w / $pix_per_bp,
            'font'      => $fontname,
            'ptsize'    => $fontsize,
            'halign'    => 'left',
            'colour'    => $colour,
            'text'      => $line,
            'absolutey' => 1,
          }));
          $bump_height += $th+1;
        }
      }
    }

  ########## bump it baby, yeah! bump-nology!
    my $bump_start = int($Composite->x * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
       $bump_end = $bitmap_length if $bump_end > $bitmap_length;
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap);
      ########## shift the composite container by however much we're bumped
    $Composite->y($Composite->y() - $strand * $bump_height * $row);
    $Composite->colour($hilight) if defined $hilight;
    $self->push($Composite);
  }

  if($transcript_drawn) {
    my $type       = $self->_type;
    my %legend_old = @{$Config->{'legend_features'}{$type}{'legend'}||[]};
    foreach(keys %legend_old) { $used_colours{$_} = $legend_old{$_}; }
    my @legend = %used_colours;
    $Config->{'legend_features'}->{$type} = {
      'priority' => $self->_pos,
      'legend'   => \@legend
    };

    ## my ($key, $priority, $legend) = $self->legend( $colours );
    # define which legend_features should be displayed
    # this is being used by GlyphSet::gene_legend
    ## $Config->{'legend_features'}->{$key} = {
    ##  'priority' => $priority,
    ##  'legend'   => $legend
    ## } if defined($key);
  } elsif( $Config->get_parameter( 'opt_empty_tracks')!=0) {
    $self->errorTrack( "No ".$self->error_track_name()." in this region" );
  }
}

sub get_homologous_gene_ids {
  my( $self, $gene_id, $species ) = @_;
  my $compara_db = $self->{'container'}->adaptor->db->get_db_adaptor('compara');
  my $ma = $compara_db->get_MemberAdaptor;
  my $qy_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);
  return () unless (defined $qy_member);
  my $ha = $compara_db->get_HomologyAdaptor;
  my @homologues;
  foreach my $homology (@{$ha->fetch_by_Member_paired_species($qy_member, $species)}){
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      next if ($member->stable_id eq $qy_member->stable_id);
      push @homologues, $member->stable_id;
    }
  }
  return @homologues;
}

sub get_homologous_peptide_ids_from_gene {
  my( $self, $gene_id, $species ) = @_;
  my $compara_db = $self->{'container'}->adaptor->db->get_db_adaptor('compara');
  return unless $compara_db;
  my $ma = $compara_db->get_MemberAdaptor;
  return () unless $ma;
  my $qy_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);
  return () unless (defined $qy_member);
  my $ha = $compara_db->get_HomologyAdaptor;
  my @homologues;
  my $STABLE_ID = undef;
  my $peptide_id = undef;
  foreach my $homology (@{$ha->fetch_by_Member_paired_species($qy_member, $species)}){
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      if( $member->stable_id eq $qy_member->stable_id ) {
        unless( $STABLE_ID) {
          my $T = $ma->fetch_by_dbID( $peptide_id = $attribute->peptide_member_id );
          $STABLE_ID = $T->stable_id;
        }
      } else {
        push @homologues, $attribute->peptide_member_id;
      }
    }
  }
  return ( $STABLE_ID, $peptide_id, \@homologues );
}

sub get_homologous_peptide_ids {
  my( $self, $gene_id, $species ) = @_;
  my $compara_db = $self->{'container'}->adaptor->db->get_db_adaptor('compara');

  my $peptide_sql = qq(select m.stable_id
  from homology_member as hm, member as m, source as s, genome_db as gd,
       homology_member as ohm, member as om, genome_db as ogd
 where m.member_id = hm.peptide_member_id and hm.homology_id = ohm.homology_id and
       ohm.peptide_member_id = om.member_id and
       om.source_id = s.source_id and m.source_id = s.source_id and s.source_name = 'ENSEMBLPEP' and
       m.genome_db_id = gd.genome_db_id  and gd.name = ? and
       om.genome_db_id = ogd.genome_db_id  and ogd.name = ? and
        om.stable_id = ?);

  ( my $current_species = $self->{'container'}{web_species} ) =~ s/_/ /g;
  ( my $other_species   = $species )                                 =~ s/_/ /g;
  my $results = $compara_db->prepare( $peptide_sql );
     $results->execute( $other_species, $current_species, $gene_id );

  return map {@$_} @{$results->fetchall_arrayref};
}

sub title {
  my( $self, $transcript, $gene ) = @_;
  my $title = 'Transcript: '.$transcript->stable_id;
  if( $gene->stable_id ) {
    $title .= '; Gene: '.$gene->stable_id;
  }
  $title .= '; Location: '.$transcript->seq_region_name.':'.$transcript->seq_region_start.'-'.$transcript->seq_region_end;
  return $title
}

sub gene_title {
  my( $self, $gene ) = @_;
  my $title  = 'Gene: '.$gene->stable_id;
     $title .= '; Location: '.$gene->seq_region_name.':'.$gene->seq_region_start.'-'.$gene->seq_region_end;
  return $title;
}
sub expanded_init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my $strand_flag   = $self->my_config('strand') || 'b';
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $target        = $Config->{'_draw_single_Transcript'};
  my $target_gene   = $Config->{'geneid'};
    
  my $y             = 0;
  my $h             = $target ? 30 : 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my @bitmap        = undef;
  my $colours       = $self->colours();

  my %used_colours  = ();
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $strand  = $self->strand();
  my $length  = $container->length;
  my $transcript_drawn = 0;
    

  my $compara = $Config->{'compara'};
  my $link    = $compara ? $Config->get_parameter( 'opt_join_transcript') : 0;
  
  foreach my $gene ( @{$self->features()} ) { # For alternate splicing diagram only draw transcripts in gene
    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id() : undef;
    next if $gene_strand != $strand and $strand_flag eq 'b'; # skip features on wrong strand....
    next if $target_gene && $gene_stable_id ne $target_gene;
    my %TAGS = (); my @GENE_TAGS;
    my $tsid;
    if( $link && ( $compara eq 'primary' || $compara eq 'secondary' ) && $link ) {
      if( $gene_stable_id ) {
        my $alt_alleles = $gene->get_all_alt_alleles();

        #vega stuff to link alt-alleles on longest transcript
        my $alltrans = $gene->get_all_Transcripts;
        my @s_alltrans = sort {$a->length <=> $b->length} @{$alltrans};
        my $long_trans = pop @s_alltrans;
        $tsid = $long_trans->stable_id;
        my @long_trans;
        foreach my $gene (@{$alt_alleles}) {
            my $vtranscripts = $gene->get_all_Transcripts;
            my @sorted_trans = sort {$a->length <=> $b->length} @{$vtranscripts};
            push @long_trans,(pop @sorted_trans);
        }
            
        if( $Config->{'previous_species'} ) {
          my( $psid, $pid, $href ) = $self->get_homologous_peptide_ids_from_gene( $gene_stable_id, $Config->{'previous_species'} );
          push @{$TAGS{$psid}}, map { $Config->{'slice_id'}. "#$_#$pid" } @{$href};
          push @GENE_TAGS, map { $Config->{'slice_id'}. "=@{[$_->stable_id]}=$tsid" } @long_trans;    
        }
        if( $Config->{'next_species'} ) {
          my( $psid, $pid, $href ) = $self->get_homologous_peptide_ids_from_gene( $gene_stable_id, $Config->{'next_species'} );
          push @{$TAGS{$psid}}, map { ($Config->{'slice_id'}+1). "#$pid#$_" } @{$href};
          push @GENE_TAGS, map { ($Config->{'slice_id'}+1). "=$tsid=@{[$_->stable_id]}" } @long_trans;
        }
      }
    }
    my $join_col1 = 'blue';
    my $join_col2 = 'chocolate1';
    my $join_z   = -10;

    foreach my $transcript (@{$gene->get_all_Transcripts()}) {
      next if $transcript->start > $length ||  $transcript->end < 1;
      my @exons = sort {$a->start <=> $b->start} grep { $_ } @{$transcript->get_all_Exons()};#sort exons on their start coordinate 

      #$self->datadump( $gene_stable_id, \%TAGS );
      # Skip if no exons for this transcript
      next if (@exons == 0);
      # If stranded diagram skip if on wrong strand
      next if (@exons[0]->strand() != $strand && $self->{'do_not_strand'}!=1 );
      # For exon_structure diagram only given transcript
      next if $target && ($transcript->stable_id() ne $target);

      $transcript_drawn=1;        

      my $Composite = $self->Composite({'y'=>$y,'height'=>$h,'title'=>$self->title($transcript,$gene) });
         $Composite->{'href'} = $self->href( $gene, $transcript, %highlights );
      my($colour, $label, $hilight) = $self->colour( $gene, $transcript, $colours, %highlights );
      ($colour,$label) = ('orange','Other') unless $colour;
      $used_colours{ $label } = $colour;
      my $coding_start = defined ( $transcript->coding_region_start() ) ? $transcript->coding_region_start :  -1e6;
      my $coding_end   = defined ( $transcript->coding_region_end() )   ? $transcript->coding_region_end :    -1e6;
      my $Composite2 = $self->Composite({'y'=>$y,'height'=>$h});
      if( $transcript->translation ) { 
        foreach( @{$TAGS{$transcript->translation->stable_id}||[]} ) { 
          $self->join_tag( $Composite2, $_, 0.5, 0.5 , $join_col1, 'line', $join_z ) ;
        }
      }
      foreach( @GENE_TAGS) {
      if ($transcript->stable_id eq $tsid) {
              $self->join_tag( $Composite2, $_, 0.5, 0.5 , $join_col2, 'line', $join_z ) ;
          }
      }
      for(my $i = 0; $i < @exons; $i++) {
        my $exon = @exons[$i];
        next unless defined $exon; #Skip this exon if it is not defined (can happen w/ genscans) 
        my $next_exon = ($i < $#exons) ? @exons[$i+1] : undef; #First draw the exon
              # We are finished if this exon starts outside the slice
        last if $exon->start() > $length;
        my($box_start, $box_end);
            # only draw this exon if is inside the slice
        if($exon->end() > 0 ) { #calculate exon region within boundaries of slice
          $box_start = $exon->start();
          $box_start = 1 if $box_start < 1 ;
          $box_end = $exon->end();
          $box_end = $length if$box_end > $length;
          if($box_start < $coding_start || $box_end > $coding_end ) {
                      # The start of the transcript is before the start of the coding
                      # region OR the end of the transcript is after the end of the
                      # coding regions.  Non coding portions of exons, are drawn as
                      # non-filled rectangles
                      #Draw a non-filled rectangle around the entire exon
            $Composite2->push($self->Rect({
              'x'         => $box_start -1 ,
              'y'         => $y+$h/8,
              'width'     => $box_end-$box_start +1,
              'height'    => 3*$h/4,
              'bordercolour' => $colour,
              'absolutey' => 1,
             }));
           } 
           # Calculate and draw the coding region of the exon
           my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
           my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
                  # only draw the coding region if there is such a region
           if( $filled_start <= $filled_end ) {
            #Draw a filled rectangle in the coding region of the exon
              $Composite2->push( $self->Rect({
                'x' => $filled_start -1,
                'y'         => $y,
                'width'     => $filled_end - $filled_start + 1,
                'height'    => $h,
                'colour'    => $colour,
                'absolutey' => 1
              }));
          }
        } #we are finished if there is no other exon defined
        last unless defined $next_exon;

        my $intron_start = $exon->end() + 1;   #calculate the start and end of this intron
        my $intron_end = $next_exon->start()-1;
        next if($intron_end < 0);   #grab the next exon if this intron is before the slice
        last if($intron_start > $length);      #we are done if this intron is after the slice
          
        #calculate intron region within slice boundaries
        $box_start = $intron_start < 1 ? 1 : $intron_start;
        $box_end   = $intron_end > $length ? $length : $intron_end;
        my $intron;
        if( $box_start == $intron_start && $box_end == $intron_end ) {
          # draw an wholly in slice intron
          $Composite2->push($self->Intron({
            'x'         => $box_start -1,
            'y'         => $y,
            'width'     => $box_end-$box_start + 1,
            'height'    => $h,
            'colour'    => $colour,
            'absolutey' => 1,
            'strand'    => $strand,
          }));
        } else { 
            # else draw a "not in slice" intron
          $Composite2->push($self->Line({
            'x'         => $box_start -1 ,
            'y'         => $y+int($h/2),
            'width'     => $box_end-$box_start + 1,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $colour,
            'dotted'    => 1,
          }));
        } # enf of intron-drawing IF
      }
      if($self->can('join')) {
        my @tags;
           @tags = $self->join( $gene->stable_id ) if $gene && $gene->can('stable_id');
        foreach (@tags) {
          $self->join_tag( $Composite2, $_, 0, $self->strand==-1 ? 0 : 1, 'grey60' );
          $self->join_tag( $Composite2, $_, 1, $self->strand==-1 ? 0 : 1, 'grey60' );
        }
      }
      $Composite->push($Composite2);
      my $bump_height = 1.5 * $h;
      if( $Config->{'_add_labels'} ) {
        if(my $text_label = $self->text_label($gene, $transcript) ) {
      my @lines = split "\n", $text_label; 
          $lines[0] = "< $lines[0]" if $strand < 1;
          $lines[0] = $lines[0].' >' if $strand >= 1;
          for( my $i=0; $i<@lines; $i++ ){
            my $line = $lines[$i].' ';
            my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname );
            $Composite->push( $self->Text({
              'x'         => $Composite->x(),
              'y'         => $y + $h + $i*($th+1),
              'height'    => $th,
              'width'     => $w / $pix_per_bp,
              'font'      => $fontname,
              'ptsize'    => $fontsize,
              'halign'    => 'left', 
              'colour'    => $colour,
              'text'      => $line,
              'absolutey' => 1,
            }));
            $bump_height += $th+1;
      }
        }
      }

      ########## bump it baby, yeah! bump-nology!
      my $bump_start = int($Composite->x * $pix_per_bp);
         $bump_start = 0 if ($bump_start < 0);
      my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
         $bump_end = $bitmap_length if $bump_end > $bitmap_length;
      my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap);
      ########## shift the composite container by however much we're bumped
      $Composite->y($Composite->y() - $strand * $bump_height * $row);
      $Composite->colour($hilight) if(defined $hilight && !defined $target);
      $self->push($Composite);
        
      if($target) {     
        # check the strand of one of the transcript's exons
        my ($trans_exon) = @{$transcript->get_all_Exons};
        if($trans_exon->strand() == 1) {
          $self->push($self->Line({
            'x'         => 0,
            'y'         => -4,
            'width'     => $length,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $colour
          }));
          $self->push( $self->Poly({
            'points' => [
               $length - 4/$pix_per_bp,-2,
               $length                ,-4,
               $length - 4/$pix_per_bp,-6],
            'colour'    => $colour,
            'absolutey' => 1,
          }));
        } else {
          $self->push($self->Line({
            'x'         => 0,
            'y'         => $h+4,
            'width'     => $length,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $colour
          }));
          $self->push($self->Poly({
            'points'    => [ 4/$pix_per_bp,$h+6,
                             0,              $h+4,
                             4/$pix_per_bp,$h+2],
            'colour'    => $colour,
            'absolutey' => 1,
          }));
        }
      }  
    }
  }
  if($transcript_drawn) {
    my $type = $self->_type;
    my %legend_old = @{$Config->{'legend_features'}{$type}{'legend'}||[]};
    foreach(keys %legend_old) { $used_colours{$_} = $legend_old{$_}; }

    my @legend = %used_colours;
    $Config->{'legend_features'}->{$type} = {
      'priority' => $self->_pos,
      'legend'   => \@legend
    };

    ## my ($key, $priority, $legend) = $self->legend( $colours );
    # define which legend_features should be displayed
    # this is being used by GlyphSet::gene_legend
    ## $Config->{'legend_features'}->{$key} = {
    ##  'priority' => $priority,
    ##  'legend'   => $legend
    ## } if defined($key);
  } elsif( $Config->get_parameter( 'opt_empty_tracks')!=0) {
    $self->errorTrack( "No ".$self->error_track_name()." in this region" );
  }
}

sub map_AS_Exons {
    my ($self, $transcript, $length) = @_;
    my @as_exons = ();

# get_all_Exons returns all exons of AlignSlice including missing exons 
# (they are located in primary species but not in secondary - we still get them for secondary species but
#  without coordinates)
# Here we mark all exons in following way for future display  
# B - exons that are located in front of viewed region
# A - exons that are located behind the viewed region
# N - normal exons
# M - exons that are between normal exons

    my $m_flag = 0; # Indicates that if an exons start is undefined it is missing exon
    my $exon_type = 'B';
    my $fstart = 0; # Start value for B exons

# First we preceeding, normal and missing exons (these will include A exons)
    foreach my $ex (@{$transcript->get_all_Exons()}) {
    if ($ex->start) {
        $m_flag = 1;
        $exon_type = 'N';
        $fstart = $ex->end;
    } elsif ($m_flag) {
        $exon_type = 'M';
    }

    $ex->{exon}->{etype} = $exon_type;
    $ex->{exon}->{fstart} = $fstart if ($exon_type eq 'M');
        
    push (@as_exons, $ex);
    }

    my @exons = ();

    # Now mark A exons
    $exon_type = 'A';
    $m_flag = 0; # Reset missing exon flag
    
    $fstart = $length + 2; # Start value for A exons (+2 to get it outside visible area)

    foreach my $ex (reverse @as_exons) {
    if ($ex->start) {
        $m_flag = 1;
        $fstart = $ex->start;
    } else {
        if (! $m_flag) {
        $ex->{exon}->{etype} = $exon_type;
        $ex->start($fstart);
        $ex->end($fstart);
        } else {
        $ex->start($ex->{exon}->{fstart} +1);
        $ex->end($ex->{exon}->{fstart} +1);
            
        if ($ex->{exon}->{etype} eq 'B') {
            $fstart = -1;
            $ex->start($fstart);
            $ex->end($fstart);
        } elsif ($ex->{exon}->{etype} eq 'M') {
            $ex->{exon}->{fend} = $fstart;
        }
        }
    }
    
    push(@exons, $ex);
    }
    
    return reverse @exons;
}
      
sub as_expanded_init {
    my ($self) = @_;

    my $Config        = $self->{'config'};
    my $strand_flag   = $self->my_config('strand') || 'b';
    my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
    my $target        = $Config->{'_draw_single_Transcript'};
    my $target_gene   = $Config->{'geneid'};
    
    my $y             = 0;
    my $h             = $target ? 30 : 8;   #Single transcript mode - set height to 30 - width to 8!
    
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list

    my @bitmap        = undef;
    my $colours       = $self->colours();
    my %used_colours  = ();
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

    my $strand  = $self->strand();
    my $length  = $container->length;
    my $transcript_drawn = 0;
    

# Colour to use to display missing exons
    my $mcolour = 'green';

# Get all the genes in the region
    my %ugenes = map {$_->stable_id, $_ } @{$self->features()};


    foreach my $gn (keys(%ugenes)) {
    my $gene = $ugenes{$gn};

    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id() : undef;
    next if $gene_strand != $strand and $strand_flag eq 'b'; # skip features on wrong strand....
    next if $target_gene && $gene_stable_id ne $target_gene;
    my %TAGS = ();

    my $join_col = 'blue';
    my $join_z   = -10;

    foreach my $transcript (@{$gene->get_all_Transcripts()}) {
        next if $transcript->start > $length ||  $transcript->end < 1;
        my @exons = $self->map_AS_Exons($transcript, $length);
        next if (@exons == 0);

        # For exon_structure diagram only given transcript
        next if $target && ($transcript->stable_id() ne $target);

        $transcript_drawn=1;        
        my $Composite = $self->Composite({'y'=>$y,'height'=>$h});
        $Composite->{'href'} = $self->href( $gene, $transcript, %highlights );
        $Composite->{'zmenu'} = $self->zmenu( $gene, $transcript ) unless $Config->{'_href_only'};
        my($colour, $label, $hilight) = $self->colour( $gene, $transcript, $colours, %highlights );
            ($colour,$label) = ('orange','Other') unless $colour;

        $used_colours{ $label } = $colour; 

        my $coding_start = defined ( $transcript->coding_region_start() ) ? $transcript->coding_region_start :  -1e6;
        my $coding_end   = defined ( $transcript->coding_region_end() )   ? $transcript->coding_region_end :    -1e6;

        my $Composite2 = $self->Composite({'y'=>$y,'height'=>$h});


        if( $transcript->translation ) { 
        foreach( @{$TAGS{$transcript->translation->stable_id}||[]} ) { 
            $self->join_tag( $Composite2, $_, 0.5, 0.5 , $join_col, 'line', $join_z ) ;
        }
        }


        # now draw exons
        for(my $i = 0; $i < @exons; $i++) {
        my $exon = @exons[$i];
         
        next unless defined $exon; #Skip this exon if it is not defined (can happen w/ genscans) 
        my $next_exon = ($i < $#exons) ? @exons[$i+1] : undef; #First draw the exon
        # We are finished if this exon starts outside the slice
          
        last if $exon->start() > $length;
        my($box_start, $box_end);
        # only draw this exon if is inside the slice



        if($exon->end() > 0 ) { #calculate exon region within boundaries of slice
            $box_start = $exon->start();
            $box_start = 1 if $box_start < 1 ;
            $box_end = $exon->end();
            $box_end = $length if $box_end > $length;
            if($box_start < $coding_start || $box_end > $coding_end ) {
            # The start of the transcript is before the start of the coding
            # region OR the end of the transcript is after the end of the
            # coding regions.  Non coding portions of exons, are drawn as
            # non-filled rectangles
            #Draw a non-filled rectangle around the entire exon
            $Composite2->push($self->Rect({
                'x'         => $box_start -1 ,
                'y'         => $y+$h/8,
                'width'     => $box_end-$box_start +1,
                'height'    => 3*$h/4,
                'bordercolour' => $colour,
                'absolutey' => 1,
            }));
            } 
            # Calculate and draw the coding region of the exon
            my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
            my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
            # only draw the coding region if there is such a region
            if( $filled_start <= $filled_end ) {
            #Draw a filled rectangle in the coding region of the exon
            $Composite2->push( $self->Rect({
                'x' => $filled_start -1,
                'y'         => $y,
                'width'     => $filled_end - $filled_start + 1,
                'height'    => $h,
                'colour'    => $colour,
                'absolutey' => 1
                }));
            }
        } #we are finished if there is no other exon defined
        last unless defined $next_exon;

        my $intron_start = $exon->end() + 1;   #calculate the start and end of this intron
        my $intron_end = $next_exon->start()-1;
        next if($intron_end < 0);   #grab the next exon if this intron is before the slice
        last if($intron_start > $length);      #we are done if this intron is after the slice
          
        #calculate intron region within slice boundaries
        $box_start = $intron_start < 1 ? 1 : $intron_start;
        $box_end   = $intron_end > $length ? $length : $intron_end;
        my $intron;


        if( $exon->{exon}->{etype} ne 'M') {
            # Usual stuff if it is not missing exon
            if( $box_start == $intron_start && $box_end == $intron_end) {
              # draw an wholly in slice intron
            $Composite2->push($self->Intron({
                'x'         => $box_start -1,
                'y'         => $y,
                'width'     => $box_end-$box_start + 1,
                'height'    => $h,
                'colour'    => $colour,
                'absolutey' => 1,
                'strand'    => $strand,
            }));
            } else {
            # else draw a "not in slice" intron
            $Composite2->push($self->Line({
                'x'         => $box_start -1 ,
                'y'         => $y+int($h/2),
                'width'     => $box_end-$box_start + 1,
                'height'    => 0,
                'absolutey' => 1,
                'colour'    => $colour,
                'dotted'    => 1,
            }));
            }
        } else { # Missing exon - draw a dotted line
            $Composite2->push($self->Line({
            'x'         => $box_start -1 ,
            'y'         => $y+int($h/2),
            'width'     => $box_end-$box_start + 1,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $mcolour,
            'dotted'    => 1,
            }));
        } 
        }
        if($self->can('join')) {
        my @tags;
        @tags = $self->join( $gene->stable_id ) if $gene && $gene->can('stable_id');
        foreach (@tags) {
            $self->join_tag( $Composite2, $_, 0, $self->strand==-1 ? 0 : 1, 'grey60' );
            $self->join_tag( $Composite2, $_, 1, $self->strand==-1 ? 0 : 1, 'grey60' );
        }
        }

        $Composite->push($Composite2);
        my $bump_height = 1.5 * $h;
        if( $Config->{'_add_labels'} ) {
        if ( my $text_label = $self->text_label($gene, $transcript) ) {
            my @lines = split "\n", $text_label;
            my @lines = split "\n", $text_label;
            for( my $i=0; $i<@lines; $i++ ){
            my $line = $lines[$i];
          my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname );

            $Composite->push( $self->Text({
                'x'         => $Composite->x(),
                'y'         => $y + $h + $i*($th+1),
            'height'    => $th,
            'width'     => $w / $pix_per_bp,
            'font'      => $fontname,
            'ptsize'    => $fontsize,
            'halign'    => 'left',

                'colour'    => $colour,
                'text'      => $line,
                'absolutey' => 1,
            }));
            $bump_height += $th+1;
            }
        }
        }
        
        ########## bump it baby, yeah! bump-nology!
        my $bump_start = int($Composite->x * $pix_per_bp);
        $bump_start = 0 if ($bump_start < 0);
        my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
        $bump_end = $bitmap_length if $bump_end > $bitmap_length;
        my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap);
      ########## shift the composite container by however much we're bumped
        $Composite->y($Composite->y() - $strand * $bump_height * $row);
        $Composite->colour($hilight) if(defined $hilight && !defined $target);
        $self->push($Composite);
        
        if($target) {     
        # check the strand of one of the transcript's exons
        my ($trans_exon) = @{$transcript->get_all_Exons};
        if($trans_exon->strand() == 1) {
            $self->push($self->Line({
            'x'         => 0,
            'y'         => -4,
            'width'     => $length,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $colour
            }));
            $self->push( $self->Poly({
            'points' => [
                     $length - 4/$pix_per_bp,-2,
                     $length                ,-4,
                     $length - 4/$pix_per_bp,-6],
                'colour'    => $colour,
                'absolutey' => 1,
            }));
        } else {
            $self->push($self->Line({
            'x'         => 0,
            'y'         => $h+4,
            'width'     => $length,
            'height'    => 0,
            'absolutey' => 1,
            'colour'    => $colour
            }));
            $self->push($self->Poly({
            'points'    => [ 4/$pix_per_bp,$h+6,
                     0,              $h+4,
                     4/$pix_per_bp,$h+2],
            'colour'    => $colour,
            'absolutey' => 1,
            }));
        }
        }  
    }
    }
  if($transcript_drawn) {
    my $type = $self->_type;
    my @legend = %used_colours;
    $Config->{'legend_features'}->{$type} = {
      'priority' => $self->_pos,
      'legend'   => \@legend
    };

    ## my ($key, $priority, $legend) = $self->legend( $colours );
    # define which legend_features should be displayed
    # this is being used by GlyphSet::gene_legend
    ## $Config->{'legend_features'}->{$key} = {
    ##  'priority' => $priority,
    ##  'legend'   => $legend
    ## } if defined($key);
  } elsif( $Config->get_parameter( 'opt_empty_tracks')!=0) {
    $self->errorTrack( "No ".$self->error_track_name()." in this region" );
  }
}

sub as_compact_init {
    my ($self) = @_;

    my $Config        = $self->{'config'};
    my $strand_flag   = $self->my_config('strand');
    my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};

    my $y             = 0;
    my $h             = 8;

    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list

    my @bitmap        = undef;
    my $colours       = $self->colours();
    my %used_colours; 
  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

    my $strand        = $self->strand();
    my $length        = $container->length;
    my $transcript_drawn = 0;

    my $gene_drawn = 0;
 
    my $compara = $Config->{'compara'};
    my $link    = $compara ? $Config->get_parameter( 'opt_join_transcript') : 0;
    $link = 0;

    my $join_col = 'blue';
    my $join_z   = -10;

    my %ugenes = map {$_->stable_id, $_ } @{$self->features()};

    foreach my $gn (keys(%ugenes)) {
    my $gene = $ugenes{$gn};

    my $gene_strand = $gene->strand;
    my $gene_stable_id = $gene->stable_id;
    next if $gene_strand != $strand and $strand_flag eq 'b';
    $gene_drawn = 1;

    my $Composite = $self->Composite({'y'=>$y,'height'=>$h});
    $Composite->{'href'} = $self->gene_href( $gene, %highlights );
    $Composite->{'zmenu'} = $self->gene_zmenu( $gene ) unless $Config->{'_href_only'};
    my($colour, $label, $hilight) = $self->gene_colour( $gene, $colours, %highlights );
    ($colour,$label) = ('orange','Other') unless $colour;

        $used_colours{ $label } = $colour;
    my @exons = ();
# In compact mode we 'collapse' exons showing just the gene structure, i.e overlapping exons/transcripts will be merged
    foreach my $transcript (@{$gene->get_all_Transcripts()}) {
        next if $transcript->start > $length ||  $transcript->end < 1;
        push @exons, $self->map_AS_Exons($transcript, $length);
    }

    next unless @exons;

    my $Composite2 = $self->Composite({'y'=>$y,'height'=>$h});
# All exons in the gene will be connected by a simple line which starts from a first exon if it within the viewed region, otherwise from the first pixel. The line ends with last exon of the gene or the end of the image .. 

    my $start = 0;
    my $end = 0;

# Start line from 1 if there are preceeding exons    
    if ($exons[0]->{exon}->{etype} eq 'B') {
        $start = 1;
    }
    
# End line at the end of the image if there are further exons beyond the region end .. 
    if ($exons[-1]->{exon}->{etype} eq 'A') {
        $end = $length;
    }
    
# Get only exons in view
    my @exons_in_view = grep { $_->{exon}->{etype} =~ /[NM]/} @exons;

# Set start and end of the connecting line if they are not set yet
    $start or $start = $exons_in_view[0]->start;
    $end or $end = $exons_in_view[-1]->end;
    
# Draw exons
    foreach my $exon (@exons_in_view) {
        my $s = $exon->start;
        my $e = $exon->end;
        $s = 1 if $s < 0;
        $e = $length if $e>$length;
        $transcript_drawn = 1;
        $Composite2->push($self->Rect({
        'x' => $s-1, 'y' => $y, 'width' => $e-$s+1,
        'height' => $h, 'colour'=>$colour, 'absolutey' => 1
        }));
    }

# Draw connecting line
    $Composite2->push($self->Rect({
        'x' => $start, 'width' => $end-$start+1,
        'height' => 0, 'y' => int($y+$h/2), 'colour' => $colour, 'absolutey' =>1,
    }));
    
    # Calculate and draw the coding region of the exon
    # only draw the coding region if there is such a region
    if($self->can('join')) {
        my @tags;
        @tags = $self->join( $gene->stable_id ) if $gene && $gene->can( 'stable_id' );
        foreach (@tags) {
        $self->join_tag( $Composite2, $_, 0, $self->strand==-1 ? 0 : 1, 'grey60' );
        $self->join_tag( $Composite2, $_, 1, $self->strand==-1 ? 0 : 1, 'grey60' );
        }
        

    }

    $Composite->push($Composite2);

    my $bump_height = $h + 2;
    if( $Config->{'_add_labels'} ) {
      if(my $text_label = $self->gene_text_label($gene) ) {
        my @lines = split "\n", $text_label;
        $lines[0] = "< $lines[0]" if $strand < 1;
        $lines[0] = $lines[0].' >' if $strand >= 1;
        for( my $i=0; $i<@lines; $i++ ){
          my $line = $lines[$i].' ';
          my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $fontsize, 'font' => $fontname );
          $Composite->push( $self->Text({
            'x'         => $Composite->x(),
            'y'         => $y + $h + $i*($th+1),
            'height'    => $th,
            'width'     => $w / $pix_per_bp,
            'font'      => $fontname,
            'ptsize'    => $fontsize,
            'halign'    => 'left',
            'colour'    => $colour,
            'text'      => $line,
            'absolutey' => 1,
          }));
          $bump_height += $th+1;
        }
      }
    }

    ########## bump it baby, yeah! bump-nology!
    my $bump_start = int($Composite->x * $pix_per_bp);
    $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
    $bump_end = $bitmap_length if $bump_end > $bitmap_length;
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap);
    ########## shift the composite container by however much we're bumped
    $Composite->y($Composite->y() - $strand * $bump_height * $row);
    $Composite->colour($hilight) if defined $hilight;
    $self->push($Composite);
  }
    
  if($transcript_drawn) {
    my $type = $self->_type;
    my @legend = %used_colours;
    $Config->{'legend_features'}->{$type} = {
      'priority' => $self->_pos,
      'legend'   => \@legend
    };

    ## my ($key, $priority, $legend) = $self->legend( $colours );
    # define which legend_features should be displayed
    # this is being used by GlyphSet::gene_legend
    ## $Config->{'legend_features'}->{$key} = {
    ##  'priority' => $priority,
    ##  'legend'   => $legend
    ## } if defined($key);
  } elsif( $Config->get_parameter( 'opt_empty_tracks')!=0) {
    $self->errorTrack( "No ".$self->error_track_name()." in this region" );
  }
}

1;
