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

package EnsEMBL::Draw::Output::JoinedBlocks;

### Simple module to render one or more features as solid blocks with 
### straight joins where available (based on GlyphSet::_alignment)

use strict;

use parent qw(EnsEMBL::Draw::Output::Blocks);

sub render {
  my ($self, $options) = @_;

  ## Work out some sizing and scaling parameters
  my $height    = $options->{'height'} || $self->track_config('height') || $self->default_height;
  my $width     = $self->{'container'}->length;
  my $depth     = 1;
  my $label_h   = 0;
  my $y_pos     = 0;
  my $y_offset  = 0;
  my $row       = 0;
  my $gap       = $height < 2 ? 1 : 2;
  my ($fontname, $fontsize);
 
  my $pix_per_bp    = $self->scalex;
  my $cigar_regexp  = $pix_per_bp > 0.1 ? '\dI' : $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI';

  my $strand    = $self->strand;
  my @features  = @{$self->{'data'}||[]}; 

  ## Also keep track of what's being drawn
  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $track_height    = 0;
  my $on_screen       = 0;
  my $off_screen      = 0;
  my $on_other_strand = 0;

  ## Start position
  my ($first_feature_start) = $self->convert_to_local($features[0]->{'start'});
  my $strand_y = $self->track_config('strandbump') && $features[0]->{'strand'} == -1 ? $height : 0;
  my $position = {
                    x       => $first_feature_start > 1 ? $first_feature_start - 1 : 0,
                    y       => 0,
                    width   => 0,
                    height  => $height,
                  };

  # +1 below cos we render eg a rectangle from (100, 100) of height
  # and width 10 as (100,100)-(110,110), ie actually 11x11. -- ds23
  $y_pos = $y_offset - $row * int($height + 1 + $gap * $label_h) * $strand;

  my $composite;

  if (scalar @features == 1 and !$depth) { #and $config->{'simpleblock_optimise'}) {
    $composite = $self;
  } 
  else {
    $composite = $self->Composite({
                                    %$position,
                                    href  => '',
                                    class => 'group',
                                  });

  }

  foreach my $f (@features) {
    my ($start, $end) = $self->convert_to_local($f->{'start'}, $f->{'end'});

    my $start   = List::Util::max($start, 1);
    my $end     = List::Util::min($end, $width);

    my $feature_colour  = $f->{'colour'} || $self->track_config('colour');
    my $label_colour    = $feature_colour;

    my $cigar   = $f->{'cigar_string'};

    if ($cigar && ($self->want_cigar || $cigar =~ /$cigar_regexp/)) {
      ## Space
      $composite->push($self->Space({
            x         => $start - 1,
            y         => 0,
            width     => $end - $start + 1,
            height    => $height,
            absolutey => 1,
      }));

      $self->draw_cigar_feature({
            composite      => $composite,
            feature        => $f,
            height         => $height,
            feature_colour => $feature_colour,
            label_colour   => $label_colour,
            delete_colour  => 'black',
            scalex         => $pix_per_bp,
            y              => $strand_y,
      });
    } 
    else {
      ## Simple rectangle
      $composite->push($self->Rect({
            x            => $start - 1,
            y            => $strand_y,
            width        => $end - $start + 1,
            height       => $height,
            colour       => $feature_colour,
            label_colour => $label_colour,
            absolutey    => 1,
      }));
    }
    $features_drawn = 1;
  }

=pod
  if ($composite ne $self) {
    if ($h > 1) {
      $composite->bordercolour($feature_colour) if $join;
    } else {
      $composite->unshift($self->Rect({
            x         => $composite->{'x'},
            y         => $composite->{'y'},
            width     => $composite->{'width'},
            height    => $h,
            colour    => $join_colour,
            absolutey => 1
      }));
    }

    $composite->y($composite->y + $y_pos);
    $self->push($composite);
  }

  if ($self->{'show_labels'}) {
    my $start = $self->{'container'}->start;
    ## text label
    $self->push($self->Text({
          font      => $fontname,
          colour    => $label_colour,
          height    => $fontsize,
          ptsize    => $fontsize,
          text      => $self->feature_label($feat[0][2], $db_name),
          title     => $self->feature_title($feat[0][2], $db_name),
          halign    => 'left',
          valign    => 'center',
          x         => $position->{'x'},
          y         => $position->{'y'} + $h + 2,
          width     => $position->{'x'} + ($bump_end - $bump_start) / $pix_per_bp,
          height    => $label_h,
          absolutey => 1,
          href      => $self->href($feat[0][2],{ fake_click_start => $start + $feat_from, fake_click_end => $start + $feat_to }),
          class     => 'group', # for click_start/end on labels
    }));
  }

  if ($self->{'config'}->get_option('opt_highlight_feature') != 0 && exists $highlights{$i}) {
    ## Add highlight rectangle
    $self->unshift($self->Rect({
          x         => $position->{'x'} - 1 / $pix_per_bp,
          y         => $position->{'y'} - 1,
          width     => $position->{'width'} + 2 / $pix_per_bp,
          height    => $h + 2,
          colour    => 'highlight1',
          absolutey => 1,
    }));
  }
  $track_height = $position->{'y'} if $position->{'y'} > $track_height;
  $y_offset -= $strand * ($self->_max_bump_row * ($h + $gap + $label_h) + 6);

  if ($off_screen) {
    my $total = $on_screen + $off_screen;
    my $default = $depth == $default_depth ? 'by default' : '';
    my $text = "Showing $on_screen of $total features, due to track being limited to $depth rows $default - click to show more";
    my $y = $track_height + $fontsize * 2 + 10;
    my $href = $self->_url({'action' => 'ExpandTrack', 'goto' => $self->{'config'}->hub->action, 'count' => $total, 'default' => $default_depth});
    ## Print message
    $self->push($self->Text({
          font      => $fontname,
          colour    => 'black',
          height    => $fontsize,
          width     => $self->{'container'}->length,
          ptsize    => $fontsize,
          text      => $text,
          halign    => 'left',
          valign    => 'center',
          x         => 0,
          y         => $y,
          absolutey => 1,
          href      => $href,
        }));
    ## Space
    $self->push($self->Space({
            x         => 0,
            y         => $y + 5,
            width     => 100,
            height    => 8,
            absolutey => 1,
    }));
  }
=cut

  $self->_render_hidden_bgd($height) if $features_drawn && $self->my_config('addhiddenbgd') && $self->can('href_bgd') && !$depth;

  $self->errorTrack(sprintf q{No features from '%s' on this strand}, $self->my_config('name')) unless $features_drawn || $on_other_strand || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  $self->errorTrack(sprintf(q{%s features from '%s' omitted}, $features_bumped, $self->my_config('name')), undef, $y_offset) if $self->get_parameter('opt_show_bumped') && $features_bumped;
}

sub want_cigar { 
  my $self = shift;
  return $self->my_config('force_cigar') eq 'yes' || $self->scalex > 0.2; 
}

1;

