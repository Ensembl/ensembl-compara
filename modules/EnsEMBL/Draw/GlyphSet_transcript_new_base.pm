=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet_transcript_new_base;

### Parent module for various glyphsets that draw transcripts
### (styles include exons as blocks, joined by angled lines across introns)

use strict;

use List::Util qw(min max);
use List::MoreUtils qw(natatime);

use base qw(EnsEMBL::Draw::GlyphSet);

sub draw_collapsed_exon {
  my ($self,$composite2,$length,$gene,$exon) = @_;

  my $s = max($exon->{'start'},1);
  my $e = min($exon->{'end'},$length);
  
  $composite2->push($self->Rect({
    x         => $s - 1,
    y         => 0,
    width     => $e - $s + 1,
    height    => 8,
    colour    => $gene->{'colour'},
    absolutey => 1
  }));
}

sub draw_expanded_exon {
  my ($self,$composite2,$t,$h,$e,$length) = @_;
  
  my $non_coding_height = ($self->my_config('non_coding_scale')||0.75) * $h;
  my $non_coding_start  = ($h - $non_coding_height) / 2;
  my $colour    = $self->my_colour($t->{'colour_key'});
  my $box_start = max($e->{'start'}, 1);
  my $box_end   = min($e->{'end'}, $length);
  foreach my $type (@{$e->{'types'}}) {
    if ($type eq 'border') {
      $composite2->push($self->Rect({
        x            => $box_start - 1 ,
        y            => $non_coding_start,
        width        => $box_end - $box_start + 1,
        height       => $non_coding_height,
        bordercolour => $colour,
        absolutey    => 1,
      }));
    } elsif ($type eq 'fill') {
      my $fill_start = max($e->{'start'} + $e->{'coding_start'}, 1);
      my $fill_end   = min($e->{'end'}   - $e->{'coding_end'}, $length);
      
      if ($fill_end >= $fill_start) {
        $composite2->push($self->Rect({
          x         => $fill_start - 1,
          y         => 0,
          width     => $fill_end - $fill_start + 1,
          height    => $h,
          colour    => $colour,
          absolutey => 1,
        }));
      }
    } elsif($type eq 'missing') {
      $composite2->push($self->Line({
        x         => $box_start - 1,
        y         => int($h/2),
        width     => $box_end-$box_start + 1,
        height    => 0,
        absolutey => 1,
        colour    => 'green',
        dotted    => 1
      }));
    }
  }
}

sub draw_collapsed_gene_base {
  my ($self,$composite2,$length,$gene) = @_;    

  my $start = $gene->{'start'} < 1 ? 1 : $gene->{'start'};
  my $end   = $gene->{'end'} > $length ? $length : $gene->{'end'};
  
  $composite2->push($self->Rect({
    x         => $start, 
    y         => 4,
    width     => $end - $start + 1,
    height    => 0.4, 
    colour    => $gene->{'colour'}, 
    absolutey => 1
  }));
}

sub draw_expanded_transcript {
  my ($self,$composite2,$t,$h,$length,$strand) = @_;

  foreach my $j (@{$t->{'joins'}||[]}) {
    $self->draw_join($composite2,$j);
  }
  foreach my $e (@{$t->{'exons'}||[]}) {
    $self->draw_expanded_exon($composite2,$t,$h,$e,$length);
  }
  $self->draw_introns($composite2,$t,$h,$length,$strand);
}

sub draw_expanded_transcripts {
  my ($self,$tdraw,$length,$strand,$draw_labels,$target) = @_;

  return unless @$tdraw;
  my $target = $self->get_parameter('single_Transcript');
  my $h = $self->my_config('height') || ($target ? 30 : 8);
  my $strand_flag = $self->my_config('strand');
  my %used_colours;
  foreach my $td (@$tdraw) { 
    next if $strand != $td->{'strand'} and $strand_flag eq 'b';
    my $composite = $self->Composite({
      y      => 0,
      height => $h,
      title  => $td->{'title'},
      href   => $td->{'href'},
      class  => 'group',
    });

    $self->use_legend(\%used_colours,$td->{'colour_key'});
    
    $self->draw_expanded_transcript($composite,$td,$h,$length,$strand);
    
    my $bump_height  = 1.6 * $h;
    $bump_height += $self->add_label_new($composite,$td) if $draw_labels;
    $composite->y($composite->y - $strand * $bump_height * $td->{'_bump'});

    $composite->colour($td->{'highlight'}) if $td->{'highlight'};
    if ($target) {
      # check the strand of one of the transcript's exons
      my $estrand = ((($td->{'exons'}||[])->[0])||{})->{'strand'};
      my $colour = $td->{'colour'};
      $self->draw_grey_arrow($estrand,$length,$h,$colour);
    }
    $self->push($composite);
  }
  my $type = $self->type;
  my %legend_old = @{$self->{'legend'}{'gene_legend'}{$type}{'legend'}||[]};
  $used_colours{$_} = $legend_old{$_} for keys %legend_old;
  my @legend = %used_colours;
  $self->{'legend'}{'gene_legend'}->{$type} = {
    priority => $self->_pos,
    legend   => \@legend
  };
}
    
sub draw_collapsed_genes {
  my ($self,$length,$labels,$strand,$genes) = @_;

  my $strand_flag      = $self->my_config('strand');
  return unless @$genes;
  my %used_colours;
  foreach my $g (@$genes) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    $self->use_legend(\%used_colours,$g->{'colour_key'});
    my $composite = $self->Composite({
      y      => 0,
      height => 8,
      title  => $g->{'title'},
      href   => $g->{'href'},
    });
      
    $self->draw_collapsed_gene_base($composite,$length,$g);
    foreach my $e (@{$g->{'exons'}}) {
      $self->draw_collapsed_exon($composite,$length,$g,$e);
    }
    foreach my $j (@{$g->{'joins'}}) {
      $self->draw_join($composite,$j);
    }
  
    # shift the composite container by however much we're bumped
    my $bump_height  = 10;
    $bump_height += $self->add_label_new($composite,$g) if $labels;

    # bump
    $composite->y($composite->y - $strand * $bump_height * $g->{'_bump'});
    $composite->colour($g->{'highlights'}) if $g->{'highlights'};
    $self->push($composite);
  }
  my $type = $self->my_config('name');
  my %legend_old = @{$self->{'legend'}{'gene_legend'}{$type}{'legend'} || []};
  $used_colours{$_} = $legend_old{$_} for keys %legend_old;
  my @legend = %used_colours;
  $self->{'legend'}{'gene_legend'}{$type} = {
    priority => $self->_pos,
    legend   => \@legend
  };
}
    
sub draw_rect_gene {
  my ($self,$g) = @_;

  my $pix_per_bp = $self->scalex;
  my $rect = $self->Rect({
    x => $g->{'start'}-1,
    y => 0,
    width => $g->{'end'}-$g->{'start'}+1,
    height => 4,
    colour => $g->{'colour'},
    absolutey => 1,
    href => $g->{'href'},
    title => $g->{'title'},
  });
  $self->push($rect);
  if($g->{'highlight'}) {
    $self->unshift($self->Rect({
      x         => ($g->{'start'}-1) - 1/$pix_per_bp,
      y         => -1,
      width     => ($g->{'end'}-$g->{'start'}+1) + 2/$pix_per_bp,
      height    => 6,
      colour    => $g->{'highlight'},
      absolutey => 1
    }));
  }
  $self->draw_join($rect,$_) for(@{$g->{'joins'}});
  return $rect;
}
      
sub draw_introns {
  my ($self,$composite2,$t,$h,$length,$strand) = @_;

  my $colour = $self->my_colour($t->{'colour_key'});
  my @introns = @{$t->{'exons'}};
  # add off-screen endpoints, duplicate, pair up
  unshift @introns,{end => 0,dotted => 1} if $t->{'exon_stageleft'};
  push @introns,{start => $length, dotted => 1} if $t->{'exon_stageright'};
  @introns = map { ($_,$_) } @introns;
  my $in_it = natatime(2,@introns[1..$#introns-1]);
  while(my @pair = $in_it->()) {
    my $intron_start = max($pair[0]->{'end'}+1,0);
    my $intron_end = min($pair[1]->{'start'}-1,$length);
    my $dotted = ($pair[0]->{'dotted'} || $pair[1]->{'dotted'});
    if($dotted) {
      $composite2->push($self->Line({
        x         => $intron_start - 1,
        y         => int($h/2),
        width     => $intron_end - $intron_start + 1,
        height    => 0,
        colour    => $colour,
        absolutey => 1,
        strand    => $strand,
        dotted => 1,
      }));
    } else {
      $composite2->push($self->Intron({
        x         => $intron_start - 1,
        y         => 0,
        width     => $intron_end - $intron_start + 1,
        height    => $h,
        colour    => $colour,
        absolutey => 1,
        strand    => $strand,
      }));
    }
  }
}

# Probably not used anywhere any more?
sub draw_grey_arrow {
  my ($self,$strand,$length,$h,$colour) = @_;

  my $pix_per_bp = $self->scalex;
  my ($ay,$ao,$am); 
  if ($strand) {
    ($ay,$ao,$am) = (-4,$length,-1);
  } else {
    ($ay,$ao,$am) = ($h+4,0,1);
  }
  $self->push($self->Line({
    x         => 0,
    y         => $ay,
    width     => $length,
    height    => 0,
    absolutey => 1,
    colour    => $colour
  }));
  $self->push($self->Poly({
    absolutey => 1,
    colour    => $colour,
    points    => [ 
      $ao+$am*4/$pix_per_bp, $ay-2*$am,
      $ao, $ay,
      $ao+$am*4/$pix_per_bp, $ay+2*$am,
    ]
  }));
}
  
sub draw_rect_genes {
  my ($self,$ggdraw,$length,$draw_labels,$strand) = @_;

  my $strand_flag = $self->my_config('strand');
  my $pix_per_bp = $self->scalex;
  my $rects_rows = $self->mr_bump($ggdraw,0,$length);
  foreach my $g (@$ggdraw) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    my $rect = $self->draw_rect_gene($g);
    $rect->y($rect->y + (6*$g->{'_bump'}));
  } 
  if($draw_labels) {
    $_->{'_lwidth'} += 8/$pix_per_bp for(@$ggdraw);
    $self->mr_bump($ggdraw,2,$length); # Try again

    foreach my $g (@$ggdraw) {
      next if $strand != $g->{'strand'} and $strand_flag eq 'b';
      my $composite = $self->Composite({
        y => 0,
        x => $g->{'_bstart'},
        width => $g->{'_lwidth'},
        absolutey => 1,
        colour => $g->{'highlight'},
      });
      $self->add_label_new($composite,$g);
      $composite->x($composite->x+8/$pix_per_bp);
      $self->draw_bookend($composite,$g);
      $composite->y($g->{'_lheight'}*$g->{'_bump'}+($rects_rows*6));
      $self->push($composite);
    }
  }
  my %legend_old = @{$self->{'legend'}{'gene_legend'}{$self->type}{'legend'}||[]};
  my %used_colours;
  $used_colours{$_} = $legend_old{$_} for keys %legend_old;

  $self->use_legend(\%used_colours,$_->{'colkey'}) for @$ggdraw;

  my @legend = %used_colours;
  
  $self->{'legend'}{'gene_legend'}{$self->type} = {
    priority => $self->_pos,
    legend   => \@legend
  };
}

sub draw_join {
  my ($self,$target,$j) = @_;
  
  $self->join_tag($target,$j->{'key'},0.5,0.5,$j->{'colour'},'line',1000);
  $self->{'legend'}{'gene_legend'}{'joins'}{'priority'} ||= 1000;
  if($j->{'legend'}) {
    $self->{'legend'}{'gene_legend'}{'joins'}{'legend'}{$j->{'legend'}} =
      $j->{'colour'};
  }
}

sub draw_bookend {
  my ($self,$composite,$g) = @_;

  my $pix_per_bp = $self->scalex;
  $composite->push(
    $self->Rect({
      x         => $g->{'_bstart'}+8,
      y         => 4,
      width     => 0,
      height    => 4,
      colour    => $g->{'colour'},
      absolutey => 1
    }),
    $self->Rect({
      x         => $g->{'_bstart'}+8,
      y         => 8,
      width     => 3/$pix_per_bp,
      height    => 0,
      colour    => $g->{'colour'},
      absolutey => 1
    })
  );
}

1;
