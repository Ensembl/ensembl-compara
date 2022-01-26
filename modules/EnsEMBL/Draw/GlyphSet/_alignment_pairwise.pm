=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::_alignment_pairwise;

### Draws compara pairwise alignments - see EnsEMBL::Web::ImageConfig
### and E::W::ImageConfig::MultiBottom for usage

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

use List::Util qw(min max);

# Useful for debugging. Should all be 0 in checked-in code.
my $debug_force_cigar   = 0; # CIGAR at all resolutions
my $debug_rainbow       = 0; # Joins in rainbow colours to tell them apart
my $debug_force_compact = 0; # render_normal -> render_compact
my $debug_force_text    = 0; # render_normal -> render_text

# Split CIGAR into array, used by cigar_string
sub _parse_cigar {
  my @out; 
  while($_[0] =~ s/^(\d*)([A-Z])//) { push @out,[$1||1,$2]; }
  return \@out;
}

# Build CIGAR string from "match/gap" CIGARs in each GenomicAlign.
# (The one good thing we once got automatically from DnaAlignFeatures).
# Based on _convert_GenomicAlignBlocks_into_DnaDnaAlignFeatures, but
# implemented more efficiently.
sub cigar_string {
  my ($self,$gab) = @_;

  my @inputs = map { _parse_cigar($_) } (
    $gab->reference_genomic_align->cigar_line,
    $gab->get_all_non_reference_genomic_aligns->[0]->cigar_line
  );
  if($gab->reference_slice_strand < 0) {
    @inputs = map { [ reverse @$_ ] } @inputs;
  }
  my @out;
  while(@{$inputs[0]} and @{$inputs[1]}) {
    my $n = min(map { $_->[0][0] } @inputs);
    my $m = join("",map { ($_->[0][1] eq 'M')?'N':'-' } @inputs);
    $m = { NN => 'M', 'N-' => 'I', '-N' => 'D' }->{$m};
    return undef unless($m);
    push @out,[$n,$m];
    foreach my $in (@inputs) {
      shift @$in unless $in->[0][0] -= $n;
    }
  }
  return join("",map { (($_->[0]==1)?'':$_->[0]).$_->[1] } @out);
}

# Calculates glyphs, -- an array of what needs to be drawn -- from a
# CIGAR string. Can then be passed to draw_cigar_glyphs (or otherwise).
sub calc_cigar_glyphs {
  my ($self,$start,$length,$cigar,$reverse,$flip_tags) = @_;

  my $start_pos = $start - 1;

  my @cigar = @{_parse_cigar($cigar)};
  @cigar = reverse @cigar if($reverse);
  my @positions;
  my $tcount = ($flip_tags?scalar(@cigar)+1:0);
  foreach (@cigar) {
    my ($num,$type) = @$_;
    $tcount += ($flip_tags?-1:1);
    my $end_pos = $start_pos;
    $end_pos += $num unless $type eq 'D';
    if($end_pos<0 or $start_pos>$length) { $start_pos = $end_pos; next; }
    my $num = $end_pos - $start_pos;
    $num += $start_pos if $start_pos<0;               # choped off start
    $num -= $end_pos - $length if $end_pos > $length; # chopped off end
    push @positions,[$type,max($start_pos,0),$num,$tcount];
    $start_pos = $end_pos;
  }
  return \@positions;
}

# Common rectangle-drawing routine
sub draw_rect {
  my ($self,$params,$start,$length,$colour) = @_;
  unless ($colour && $colour eq 'transparent') {
    $colour = $params->{$colour || 'feature_colour'};
  }

  my $out = $self->Rect({
    x      => $start,
    y      => $params->{'y'} || 0,
    width  => $length,
    height => $params->{'h'},
    colour => $colour,
  });
  return $out;
}

# Draws CIGAR glyphs as previously calculated by calc_cigar_glyphs.
# Returns a hash of boxes created against their "ID", -- ie position in the
# CIGAR string, -- to allow joins, etc.
sub draw_cigar_glyphs {
  my ($self,$glyphs,$composite,$params) = @_;

  my $index = 0;
  my %boxes;

  # Draw matches
  foreach (@$glyphs) {
    my ($type,$start,$length,$id) = @$_;

    if($type =~ /[MmU=X]/) {
      my $box = $self->draw_rect($params,$start,$length);
      $composite->push($box);
      $boxes{$id} = $box;
    }
  }

  # Reloop to ensure on top of matches
  foreach (@$glyphs) {
    my ($type,$start,$length,$id) = @$_;
    next unless $type eq 'D';
    $composite->push($self->draw_rect($params,$start,0,'delete_colour'));
  }

  return \%boxes;
}

# Combine calc_cigar_glyphs and draw_cigar_glyphs to draw a cigar
sub draw_cigar {
  my ($self,$params,$args,$composite,$gab,$joins) = @_;

  my $glyphs = $self->calc_cigar_glyphs(
    $gab->reference_slice_start,
    $gab->reference_slice->length,
    $self->cigar_string($gab),
    $gab->reference_slice_strand == -1,
    $self->should_draw_cross($gab) && $self->strand==1 # flip tag names
  );
  my $boxes = $self->draw_cigar_glyphs($glyphs,$composite,$params);
  if($params->{'link'}) {
    foreach my $id (keys %$boxes) {
      $joins->{join(":",@{$args->{'tag'}},$id)} = { x => $args->{'drawx'}, box => $boxes->{$id} };
    }
    # Though we are CIGAR, our joiner may not be, so add a transparent box
    # with tag!
    my ($x,$width,$ori,$r,$r1) = $self->calculate_region($gab);
    my $box = $self->draw_rect($params,$x,$width,'transparent');
    $self->push($box);
    $joins->{join(":",@{$args->{'tag'}})} = { x => $args->{'drawx'}, box => $box };
  }
}

# Draw a single, regular, non-CIGAR box
sub draw_non_cigar {
  my ($self,$params,$args,$gab,$joins,$zm) = @_;

  my ($x,$width,$ori,$r,$r1) = $self->calculate_region($gab);
  my $box = $self->draw_rect($params,$x,$width);
  $self->add_zmenu($zm,$box,$ori,$r,$r1);
  $self->push($box);
  if ($params->{'link'}) {
    $joins->{join(":",@{$args->{'tag'}})} = { x => $args->{'drawx'}, box => $box };
  }
}

# Draw green joining crosses and quadrilaterals
my @rainbow = qw(red orange yellow green cyan blue purple);
sub draw_joins {
  my ($self,$joins) = @_;

  my $part = ($self->strand == 1) || 0;
  my @shapes = (
    [[0,0],[0,1],[1,1],[1,0]], # circuit makes quadrilateral,
    [[0,0],[0,1],[1,0],[1,1]], # but zigzag makes cross
  );
  my $feature_key = lc $self->my_config('type');
 
  foreach my $tag (keys %$joins) {
    foreach my $s (@{$shapes[$joins->{$tag}{'x'}]}) {
      next unless $s->[0] == $part; # only half of it is on each track
      my $colour = $self->my_colour($feature_key, 'join') || 'gold'; 
      $colour = $rainbow[rand()*7] if($debug_rainbow);
      $self->join_tag($joins->{$tag}{'box'},$tag,{
        x => $s->[1],
        y => !$s->[0] || 0, # y start at bottom edge of upper block & vice versa
        z => $self->my_colour($feature_key, 'join_z') || 100,
        col => $colour,
        style => 'fill'
      });
    } 
  }
}

# Should we draw a cross rather than a quadrilateral?
sub should_draw_cross {
  my ($self,$gab) = @_;

  my $this_ori  = $gab->reference_slice_strand;
  my $other_ori = $self->my_config('ori');
  my $nonref    = $gab->get_all_non_reference_genomic_aligns->[0];
  
  # flipdata -- alignment is interstrand
  # flipview -- views are in opposite orientations
  my $flipdata = ($gab->reference_slice_strand != $nonref->dnafrag_strand);
  my $flipview = (($this_ori == -1) xor ($other_ori == -1));
  return ($flipdata xor $flipview);
}

# Special GABs are ones where they contain a displayed GA for more than
#   one displayed slice. This method tests all the passed GABs to see if
#   any of them are special. A special GAB is then prioritised in sorting
#   to try to ensure that it is displayed despite maximum depths.
sub is_special {
  my ($self,$gabs,$slices) = @_;

  foreach my $gab (@$gabs) {
    my $c = 0;
    foreach my $ga (@{$gab->get_all_GenomicAligns}) {
      foreach my $slice (@$slices) {
        my ($species,$seq_region,$start,$end) = split(':',$slice);
        next unless lc $species eq lc $ga->genome_db->name;
        next unless $seq_region eq $ga->dnafrag->name;
        next unless $end >= $ga->dnafrag_start();
        next unless $start <= $ga->dnafrag_end();
        $c++;
        return 1 if $c > 1;
      }
    }
  }
  return 0;
}

# Features are grouped and rendered together: make those groups
sub build_features_into_sorted_groups {
  my ($self,$gabs,$slices) = @_;

  my $container   = $self->{'container'};
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');
  my $length      = $container->length;
  my $part = ($strand == 1) || 0;
  my %out;
  my $k = 0;
  foreach my $gab (@{$gabs||[]}) {
    my $start = $gab->reference_slice_start;
    my $end = $gab->reference_slice_end;
    my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
    my $hseqname = $nonref->dnafrag->name;
    
    my $flip = ( $gab->reference_slice_strand != $nonref->dnafrag_strand );
    next if $end < 1 || $start > $length;
    next if $strand_flag eq 'b' && ($flip xor !$part);
    my $key = $hseqname . ':' . ($gab->group_id || ('00' . $k++));
    push @{$out{$key}{'gabs'}},[$start,$gab];
  }
  # sort contents of groups by start
  foreach my $g (values %out) {
    my @f = map {$_->[1]} sort { $a->[0] <=> $b->[0] } @{$g->{'gabs'}};
    $g->{'len'} = max(map { $_->reference_slice_end   } @f) -
                  min(map { $_->reference_slice_start } @f);
    $g->{'gabs'} = \@f;
    $g->{'special'} = $self->is_special($g->{'gabs'},$slices);
  }
  # Sort by length
  return
    map { $_->{'gabs'} } sort {
      ($b->{'special'} <=> $a->{'special'}) ||
      ($b->{'len'} <=> $a->{'len'})
    } values %out;
}

# Sort and exclude irrelevant features for compact display.
# Equivalent to build_features_into_sorted_groups, as used on normal.
sub get_compact_features {
  my ($self,$gabs) = @_;
  
  my $container   = $self->{'container'};
  my $length      = $container->length;
  my $strand_flag = $self->my_config('strand');
  my $strand      = $self->strand;
  my $part        = ($strand == 1) || 0;
  my @out;
  foreach my $gab (@$gabs) {
    my $start = $gab->reference_slice_start;
    my $end = $gab->reference_slice_end;
    my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
    my $flip = ( $gab->reference_slice_strand != $nonref->dnafrag_strand );
    next if $end < 1 || $start > $length;
    next if $strand_flag eq 'b' && ($flip xor $part);
    push @out,[$gab->reference_genomic_align->dnafrag_start,$gab];  
  }
  return [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } @out ];
}

# Draws out box of nets (hollow box)
sub draw_containing_box {
  my ($self,$gabs,$y_pos) = @_;

  my $ga_first = $gabs->[0];
  my $ga_last = $gabs->[-1];
  my $feature_key    = lc $self->my_config('type');
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $feature_colour = $self->my_colour($feature_key);
  my $container      = $self->{'container'};
  my $depth          = $self->depth || 6;
  my $length         = $container->length;
  my $ga_first_start = $ga_first->reference_slice_start;
  my $ga_last_end    = $ga_last->reference_slice_end;
  my $width = $ga_last_end;
  if ($width > $length) {
    $width = $length;
  }
  if ($ga_first_start > 0) {
    $width -= $ga_first_start - 1;
  }

  my $seqname = $ga_first->reference_genomic_align->dnafrag->name;
  my $start = $ga_first->reference_slice_start;
  my $end = $ga_first->reference_slice_end;
  my $abs_start = $ga_first->reference_slice->start + $start - 1;
  my $abs_end = $ga_first->reference_slice->start   + $end -1;
  my $n0 = "$seqname:$abs_start-$abs_end";

  my $net_composite = $self->Composite({
    x     => $ga_first_start > 1 ? $ga_first_start - 1 : 0,
    y     => $y_pos,
    width => $width,
    height => $h,
    bordercolour => $feature_colour,
    absolutey => 1,
  });
  return $net_composite;
}

# Makes the tricky n0,n1 parameters for ZMenu URLs
sub make_net_urls {
  my ($self,$gabs) = @_;
   
  my $ga_first = $gabs->[0];
  my $ga_first_nonref = $ga_first->get_all_non_reference_genomic_aligns->[0];
  # Determine extent of net on target and reference
  my ($hs_net,$he_net);
  my ($ref_s_net,$ref_e_net);
  foreach my $gab (@$gabs) {
    my $ref = $gab->reference_genomic_align;
    my $ref_start = $ref->dnafrag_start;
    my $ref_end = $ref->dnafrag_end;

    $ref_s_net = $ref_start if (!defined $ref_s_net) or $ref_start < $ref_s_net;
    $ref_e_net = $ref_end   if (!defined $ref_e_net) or $ref_end   > $ref_e_net;

    my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
    my $hstart = $nonref->dnafrag_start;
    my $hend = $nonref->dnafrag_end;
    $hs_net = $hstart if (!defined $hs_net) or $hstart < $hs_net;
    $he_net = $hend   if (!defined $he_net) or $hend   > $he_net;
  } 

  my $seqname = $ga_first->reference_genomic_align->dnafrag->name;
  my $n0 = "$seqname:$ref_s_net-$ref_e_net";
  my $n1 = $ga_first_nonref->dnafrag->name. ":$hs_net-$he_net";

  return ($n0,$n1);
}

# Get orientation of GAB
sub get_ori {
  my ($self,$gab) = @_;

  my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
  return $nonref->dnafrag_strand > 0 ? 'Forward' : 'Reverse';
}

# calculate on-screen region
sub calculate_region {
  my ($self,$gab) = @_;

  my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
  my $chr = $gab->reference_slice->seq_region_name;
  my $hseqname = $nonref->dnafrag->name;
  my $ori = $self->get_ori($gab);

  # Start and end of image
  my $cstart    = $gab->reference_slice->start;
  my $cend      = $gab->reference_slice->end;
  
  # Start and end of ref block (inc off-screen)
  my $start2    = $cstart+$gab->reference_slice_start-1;
  my $end2      = $cstart+$gab->reference_slice_end-1;
  
  # Start and end of nonref block (inc off-screen)
  my $start_nr  = $nonref->dnafrag_start;
  my $end_nr    = $nonref->dnafrag_end;
  
  # Drawn ref block start/end (ie only on-screen bit)
  my $dstart    = max($start2,$cstart);
  my $dend      = min($end2,$cend);
  
  # Drawn non-ref block start/end (ie only on-screen bit)
  my $dstart_nr = max($start_nr,$cstart);
  my $dend_nr   = min($end_nr,$cend);

  my $r  = sprintf("%s:%d-%d",$chr,$start2,$end2);
  my $r1 = sprintf("%s:%d-%d",$hseqname,$start_nr,$end_nr);
  
  return ($dstart-$cstart,$dend-$dstart+1,$ori,$r,$r1);
}

# Calculates y position from bumping considerations
sub calculate_ypos {
  my ($self,$ga_s) = @_;
  
  my $container      = $self->{'container'};
  my $pix_per_bp     = $self->scalex;
  my $length         = $container->length;
  my $strand      = $self->strand;
  my $depth          = $self->depth || 6;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $ga_first = $ga_s->[0];
  my $ga_last = $ga_s->[-1];
  my $ga_first_start = $ga_first->reference_slice_start;
  my $ga_last_end    = $ga_last->reference_slice_end;
  my $bump_start = (($ga_first_start < 1 ? 1 : $ga_first_start) * $pix_per_bp) - 1; # start in pixels
  my $bump_end   = ($ga_last_end > $length ? $length : $ga_last_end) * $pix_per_bp; # end in pixels
  my $row        = $self->bump_row(int $bump_start, int $bump_end);
  my $yrow = $row;
  # In images, "outside" is usually considered least important.
  # Not for align images, so flip it.
  $yrow = $depth-$row if $self->my_config('flip_vertical');
  my $y_pos = -($yrow) * int(1.5 * $h) * $strand;
  return undef if $row > $depth;
  return $y_pos;
}

# Draws either a CIGAR or non-cigar line of boxes, as appropriate.
sub draw_boxes {
  my ($self,$net_composite,$ga_s,$y_pos,$zm) = @_;
 
  my $feature_key    = lc $self->my_config('type');
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2 || $debug_force_cigar;
  my $container      = $self->{'container'};
  my $length         = $container->length;

  my $params = {
    feature_colour => $self->my_colour($feature_key),
    delete_colour  => 'black',
    y              => $y_pos,
    h              => $self->get_parameter('opt_halfheight') ? 4 : 8,
    link           => $self->get_parameter('compara') ? $self->my_config('join') : 0,
  };
  my (%joins);

  foreach my $gab (@$ga_s) {
    my @tag = (
      #Need to use original_dbID if GenomicAlign has been restricted
      $gab->reference_genomic_align->dbID() || $gab->reference_genomic_align->original_dbID,
      $gab->get_all_non_reference_genomic_aligns->[0]->dbID() || $gab->get_all_non_reference_genomic_aligns->[0]->original_dbID
    );

    @tag = reverse @tag if $self->strand == 1; # Flip on bottom of link
    my $args = {
      drawx => $self->should_draw_cross($gab),
      tag => \@tag,
    };
    if ($draw_cigar) {
      my $composite = $net_composite;
      unless(defined $composite) {
        my ($x,$width,$ori,$r,$r1) = $self->calculate_region($gab);
        $composite = $self->draw_containing_box([$gab],0);
        $self->add_zmenu($zm,$composite,$ori,$r,$r1);
        $self->push($composite);
      }
      $self->draw_cigar($params,$args,$composite,$gab,\%joins);
    } else {
      $self->draw_non_cigar($params,$args,$gab,\%joins,$zm);
    }
  }
  $self->draw_joins(\%joins);
}

# Things that stay constant for zmenu params (at least within a net)
sub prepare_zmenus {
  my ($self,$gabs,$net) = @_;

  my $url_species =
    ucfirst $gabs->[0]->reference_genomic_align->genome_db->name;
  my ($n0,$n1);
  ($n0,$n1) = $self->make_net_urls($gabs) if $net;
  my $other_species  = $self->my_config('species');
  my $mlss_id        = $self->my_config('method_link_species_set_id');
  return {
    type    => 'Location',
    action  => 'PairwiseAlignment',
    species => $url_species,
    n0      => $n0,
    n1      => $n1,
    s1      => $other_species,
    method  => $self->my_config('type'),
    align   => $mlss_id, #use only the mlss_id here and create the rest of the link in the ZMenu/PairwiseAlignment module because the region and net values need to be set differently
  };
}

# Add ZMenu to box
sub add_zmenu {
  my ($self,$zm,$box,$ori,$r,$r1) = @_;

  $box->href($self->_url({ %$zm, r => $r, r1 => $r1, orient => $ori}));
}

sub empty_track {
  my ($self) = @_;
  unless($self->{'config'}->get_option('opt_empty_tracks')==0) {
    my $name = $self->my_config('name');
    $self->errorTrack("No $name features in this region");
  }
}

# Should we be drawing track at all, maybe this is the wrong strand?
sub this_strand {
  my ($self) = @_;

  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');
  return 0 if $strand_flag eq 'r' && $strand != -1;
  return 0 if $strand_flag eq 'f' && $strand !=  1;
  return 1;
}

sub render_normal {
  my $self = shift;

  return $self->render_compact if $debug_force_compact;
  return $self->render_text if $self->{'text_export'} or $debug_force_text;
  return unless $self->this_strand(); 
  
  $self->_init_bump(undef, $self->depth || 6); # initialize bumping

  my @slices = split(' ',$self->my_config('slice_summary')||'');
  my $features = $self->features;
  unless(@$features) {
    $self->empty_track();
    return;
  }
  foreach my $ga_s ($self->build_features_into_sorted_groups($features,\@slices)) {
    next unless @$ga_s;
    my $y_pos = $self->calculate_ypos($ga_s);
    next unless defined $y_pos;
    my $net_composite = $self->draw_containing_box($ga_s,$y_pos);
    my $zm = $self->prepare_zmenus($ga_s,1);
    $self->draw_boxes($net_composite,$ga_s,$y_pos,$zm);
    $self->add_zmenu($zm,$net_composite,$self->get_ori($ga_s->[0]));
    $self->push($net_composite);
  }
}

sub render_compact {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  return unless $self->this_strand(); 
  $self->_init_bump(undef, $self->depth);  # initialize bumping 

  my @features = @{$self->get_compact_features($self->features||[])};
  unless(@features) {
    $self->empty_track();
    return;
  }
  $self->draw_boxes(undef,\@features,0,$self->prepare_zmenus(\@features,0));
}

sub features {
  my $self = shift;

  my $compara = $self->dbadaptor('multi',$self->my_config('db'));
  my $mlss_a = $compara->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_id = $self->my_config('method_link_species_set_id');
  my $mlss = $mlss_a->fetch_by_dbID($mlss_id);
  my $gab_a = $compara->get_GenomicAlignBlockAdaptor;
  my $cont = $self->{'container'};

  #Get restricted blocks
  my $gab_s = $gab_a->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss,$cont, undef, undef, 'restrict');
  # Filter to target non-refs, if specified
  my $target = $self->my_config('target');
  if($target) {
    $gab_s = [
      grep {
        $_->get_all_non_reference_genomic_aligns->[0]->dnafrag->name eq
          $target
      } @{$gab_s || []}
    ];
  }
  return $gab_s;
}

sub render_text {
  my $self = shift;
 
  return unless $self->this_strand();

  # We don't have "features" so can't use the supertype class. Creating
  # fake features doesn't really help simplify things. May as well do it
  # here. We should probably alter the superclass method to accept gab's.
  my $species = $self->my_config('species');
  my $type    = $self->my_config('type');
  my $db      = $self->my_config('db');

  my @header = qw(seqname source feature start end score stand frame);
  push @header,$species;
  my $out;
  $out = join("\t",@header)."\r\n" unless $type eq 'gff';
  foreach my $gab (@{$self->features}) {
    my $ref = $gab->reference_genomic_align;
    my $nonref = $gab->get_all_non_reference_genomic_aligns->[0];
    my @row = ( 
      $ref->dnafrag->name,
      'Ensembl', 
      $type,
      $ref->dnafrag_start,
      $ref->dnafrag_end,
      $gab->score,'.','.',
      sprintf("%s:%d-%d",$nonref->dnafrag->name,
              $nonref->dnafrag_start,
              $nonref->dnafrag_end)
    );
    if($type eq 'gff') {
      @row = map { "$header[$_]=$row[$_]" } (0..$#header);
      $out .= join("; ",@row)."\r\n";
    } else {
      $out .= join("\t",@row)."\r\n";
    }
  } 
  return $out; 
}

1;
