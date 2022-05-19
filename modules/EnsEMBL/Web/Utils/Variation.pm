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

package EnsEMBL::Web::Utils::Variation;

## Handy methods for formatting variation content

use EnsEMBL::Web::Utils::FormatText qw(coltab);

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(vep_icon render_sift_polyphen render_consequence_type render_p_value render_var_coverage predictions_classes classify_sift_polyphen classify_score_prediction display_items_list);


sub vep_icon {
  my ($hub, $inner_html) = @_;
  return '' unless $hub->species_defs->ENSEMBL_VEP_ENABLED;

  $inner_html   ||= 'Test your own variants with the <span>Variant Effect Predictor</span>';
  my $vep_link    = $hub->url({'__clear' => 1, qw(type Tools action VEP)});

  return qq(<a class="vep-icon" href="$vep_link">$inner_html</a>);
}


sub render_sift_polyphen {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($pred, $score) = @_;

  return '-' unless defined($pred) || defined($score);

  my %classes = (
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad',

    # slightly different format for SIFT low confidence states
    # depending on whether they come direct from the API
    # or via the VEP's no-whitespace processing
    'tolerated - low confidence'   => 'neutral',
    'deleterious - low confidence' => 'neutral',
    'tolerated low confidence'     => 'neutral',
    'deleterious low confidence'   => 'neutral',
  );

  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );

  my ($rank, $rank_str);

  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }

  return qq(
    <span class="hidden">$rank</span><span class="hidden export">$pred(</span><div align="center"><div title="$pred" class="_ht score score_$classes{$pred}">$rank_str</div></div><span class="hidden export">)</span>
  );
}

sub render_consequence_type {
  my $hub         = shift;
  my $tva         = shift;
  my $most_severe = shift;
  my $var_styles  = $hub->species_defs->colour('variation');
  my $colourmap   = $hub->colourmap;
  
  my $overlap_consequences = ($most_severe) ? [$tva->most_severe_OverlapConsequence] || [] : $tva->get_all_OverlapConsequences || [];

  # Sort by rank, with only one copy per consequence type
  my @consequences = sort {$a->rank <=> $b->rank} (values %{{map {$_->label => $_} @{$overlap_consequences}}});

  my $type = join ' ',
    map {
      my $hex = $var_styles->{lc $_->SO_term}
        ? $colourmap->hex_by_name(
            $var_styles->{lc $_->SO_term}->{'default'}
          ) 
        : $colourmap->hex_by_name($var_styles->{'default'}->{'default'});
      coltab($_->label, $hex, $_->description);
    } 
    @consequences;
  my $rank = @consequences ? $consequences[0]->rank : undef;
      
  return ($type) ? qq{<span class="hidden">$rank</span>$type} : '-';
} 

sub render_p_value {
  my $pval = shift;
  my $bold = shift;

  my $render = $pval;
  # Only display 2 decimals
  if ($pval =~ /^(\d\.\d+)e-0?(\d+)$/) {
    # Only display 2 decimals
    my $val = sprintf("%.2f", $1);
    # Superscript
    my $exp = "<sup>-$2</sup>";
    $exp = "<b>$exp</b>" if ($bold);

    $render = $val.'e'.$exp;
  }
  return $render;
}

# Rectangular glyph displaying the location and coverage of the variant
# on a given feature (transcript, protein, regulatory element, ...)
sub render_var_coverage {
  my ($f_s, $f_e, $v_s, $v_e, $color) = @_;

  my $render;
  my $var_render;

  $color ||= 'red';

  my $total_width = 100;
  my $left_width  = 0;
  my $right_width = 0;
  my $small_var   = 0;

  my $scale = $total_width / ($f_e - $f_s + 1);

  # middle part
  if ($v_s <= $f_e && $v_e >= $f_s) {
    my $s = (sort {$a <=> $b} ($v_s, $f_s))[-1];
    my $e = (sort {$a <=> $b} ($v_e, $f_e))[0];

    my $bp = ($e - $s) + 1;

    $right_width = sprintf("%.0f", $bp * $scale);
    if (($right_width <= 2) || $left_width == $total_width) {
      $right_width = 3;
      $small_var   = 1;
    }
    $var_render = sprintf(qq{<div class="var_trans_pos_sub" style="width:%ipx;background-color:%s"></div>}, $right_width, $color);
  }

  # left part
  if($v_s > $f_s) {
    $left_width = sprintf("%.0f", ($v_s - $f_s) * $scale);
    if ($left_width == $total_width)  {
      $left_width -= $right_width;
    }
    elsif (($left_width + $right_width) > $total_width) {
      $left_width = $total_width - $right_width;
    }
    elsif ($small_var && $left_width > 0) {
      $left_width--;
    }
    $left_width = 0 if ($left_width < 0);
    $render .= '<div class="var_trans_pos_sub" style="width:'.$left_width.'px"></div>';
  }
  $render .= $var_render if ($var_render);

  if ($render) {
    $render = qq{<div class="var_trans_pos">$render</div>};
  }

  return $render;
}

sub predictions_classes {
  return {
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad',

    'likely deleterious'     => 'bad',
    'likely benign'          => 'good',
    'likely disease causing' => 'bad',
    'damaging'               => 'bad',
    'high'                   => 'bad',
    'medium'                 => 'ok',
    'low'                    => 'good',
    'neutral'                => 'neutral',

    # slightly different format for SIFT low confidence states
    # depending on whether they come direct from the API
    # or via the VEP's no-whitespace processing
    'tolerated - low confidence'   => 'neutral',
    'deleterious - low confidence' => 'neutral',
    'tolerated low confidence'     => 'neutral',
    'deleterious low confidence'   => 'neutral',
  };
}

sub classify_sift_polyphen {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($pred, $score) = @_;

  return [undef,'-','','-'] unless defined($pred) || defined($score);

  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );

  my ($rank, $rank_str);

  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }

  # 0 -- a value to use for sorting
  # 1 -- a value to use for exporting
  # 2 -- a class to use for styling
  # 3 -- a value for display
  return [$rank,$pred,$rank_str];
}


sub classify_score_prediction {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($pred, $score) = @_;

  return [undef,'-','','-'] unless defined($pred) || defined($score);

  my %ranks = (
    '-'                 => 0,
    'likely deleterious' => 4,
    'likely benign' => 2,
    'likely disease causing' => 4,
    'tolerated' => 2,
    'damaging'   => 4,
    'high'    => 4,
    'medium'  => 3,
    'low'     => 2,
    'neutral' => 2,
  );

  my ($rank, $rank_str);

  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }
  return [$rank,$pred,$rank_str];
}

sub display_items_list {
  my ($div_id, $title, $label, $display_data, $export_data, $no_count_label, $specific_count) = @_;

  my $html = "";
  my @sorted_data = ($display_data->[0] =~ /^<a/i) ? @{$display_data} : sort { lc($a) cmp lc($b) } @{$display_data};
  my $count = scalar(@{$display_data});
  my $count_threshold = ($specific_count) ? $specific_count : 5;
  if ($count >= $count_threshold) {
    $html = sprintf(qq{
        <a title="Click to show the list of %s" rel="%s" href="#" class="toggle_link toggle closed _slide_toggle _no_export">%s</a>
        <div class="%s"><div class="toggleable" style="display:none"><span class="hidden export">%s</span><ul class="_no_export">%s</ul></div></div>
      },
      $title,
      $div_id,
      ($no_count_label) ? $label : "$count $label",
      $div_id,
      join(",", sort { lc($a) cmp lc($b) } @{$export_data}),
      '<li>'.join("</li><li>", @sorted_data).'</li>'
    );
  }
  else {
    $html = join(", ", @sorted_data);
  }

  return $html;
}


1;
