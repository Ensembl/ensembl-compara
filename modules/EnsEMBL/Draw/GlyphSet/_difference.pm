=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::_difference;

### Module to show differences between two large regions where
### those differences are small (in contrast to compara alignments,
### which show small matches between large regions)

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

sub colourmap {
  return $_[0]->{'config'}->hub->colourmap;
}

sub _render_background {
  my ($self,$start,$end,$bump_offset) = @_;

  $self->push($self->Rect({
    x         => $start-1,
    y         => 20 + $bump_offset,
    width     => $end-$start+1,
    height    => 8,
    colour    =>'#ddddff',
    absolutey => 1,
  }));        
}

sub _render_fname {
  my ($self,$left,$string,$bump_offset) = @_;

  my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext'); 
  my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $string, '', font => $font, ptsize => $fontsize);
  $self->push($self->Text({
    x         => $left + 6 / $self->scalex,
    y         => $bump_offset + 38 - $text_height,
    width     => $text_width / $self->scalex,
    height    => $text_height,
    font      => $font,
    ptsize    => $fontsize,
    halign    => 'left',
    colour    => '#333366',
    text      => $string,
    absolutey => 1,
  }));
}

sub _cluster_zmenu {
  my ($self,$c) = @_;

  my @parts;
  my %cidx = map { $_->{'cigar_idx'} => 1 } @{$c->{'blobs'}};
  my $cigar_min_i = max(0,min(keys %cidx)-3);
  my $cigar_max_i = min(@{$c->{'cigar'}}-1,max(keys %cidx)+3);
  my ($pre,$post) = ('','');
  $pre = "... " if $cigar_min_i;
  $post = " ..." unless $cigar_max_i == @{$c->{'cigar'}}-1;
  my @cigfrag;
  foreach my $i ($cigar_min_i .. $cigar_max_i) {
    my $frag = "";
    $frag .= "<u><em>" if($cidx{$i});
    $frag .= $c->{'cigar'}->[$i];
    $frag .= "</u></em>" if($cidx{$i});
    push @cigfrag,$frag;
  }
  my $ref_mid = ($c->{'ref_start'}+$c->{'ref_end'})/2;
  my $ref_width = max(25,$c->{'ref_end'}-$c->{'ref_start'})*2;
  return $self->_url({
    action => 'AlignDiff',
    parent_action => $self->{'config'}->hub->action,
    cigar => $pre.join(" ",@cigfrag).$post,
    ctype => $c->{'type_str'},
    num => scalar @{$c->{'blobs'}},
    len => $c->{'length'},
    span => $c->{'ref_end'} - $c->{'ref_start'} +1,
    zoom => sprintf("%s:%d-%d",$c->{'ref_name'},$c->{'ref_start'}+$c->{'ref_to_coord'},$c->{'ref_end'}+$c->{'ref_to_coord'}),
    zoom_r => sprintf("%s:%d-%d",$c->{'ref_name'},($ref_mid-$ref_width/2)+$c->{'ref_to_coord'},($ref_mid+$ref_width/2)+$c->{'ref_to_coord'}),
    midel => $c->{'midel'},
    rel => $c->{'rel'},
    lel => $c->{'lel'},
    plumped => $c->{'int_size'} < $c->{'size'},
  });
}

sub _calc_clusters {
  my ($self,$blobs,$type,$options) = @_;
  
  @$blobs = sort { $a->{'req_start'} <=> $b->{'req_start'} } @$blobs; 
  my @clusters;
  foreach my $blob (@$blobs) {
    my $reuse = 0;
    my $c = $clusters[$#clusters];
    if(defined $c and ($c->{'reserve_end'} + $options->{'leeway'} / $self->scalex >= $blob->{'req_start'})) {
      # Add to existing cluster
      push @{$c->{'blobs'}},$blob;
      my $ref_delta = $blob->{'disp_ref_start'} - $c->{'disp_ref_start'};
      $c->{'disp_ref_start'} += $ref_delta if($ref_delta < 0);
      $c->{'disp_ref_end'} = max($c->{'disp_ref_end'},$blob->{'disp_ref_end'});
      $c->{'int_size'} += $blob->{'int_size'};
      $c->{'min_size'} = $options->{'composite_width'}->{$type}/$self->scalex;
      $c->{'midel'} ||= $blob->{'midel'};
      $c->{'length'} += $blob->{'length'};
      $c->{'ref_start'} = min($c->{'ref_start'},$blob->{'ref_start'});
      $c->{'ref_end'} = max($c->{'ref_end'},$blob->{'ref_end'});
    } else {
      # Add to a new cluster
      push @clusters,{
        %$blob,
        'blobs'         => [ $blob ],
        'min_size'      => $options->{'smallest_width'}->{$type}/$self->scalex,
        'reserve_start' => $blob->{'req_start'},
      };
    }
    $c = $clusters[$#clusters];
    $c->{'size'} = max($c->{'int_size'},$c->{'min_size'});
    $c->{'reserve_end'} = max($c->{'reserve_start'}+$c->{'size'}, # blob size
                              $c->{'disp_ref_end'});              # reference size
  }
  # Calculate full space now reserved for blob
  my @sc = sort { $a->{'reserve_start'} <=> $b->{'reserve_start'} } @clusters;
  my @middles;
  foreach my $i (1..$#sc) {
    $middles[$i] = ($sc[$i-1]->{'reserve_end'} + $sc[$i]->{'reserve_start'}) / 2;
  }
  foreach my $i (1..$#sc) {
    $sc[$i-1]->{'reserve_end'} = $middles[$i]-1;
    $sc[$i]->{'reserve_start'} = $middles[$i];
  }
  $sc[0]->{'reserve_start'} = -$sc[0]->{'ref_to_img'};
  $sc[$#sc]->{'reserve_end'} = $self->{'container'}->length - $sc[0]->{'ref_to_img'};
  foreach my $c (@clusters) {
    # keep it on screen, truncate if just too massive
    my $lhs_limit = -$c->{'ref_to_img'};
    my $rhs_limit = $lhs_limit + $self->{'container'}->length;
    if($c->{'reserve_start'} < $lhs_limit) {
      $c->{'reserve_start'} = $lhs_limit;
      $c->{'lel'} = 1; # assume the worst
    }
    if($c->{'reserve_end'} > $rhs_limit) {
      $c->{'reserve_end'} = $rhs_limit;
      $c->{'rel'} = 1; # assume the worst
    }
    if($c->{'reserve_end'} - $c->{'reserve_start'} >= $c->{'size'}) {
      # it's fine
      delete $c->{'lel'};
      delete $c->{'rel'};
    } else {
      # shrink!
      $c->{'size'} = $c->{'reserve_end'} - $c->{'reserve_start'};
    }
  }
  return \@clusters;
}

sub _draw_delete_blobs {
  my ($self,$clusters,$bump_offset,$options) = @_;
  
  foreach my $c (@$clusters) {
    my $middle = $self->_blob_middle($c);
    my $start = min($c->{'disp_ref_start'},$middle-$c->{'size'}/2);
    my $end = max($c->{'disp_ref_end'},$middle+$c->{'size'}/2); 
    
    my $zmenu_start = max($start-$options->{'relax'}/$self->scalex,$c->{'reserve_start'});
    my $zmenu_end = min($end+$options->{'relax'}/$self->scalex,$c->{'reserve_end'});
    
    if(@{$c->{'blobs'}} > 1) {
      # some pink will show
      $self->{'config'}->{'_difference_legend_pink'} = 1;
    }
    
    #$self->_debug_reservations($c,20+$bump_offset);
    # pink rectangle
    $self->push($self->Rect({
      x         => $c->{'disp_ref_start'} + $c->{'ref_to_img'},
      y         => 20 + $bump_offset,
      width     => $c->{'disp_ref_end'}-$c->{'disp_ref_start'},
      height    => 8,
      colour    => '#ffdddd',
      bordercolour => undef,
      absolutey => 1,
    }));    
    # rectangle for zmenu
    $self->push($self->Rect({
      x         => $zmenu_start + $c->{'ref_to_img'},
      y         => 20 + $bump_offset,
      width     => $zmenu_end-$zmenu_start+1,
      height    => 8,
      colour    => undef,
      bordercolour => undef,
      absolutey => 1,
      href      => $self->_cluster_zmenu($c),
    }));    
  }
}

sub _draw_delete_domains {
  my ($self,$clusters,$bump_offset) = @_;
  
  foreach my $c (@$clusters) {
    foreach my $b (@{$c->{'blobs'}}) {
      $self->push($self->Rect({
        x         => $b->{'disp_ref_start'} + $c->{'ref_to_img'},
        y         => 20 + $bump_offset,
        width     => $b->{'disp_ref_end'} - $b->{'disp_ref_start'},
        height    => 8,
        colour    => 'red',
        bordercolour => undef,
        absolutey => 1,
      }));      
    }
  }
}

sub _blob_middle {
  my ($self,$c) = @_;
  
  my $middle;
  my $ref_middle = ($c->{'disp_ref_start'}+$c->{'disp_ref_end'})/2;
  if($ref_middle-$c->{'size'}/2 > $c->{'reserve_start'} and
     $ref_middle+$c->{'size'}/2 < $c->{'reserve_end'}) {
    # yes, centre on ref sequence
    $middle = $ref_middle;
  } else {
    # no, push to relevant edge of reservation
    if($ref_middle-$c->{'size'}/2 <= $c->{'reserve_start'}) {
      # pushed off lhs, push to left
      $middle = $c->{'reserve_start'} + $c->{'size'}/2;
    } elsif($ref_middle+$c->{'size'}/2 >= $c->{'reserve_end'}) {
      # pushed off rhs, push to right
      $middle = $c->{'reserve_end'} - $c->{'size'}/2;      
    } else {
      # centre
      $middle = ($c->{'reserve_start'}+$c->{'reserve_end'})/2;
    }
  }
  return $middle;
}

sub _overlay_text {
  my ($self,$c,$middle,$y,$label,$tcol,$rcol,$min,$max) = @_;
  
  my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext'); 
  my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $label, '', font => $font, ptsize => $fontsize);
  my $width = min($text_width / $self->scalex * 1.5,$c->{'size'}); 
  $middle = min($middle,$max-$width/2) if defined $max;
  $middle = max($middle,$min+$width/2) if defined $min;
  if(defined $rcol) {
    $self->push($self->Rect({
      x         => $middle - $width/2  + $c->{'ref_to_img'},
      y         => $y,
      width     => $width,
      height    => 8,
      font      => $font,
      ptsize    => $fontsize,
      halign    => 'left',
      colour    => $rcol,
      text      => $label,
      absolutey => 1,
    })); 
  }
  $self->push($self->Text({
    x         => $middle - ($text_width-2) / $self->scalex / 2   + $c->{'ref_to_img'},
    y         => $y + 6 - $text_height,
    width     => $text_width / $self->scalex * 3,
    height    => $text_height,
    font      => $font,
    ptsize    => $fontsize,
    halign    => 'left',
    colour    => $tcol,
    text      => $label,
    absolutey => 1,
  }));
}

sub _debug_reservations {
  my ($self,$c,$y) = @_;
  
  $self->push($self->Rect({
    x         => $c->{'reserve_start'}+$c->{'ref_to_img'},
    y         => $y,
    width     => 1,
    height    => 40,
    colour    => 'orange',
    absolutey => 1,
  }));
  $self->push($self->Rect({
    x         => $c->{'reserve_end'}+$c->{'ref_to_img'},
    y         => $y,
    width     => 1,
    height    => 40,
    colour    => 'purple',
    absolutey => 1,
  }));
}

sub _draw_blob {
  my ($self,$c,$y,$colour,$options) = @_;

  my $paler  = $self->colourmap->mix($colour,'white',0.5);
  my $darker = $self->colourmap->mix($colour,'black',0.5);

  # Is the affected reference region big enough?
  my $size = $c->{'size'};
  my $middle = $self->_blob_middle($c);
  
  my $start = $middle-$c->{'size'}/2;
  my $end = $middle+$c->{'size'}/2;
    
  my $zmenu_start = max($start-$options->{'relax'}/$self->scalex,$c->{'reserve_start'});
  my $zmenu_end = min($end+$options->{'relax'}/$self->scalex,$c->{'reserve_end'});

  $self->push($self->Rect({
    x         => $start + $c->{'ref_to_img'},
    y         => $y,
    width     => $end - $start,
    height    => 8,
    colour    => $colour,
    bordercolour => $darker,
    absolutey => 1,
  }));
  $self->push($self->Rect({
    x         => $zmenu_start + $c->{'ref_to_img'},
    y         => $y,
    width     => $zmenu_end-$zmenu_start+1,
    height    => 18,
    colour    => undef,
    bordercolour => undef,
    absolutey => 1,
    href      => $self->_cluster_zmenu($c),
  }));
  
  # uncomment to see reserve_{start,end} on the track
  #$self->_debug_reservations($c,$y);
  if(@{$c->{'blobs'}}>1) {
    $self->_overlay_text($c,$middle,$y,"..",'white');
  }
  if($c->{'rel'}) {
    $self->_overlay_text($c,$c->{'reserve_end'},$y,"...",'black',$paler,undef,$middle + $c->{'size'}/2+1);
    $self->{'config'}->{'_difference_legend_el'} = 1;
  } elsif($c->{'lel'}) {
    $self->_overlay_text($c,$c->{'reserve_start'},$y,"...",'black',$paler,$middle - $c->{'size'}/2-1,undef);
    $self->{'config'}->{'_difference_legend_el'} = 1;
  } elsif($c->{'midel'}) {
    $self->_overlay_text($c,$middle-$c->{'size'}/4,$y,"...",'black',$paler);
    $self->_overlay_text($c,$middle+$c->{'size'}/4,$y,"...",'black',$paler);
    $self->{'config'}->{'_difference_legend_el'} = 1;
  }
}

sub _draw_insert_blobs {
  my ($self,$clusters,$bump_offset,$options) = @_;
  
  foreach my $c (@$clusters) {
    $self->_draw_blob($c,$bump_offset,'#2aa52a',$options);
  }
}

sub _draw_insert_lines {
  my ($self,$clusters,$bump_offset) = @_;
  
  foreach my $c (@$clusters) {
    my $bmiddle = $self->_blob_middle($c);
    my $bstart = $bmiddle - $c->{'size'}/2;
    if(@{$c->{'blobs'}} > 1) {
      # some dots will show
      $self->{'config'}->{'_difference_legend_dots'} = 1;
    }
    # Apportion blob
    my $blob_len;
    $blob_len += $_->{'length'} for(@{$c->{'blobs'}});
    my $px_per_len = $c->{'size'} / $blob_len;
    my $offset = 0;
    foreach my $b (sort { $a->{'disp_ref_start'} <=> $b->{'disp_ref_start'} } @{$c->{'blobs'}}) {
      my $len = $b->{'length'} * $px_per_len;
      $self->push($self->Poly({
        points => [
          $b->{'disp_ref_start'} + $c->{'ref_to_img'},18+$bump_offset,    # left on ref
          $b->{'disp_ref_end'} + $c->{'ref_to_img'},18+$bump_offset,      # right on ref
          $bstart + $offset + $c->{'ref_to_img'},10+$bump_offset, # right on top
          $bstart + $offset + $len + $c->{'ref_to_img'},10+$bump_offset, # left on top
        ],
        colour    => '#2aa52a',
        absolutey => 1,
        href      => $self->_cluster_zmenu($c),
      }));
      $offset += $len;
    }
  }
}

sub _add_blob {
  my ($self,$f,$ref_start,$ref_end,$type,$length,$cigar,$i,$options) = @_;
  
  my $midel = 0;
  my $size=$length;
  if($length > $self->{'container'}->length * 0.2 and $type eq 'I') {
    # massive insert feature: will probably shift everything so
    # much that it looks screwed. Apply middle-ellipsis.
    $size = $self->{'container'}->length * 0.2;
    $midel = 1;
  }
  my $blob_start = $ref_start;
  if($type eq 'I') {
    $blob_start -= $size/2; # put blob at /middle/ of insert point   
  } else {
    # single blobs should be in middle-ish of reservation
    $blob_start -= $options->{'smallest_width'}->{'D'}/$self->scalex/2;
  }
  my $disp_start = $ref_start;
  # check we don't fall off LHS
  $disp_start = max(-$f->start,$disp_start);
  $blob_start = max(-$f->start,$blob_start);
  my $rname = $f->seqname;
  $rname = $f->seq_region_name if $f->can('seq_region_name'); # missing from GFF
  my $ref_to_coord = $self->{'container'}->start + $f->start -1; # -1 cos adding two 1-based coordinates
  my $ref_span = $ref_end-$ref_start;
  return {
    ref_name  => $rname,                      # reference name
    ref_start => $ref_start,                  # true reference start
    ref_end => $ref_end,                      # true reference end
    disp_ref_start => $disp_start,            # where we want to start displaying the reference (eg maybe truncated)
    disp_ref_end  => $disp_start + $ref_span, # where we want to start displaying the reference (eg maybe truncated)
    int_size => $size,                        # what is the "size" of this feature (in bp)
    req_start => $blob_start,                 # where we'd ideally want our display to start
    ref_to_img => $f->start-1,                # delta from reference to image start (-1 because screen bases are 0-based)
    ref_to_coord => $ref_to_coord,            # delta from reference to true coord
    midel => $midel,                          # middle ellipsis: insert too long to display in full on this scale
    type_str => { 'I' => 'insert',            # For zmenus
                  'D' => 'delete'  }->{$type},
    length => $length,                        # true length
    cigar => $cigar,                          # Full CIGAR line for zmenu
    cigar_idx => $i,                          # Index in CIGAR for zmenu
  };
}

sub draw_cigar_difference {
  my ($self,$options) = @_;
  
  $self->_init_bump;
  my %features = $self->features;
  my $strand          = $self->strand;
  my @sorted          = $self->sort_features_by_priority(%features);                                    # Sort (user tracks) by priority
     @sorted          = $strand < 0 ? sort keys %features : reverse sort keys %features unless @sorted;
  my $size = $self->{'container'}->length;
  return unless $self->strand == 1; # Always display on +ve strand. Is this ok?

  $options ||= {};
  $options = { # set defaults: relies on later initialiazers overriding earlier.
    row_height => 40,
    smallest_width => { 'D' => 3, 'I' => 4 },
    composite_width => { 'D' => 0, 'I' => 10 }, # D = 0 because leeway is enough
    leeway => 4,
    skip_labels => 0,
    relax => 4, # expand zmenu by this amount, if available
    %$options
  };

  # How big are our clusters?
  my $pix_per_cluster = 8; # Maybe make configurable, maybe wrong size?
  my $out='';
  foreach my $feature_key (@sorted) {
    ## Fix for userdata with per-track config
    my ($config, @features);
    
    $self->{'track_key'} = $feature_key;    
    next unless $features{$feature_key};
    my @tmp = @{$features{$feature_key}};
    if (ref $tmp[0] eq 'ARRAY') {
      @features = @{$tmp[0]};
      $config   = $tmp[1];
    } else {
      @features = @tmp;
    }
    $self->{'config'}->{'_difference_legend'} = 1 if(@features); # instruct to draw legend
    foreach my $f (@features) {
      my %parts;
      my $cigar;
      eval { $cigar = $f->cigar_string; };
      unless($cigar) {
        # XXX should disable this renderer, really when not an appropriate source
        # or move this whole sub into a subclass
        warn "no cigar";
        next;
      }
      my @cigar;
      next if($cigar =~ /\d$/); # Skip erroneous duplicate data in e70, e71.
      @cigar = $cigar =~ /(\d*\D)/g;
      my $draw_start = max(0,$f->start);
      my $bump_start = $draw_start*$self->scalex;
      my $draw_end = min($self->{'container'}->length,$f->end);
      my $bump_end = $draw_end*$self->scalex;      
      my $row = $self->bump_row($bump_start,$bump_end);
      my $img_bp = 0;
      foreach my $i (0..$#cigar) {
        local $_ = $cigar[$i];
        my ($length, $type) = /^(\d+)(\D)/ ? ($1, $2) : (1, $_);
        my $ref_start = $img_bp;
        $img_bp += $length unless($type eq 'I');
        my $ref_end = $img_bp;
        next if $type eq 'M';
        next if $ref_end+$f->start < 0 or $ref_start+$f->start > $self->{'container'}->length;
        push @{$parts{$type}},$self->_add_blob($f,$ref_start,$ref_end,
                                               $type,$length,
                                               \@cigar,$i,$options);
      }
      my $rh = $options->{'row_height'};
      my $fname;
      $fname = $f->display_id if $f->can('display_id');
      $self->_render_background(max(1,$f->start),min($self->{'container'}->length,$f->end),$row*$rh);
      $self->_render_fname($draw_start,$fname,$row*$rh) if $fname and not $options->{'skip_labels'};
      my $deletes = $self->_calc_clusters($parts{'D'}||[],'D',$options);
      $self->_draw_delete_blobs($deletes,$row*$rh,$options);
      $self->_draw_delete_domains($deletes,$row*$rh);
      my $inserts = $self->_calc_clusters($parts{'I'}||[],'I',$options);
      $self->_draw_insert_blobs($inserts,$row*$rh,$options);
      $self->_draw_insert_lines($inserts,$row*$rh);
    }
  }
}

1;
