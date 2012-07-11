package Bio::EnsEMBL::GlyphSet::_difference;

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

use List::Util qw(min max);

my $DEBUG = 0;

my $xxx_scale_px = 8;
my $xxx_cluster_px = 32;

sub colourmap {
  return $_[0]->{'config'}->hub->colourmap;
}

sub _render_background {
  my ($self,$start,$end) = @_;

  $self->push($self->Rect({
    x         => $start,
    y         => 20,
    width     => $end-$start+1,
    height    => 8,
    colour    =>'#ddddff',
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
    if($cidx{$i}) {
      $frag .= "<u><em>";
    }
    $frag .= $c->{'cigar'}->[$i];
    if($cidx{$i}) {
      $frag .= "</u></em>";
    }
    push @cigfrag,$frag;
  }
  my $ref_mid = ($c->{'ref_start'}+$c->{'ref_end'})/2;
  my $ref_width = max(25,$c->{'ref_end'}-$c->{'ref_start'})*2;
  return $self->_url({
    action => 'AlignDiff',
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

my $leeway_px = 3 * $xxx_scale_px;
sub _calc_clusters {
  my ($self,$blobs) = @_;
  
  @$blobs = sort { $a->{'req_start'} <=> $b->{'req_start'} } @$blobs; 
  my @clusters;
  foreach my $blob (@$blobs) {
    my $reuse = 0;
    my $c = $clusters[$#clusters];
    if(defined $c and ($c->{'reserve_end'} + $leeway_px / $self->scalex >= $blob->{'req_start'})) {
      # Add to existing cluster
      push @{$c->{'blobs'}},$blob;
      my $ref_delta = $blob->{'disp_ref_start'} - $c->{'disp_ref_start'};
      $c->{'disp_ref_start'} += $ref_delta if($ref_delta < 0);
      $c->{'disp_ref_end'} = max($c->{'disp_ref_end'},$blob->{'disp_ref_end'});
      $c->{'int_size'} += $blob->{'int_size'};
      $c->{'min_size'} = $xxx_cluster_px/$self->scalex;
      $c->{'midel'} ||= $blob->{'midel'};
      $c->{'length'} += $blob->{'length'};
      $c->{'ref_start'} = min($c->{'ref_start'},$blob->{'ref_start'});
      $c->{'ref_end'} = max($c->{'ref_end'},$blob->{'ref_end'});
    } else {
      # Add to a new cluster
      push @clusters,{
        %$blob,
        'blobs'         => [ $blob ],
        'min_size'      => $xxx_scale_px/$self->scalex,
        'reserve_start' => $blob->{'req_start'},
      };
    }
    $c = $clusters[$#clusters];
    $c->{'size'} = max($c->{'int_size'},$c->{'min_size'});
    $c->{'reserve_end'} = max($c->{'reserve_start'}+$c->{'size'}, # blob size
                              $c->{'disp_ref_end'});              # reference size
  }
  # Calculate full space now reserved for blob
  foreach my $c (@clusters) {
    # extend reservations XXX cleverer nudging
    $c->{'reserve_start'} -= $leeway_px/2/$self->scalex;
    $c->{'reserve_end'} += $leeway_px/2/$self->scalex;
  }
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

sub _draw_delete_domains {
  my ($self,$clusters) = @_;
  
  foreach my $c (@$clusters) {
    
    $self->push($self->Rect({
      x         => $c->{'disp_ref_start'} + $c->{'ref_to_img'},
      y         => 20,
      width     => $c->{'disp_ref_end'} - $c->{'disp_ref_start'},
      height    => 8,
      colour    => '#ffdddd',
      bordercolour => undef,
      absolutey => 1,
#     href      => $url,
    }));
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
  #      href      => $url,
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
#      href      => $url,
  }));
}

sub _draw_blob {
  my ($self,$c,$y,$colour) = @_;

  my $paler  = $self->colourmap->mix($colour,'white',0.5);
  my $darker = $self->colourmap->mix($colour,'black',0.5);

  # Is the affected reference region big enough?
  my $size = $c->{'size'};
  my $middle = $self->_blob_middle($c);
  $self->push($self->Rect({
    x         => $middle - $c->{'size'}/2 + $c->{'ref_to_img'},
    y         => $y,
    width     => $c->{'size'},
    height    => 8,
    colour    => $colour,
    bordercolour => $darker,
    absolutey => 1,
    href      => $self->_cluster_zmenu($c),
  }));
  if($DEBUG) {
    $self->push($self->Rect({
      x         => $c->{'reserve_start'}+$c->{'ref_to_img'},
      y         => $y,
      width     => 1,
      height    => 40,
      colour    => 'orange',
      absolutey => 1,
  #      href      => $url,
    }));
    $self->push($self->Rect({
      x         => $c->{'reserve_end'}+$c->{'ref_to_img'},
      y         => $y,
      width     => 1,
      height    => 40,
      colour    => 'purple',
      absolutey => 1,
  #      href      => $url,
    }));
  }
  if(@{$c->{'blobs'}}>1) {
    $self->_overlay_text($c,$middle,$y,"../../..",'white');
  }
  if($c->{'rel'}) {
    $self->_overlay_text($c,$c->{'reserve_end'},$y,"...",'black',$paler,undef,$middle + $c->{'size'}/2+1);
  } elsif($c->{'lel'}) {
    $self->_overlay_text($c,$c->{'reserve_start'},$y,"...",'black',$paler,$middle - $c->{'size'}/2-1,undef);
  } elsif($c->{'midel'}) {
    $self->_overlay_text($c,$middle-$c->{'size'}/4,$y,"...",'black',$paler);
    $self->_overlay_text($c,$middle+$c->{'size'}/4,$y,"...",'black',$paler);
  }
}

sub _draw_delete_blobs {
  my ($self,$clusters) = @_;
  
  foreach my $c (@$clusters) {
    $self->_draw_blob($c,20,'brown');
  }
}

sub _draw_insert_blobs {
  my ($self,$clusters) = @_;
  
  foreach my $c (@$clusters) {
    $self->_draw_blob($c,0,'#2aa52a');
  }
}

sub _draw_insert_lines {
  my ($self,$clusters) = @_;
  
  foreach my $c (@$clusters) {
    my $dmiddle = $self->_blob_middle($c);

    $self->push($self->Poly({
      points => [
        $c->{'disp_ref_start'} + $c->{'ref_to_img'},18,    # left on ref
        $c->{'disp_ref_end'} + $c->{'ref_to_img'},18,      # right on ref
        $dmiddle + $c->{'size'}/2 + $c->{'ref_to_img'},10, # right on top
        $dmiddle - $c->{'size'}/2 + $c->{'ref_to_img'},10, # left on top
      ],
      colour    => '#2aa52a',
      absolutey => 1,
      href      => $self->_cluster_zmenu($c),
    }));
  }
}

sub _render_delete_subtrack {
  my ($self,$deletes) = @_;

  my $clusters = $self->_calc_clusters($deletes);
  $self->_draw_delete_domains($clusters);
  $self->_draw_delete_blobs($clusters);
}

sub _render_insert_subtrack {
  my ($self,$inserts) = @_;

  my $clusters = $self->_calc_clusters($inserts);
  $self->_draw_insert_blobs($clusters);
  $self->_draw_insert_lines($clusters);
}

sub draw_cigar_difference {
  my ($self,$options) = @_;
  
  my %features = $self->features;
  
  my $strand          = $self->strand;
  my @sorted          = $self->sort_features_by_priority(%features);                                    # Sort (user tracks) by priority
     @sorted          = $strand < 0 ? sort keys %features : reverse sort keys %features unless @sorted;
  my $size = $self->{'container'}->length;

  next unless $self->strand == 1; # Always display on +ve strand. Is this ok?

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
    my %parts;
    foreach my $f (@features) {
      my $cigar;
      eval { $cigar = $f->cigar_string; };
      unless($cigar) {
        # XXX should disable this renderer, really when not an appropriate source
        # or move this whole sub into a subclass
        warn "no cigar";
        next;
      }
      my @cigar = $f->cigar_string =~ /(\d*\D)/g;
      my $img_bp = 0;
      foreach my $i (0..$#cigar) {
        local $_ = $cigar[$i];
        my ($length, $type) = /^(\d+)(\D)/ ? ($1, $2) : (1, $_);
        my $blob_start = $img_bp;
        my $ref_start = $img_bp;
        $img_bp += $length unless($type eq 'I');
        my $ref_end = $img_bp;
        next if $type eq 'M';
        my $ref_span = $length;
        next if $blob_start+$f->start+$length+$length < 0 or $blob_start+$f->start > $self->{'container'}->length;
        my $midel = 0;
        my $size=$length;
        if($length > $self->{'container'}->length * 0.2 and $type eq 'I') {
          # massive insert feature: will probably shift everything so
          # much that it looks screwed. Apply middle-ellipsis.
          $size =  $self->{'container'}->length * 0.2;
          $midel = 1;
        }
        if($type eq 'I') {
          $blob_start -= $size/2; # put blob at /middle/ of insert point   
          $ref_span = 0; # inserts do not span reference
        }
        my $disp_start = $img_bp;
        # check we don't fall off LHS
        $disp_start = max(-$f->start,$disp_start);
        $blob_start = max(-$f->start,$blob_start);
        my $name = $f->seqname;
        $name = $f->seq_region_name if $f->can('seq_region_name'); # missing from GFF
        my $ref_to_coord = $self->{'container'}->start + $f->start;
        push @{$parts{$type}},{
          ref_name  => $name,                       # reference name
          ref_start => $ref_start,                  # true reference start
          ref_end => $ref_end,                      # true reference end
          disp_ref_start => $disp_start,            # where we want to start displaying the reference (eg maybe truncated)
          disp_ref_end  => $disp_start + $ref_span, # where we want to start displaying the reference (eg maybe truncated)
          int_size => $size,                        # what is the "size" of this feature (in bp)
          req_start => $blob_start,                 # where we'd ideally want our display to start
          ref_to_img => $f->start-1,                # delta from reference to image start
          ref_to_coord => $ref_to_coord,            # delta from reference to true coord
          midel => $midel,                          # middle ellipsis: insert too long to display in full on this scale
          type_str => { 'I' => 'insert',            # For zmenus
                        'D' => 'delete'  }->{$type},
          length => $length,                        # true length
          cigar => \@cigar,                         # Full CIGAR line for zmenu
          cigar_idx => $i,                          # Index in CIGAR for zmenu
        };
      }
      $self->_render_background(max(0,$f->start),min($self->{'container'}->length,$f->end));
    }
    my $size_bp = $self->{'container'}->length;
    $self->_render_delete_subtrack($parts{'D'}||[]);
    $self->_render_insert_subtrack($parts{'I'}||[]);
  }
}

1;
