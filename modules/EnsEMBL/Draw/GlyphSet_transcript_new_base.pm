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

package EnsEMBL::Draw::GlyphSet_transcript_new_base;

use strict;

use List::Util qw(min max);
use List::MoreUtils qw(natatime);

use EnsEMBL::Draw::Style::Feature::Transcript;

use base qw(EnsEMBL::Draw::GlyphSet);

sub minmax { return max(min($_[0],$_[2]),$_[1]); }

# In "collapsed" style, a single bead-string is drawn. This is fat
# wherever any consituent transcript has an exon at that position.
# It is used by render_collapsed and render_alignslice_collapsed.
# It is accessed via draw_collapsed_genes.
#
# In "expanded" style, each transcript is simply drawn separately,
# with full exon structure and labels for each. It is used by
# render_transcripts and render_alignslice_transcripts. It is accessed
# via draw_expanded_transcripts.
#
# In "rect" style, the region occupied by a gene is simply drawn as a
# rectangle. It is used in render_genes. It is accessed via
# draw_rect_genes.

# The data to be passed in must be in the form of an array of hashes
# representing a set of genes or, in expanded style, transcripts. Whether
# genes or transcripts are the objects represented, they must contain the
# following keys.
#
#   colour_key =>  key of main colour to use for object
#   start, end =>  complete extent of object in bp. Need not be truncated
#                  to edge of screen: we'll do that.
#   strand =>      the strand it lies on
#   title, href => for the respective composites, if applicable
#   label =>       text of label
#   highlight =>   a colour in which to highlight object, if needed
#   joins => [{    join lines used to join homologous genes, etc
#     colour => colour of join
#     key =>    tag key
#     legend => text for legend
#   }]
#   exons => [{    draw internal exons
#     start,end =>               locations of exon
#     strand =>                  strand of exon (needed for alignslice)
#     coding_start,coding_end => internal offset to coding part of exon
#   }]




sub draw_collapsed_genes {
  my ($self, $length, $labels, $strand, $genes) = @_;
  return unless @$genes;

  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('collapsed', 1);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('show_labels', 1) if $labels;
  $self->{'my_config'}->set('moat', 2);

  $self->_set_bump_strand($length, $strand);

  ## Filter by strand
  my $stranded_genes = [];
  my $strand_flag = $self->my_config('strand');
  foreach my $g (@$genes) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    $g->{'colour'} = $self->my_colour($g->{'colour_key'});
    $g->{'href'} .= ';display=collapsed';
    $self->_create_exon_structure($g);
    push @$stranded_genes, $g;
     $self->_add_connection_to_legend($g);
  }
  my $data = [{'features' => $stranded_genes}];

  my %config    = %{$self->track_style_config};
  my $style_class = 'EnsEMBL::Draw::Style::Feature::Transcript';
  my $style = $style_class->new(\%config, $data);
  $self->push($style->create_glyphs);
  ## Add old-style 'tags' between genes or transcripts
  $self->add_connections($style);

  $self->_make_legend($genes,$self->my_config('name'));

  ## Everything went OK, so no error to return
  return 0;
}


sub draw_expanded_transcripts {
  my ($self, $length, $labels, $strand, $transcripts) = @_;

  return unless @{$transcripts||{}};

  my $target = $self->get_parameter('single_Transcript');
  my $h = $self->my_config('height') || ($target ? 30 : 8);
  $self->{'my_config'}->set('height', $h);
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('vspacing', 10);
  if ($labels) {
    $self->{'my_config'}->set('show_labels', 1);
  }

  $self->_set_bump_strand($length, $strand);

  ## Filter by strand
  my $stranded = [];
  my $strand_flag = $self->my_config('strand'); 
  foreach my $t (@$transcripts) {
    next if $strand != $t->{'strand'} and $strand_flag eq 'b';
    $t->{'colour'} = $self->my_colour($t->{'colour_key'});
    $self->_create_exon_structure($t);
    push @$stranded, $t;
    $self->_add_connection_to_legend($t);
  }
  my $data = [{'features' => $stranded}];

  my %config    = %{$self->track_style_config};
  my $style_class = 'EnsEMBL::Draw::Style::Feature::Transcript';
  my $style = $style_class->new(\%config, $data);
  $self->push($style->create_glyphs);
  ## Add old-style 'tags' between genes or transcripts
  $self->add_connections($style);

  $self->_make_legend($transcripts, $self->my_config('name'));

  ## Everything went OK, so no error to return
  return 0;
}

sub draw_rect_genes {
  my ($self, $genes, $length, $labels, $strand) = @_;
  #warn ">>> DRAWING RECT GENES FOR ".$self->{'config'};

  return unless @$genes;

  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('height', 4);
  $self->{'my_config'}->set('show_labels', 1) if $labels;

  $self->_set_bump_strand($length, $strand);

  ## Filter by strand
  my $stranded_genes = [];
  my $strand_flag = $self->my_config('strand');
  foreach my $g (@$genes) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    $g->{'colour'} = $self->my_colour($g->{'colour_key'});
    push @$stranded_genes, $g;
    $self->_add_connection_to_legend($g);
  }
  my $data = [{'features' => $stranded_genes}];

  my %config    = %{$self->track_style_config};
  my $style_class = 'EnsEMBL::Draw::Style::Feature';
  my $style = $style_class->new(\%config, $data);
  $self->push($style->create_glyphs);
  ## Add old-style 'tags' between genes or transcripts
  $self->add_connections($style);

  $self->_make_legend($genes,$self->my_config('name'));

  ## Everything went OK, so no error to return
  return 0;
}


##########################################################
# UTILITIES USED IN MULTIPLE STYLES                      #
##########################################################

sub _set_bump_strand {
  my ($self, $length, $strand) = @_;

  my $strand_flag = $self->my_config('strand');
  my $bstrand = ($length, $strand_flag eq 'b') ? $strand : undef;
  $self->{'my_config'}->set('bstrand', $bstrand);
}


sub _create_exon_structure {
  my ($self, $f) = @_;
  my $structure = [];
  my $slice_length = $self->{'config'}->container_width;

  foreach my $e (@{$f->{'exons'}}) {
    next unless ($e->{'start'} || $e->{'end'}); 
    my $exon = {'start' => $e->{'start'}, 'end' => $e->{'end'}};

    if (defined $e->{'coding_start'} && defined $e->{'coding_end'}) {
      ## Turn API coordinates into something that makes sense in drawing terms 
      if ($e->{'coding_start'} < 1) {
        $e->{'coding_start'} = $e->{'start'};
      }
      if ($e->{'coding_end'} < 1) {
        $e->{'coding_end'} = $e->{'end'};
      }

      if ($e->{'coding_start'} != $e->{'start'}) {
        $e->{'coding_start'}  += $e->{'start'};
      }
      if ($e->{'coding_end'} != $e->{'end'}) {
        $e->{'coding_end'}  = $e->{'end'} - $e->{'coding_end'};
      }

      ## Use direction of drawing, not direction of transcript
      my ($coding_start, $coding_end) = ($e->{'coding_start'}, $e->{'coding_end'});
      if (($coding_end - $coding_start) < 0 || ($coding_end - $coding_start) > $slice_length) {
        $exon->{'non_coding'} = 1;
      }
      else {
        if ($coding_start > $e->{'start'}) {
          $exon->{'utr_5'} = $coding_start;
        }
        if ($coding_end < $e->{'end'}) {
          $exon->{'utr_3'} = $coding_end - 1;
        }
      }
    }
    else {
      $exon->{'non_coding'} = 1;
    }
    push @$structure, $exon;
  }
  $f->{'structure'} = $structure;
  return 1;
}

sub _add_connection_to_legend {
  my ($self, $feature) = @_;

  foreach (@{$feature->{'connections'}||[]}) {
    ## Add to legend
    if ($_->{'legend'}) {
      $self->{'legend'}{'gene_legend'}{'connections'}{'legend'}{$_->{'legend'}} = $_->{'colour'};
    }
  }
}

# legends 

sub _use_legend {
  my ($self,$used_colours,$colour_key) = @_;

  my $colour = 'orange';
  my $label = 'Other';
  my $section = 'none';
  if($colour_key) {
    $colour     = $self->my_colour($colour_key);
    if($colour) {
      $label      = $self->my_colour($colour_key, 'text');
      $section    = $self->my_colour($colour_key,'section') || 'none';
    }
  }
  my $section_name = $self->my_colour("section_$section",'text') ||
                      $self->my_colour("section_none",'text');
  my $section_prio = $self->my_colour("section_$section",'prio') ||
                      $self->my_colour("section_none",'prio');
  if($section) {
    $section = {
      key => $section,
      name => $section_name,
      priority => $section_prio,
    };
  }
  $used_colours->{$label} = [$colour,$section];

  if ($self->{'legend'}{'gene_legend'}{'connections'}) {
    $self->{'legend'}{'gene_legend'}{'connections'}{'priority'} ||= 1000;
  }
}

sub _make_legend {
  my ($self,$objs,$type) = @_;

  my %used_colours;
  $self->_use_legend(\%used_colours,$_->{'colour_key'}) for(@$objs);
  my %legend_old = @{$self->{'legend'}{'gene_legend'}{$type}{'legend'}||[]};
  $used_colours{$_} = $legend_old{$_} for keys %legend_old;
  my @legend = %used_colours;
  $self->{'legend'}{'gene_legend'}{$type} = {
    priority => $self->_pos,
    legend   => \@legend
  };
}
1;
