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

package EnsEMBL::Draw::GlyphSet::P_variation;

### Draws sequence variants on Transcript/ProteinSummary

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::variation);

sub render_labels {
  my $self = shift;

  #if ($self->{'container'}->length <= 1e4) {
    $self->{'my_config'}->set('show_labels', 1);
    $self->{'my_config'}->set('bumped', 'labels_alongside');
  #}
  return $self->_render;
}


sub get_data {
  my $self         = shift;
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;

  my $hub = $self->{'config'}{'hub'};

  if ($slice_length > $max_length * 1010) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
    return [];
  } else {
    my $snps       = $self->cache('image_snps');
    return [] unless $snps;

    my $is_somatic = $self->{'my_config'}->id =~ /somatic/ ? 1 : 0;

    my $features_list = [];
    foreach my $snp (@$snps) {
      my $vf = $snp->{'vf'};
      next if $vf->is_somatic != $is_somatic;

      my $colour = $self->get_colour($vf);
      my $feature_type;

      my $url_params = {
                        type   => 'Variation',
                        action => 'VariationProtein',
                        v      => $snp->{'snp_id'},
                        vf     => $snp->{'vdbid'},
                        };

      my $x   = $snp->{'position'};

      if ($snp->{'indel'}) {
        my $type    = ucfirst $snp->{'indel'};
        my $end     = $snp->{'indel'} eq 'insert' ? 1 : ($snp->{'length'} - 1);
        my $pos     = $x . ($end ? '-' . ($x + $end) : '');
        $url_params = {
                        vtype  => $type,
                        pos    => $pos,
                        len    => $snp->{'length'},
                        indel  => $snp->{'allele'},
                        %$url_params
                      };
        $feature_type = 'insertion' if $snp->{'indel'} eq 'insert';
      }
      else {
        $url_params = {
                        res    => $x,
                        cod    => $snp->{'ambigcode'}
                                  ? join('', map { $_ == $snp->{'codon_var_pos'}
                                      ? "[$snp->{'ambigcode'}]"
                                      : $snp->{'codon_seq'}->[$_] } 0..2)
                                  : '',
                        ar     => $snp->{'pep_snp'},
                        al     => $snp->{'allele'},
                        %$url_params
                      };
      }

      my $feature = {
                      start         => $snp->{'position'},
                      end           => $snp->{'position'} + $snp->{'length'} - 1,
                      type          => $feature_type,
                      colour        => $colour,
                      label         => $vf->variation_name,
                      text_overlay  => $snp->{'ambigcode'},
                      href          => $self->_url($url_params),
                    };


      push @$features_list, $feature;
      $self->{'legend'}{'variation_legend'}{$snp->{'vf'}->display_consequence} ||= $colour;
    }

    return [{'features' => $features_list}];
  }
}

sub colour_key { return lc $_[1]->display_consequence; }


############ OLD CODE ##############

=pod
sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};

  my $config     = $self->{'config'};
  my $snps       = $self->cache('image_snps');
  my $h          = $self->my_config('height') || 4;
  my $pix_per_bp = $self->scalex;
  my $t_width    = $h * 0.75 / $pix_per_bp;

  $self->_init_bump(undef, $self->depth || 1e6);

  return unless $snps;

  my $is_somatic = $self->{'my_config'}->id =~ /somatic/ ? 1 : 0;

  foreach my $snp (@$snps) {
    next if $snp->{'vf'}->is_somatic != $is_somatic;

    my $x      = $snp->{'position'};
    my $colour = $self->get_colour($snp->{'vf'});

    if ($snp->{'indel'}) {
      my ($y, $end, $direction) = $snp->{'indel'} eq 'insert' ? ($h, 1, 'down') : (0, $snp->{'length'} - 1, 'up');
      my $pos    = $x . ($end ? '-' . ($x + $end) : '');
      my $type   = ucfirst $snp->{'indel'};

      my ($glyph, $zmenu) = $self->Triangle({
        x         => $x - $t_width,
        y         => 0,
        width     => $t_width * 2,
        height    => $h,
        direction => $direction,
        mid_point => [ $x, $y ],
        colour    => $colour,
        absolutey => 1,
        href      => $self->_url({
          type   => 'Variation',
          action => 'VariationProtein',
          v      => $snp->{'snp_id'},
          vf     => $snp->{'vdbid'},
          vtype  => $type,
          pos    => $pos,
          len    => $snp->{'length'},
          indel  => $snp->{'allele'}
        })
      });

      my $bump_start = int($glyph->x * $pix_per_bp);
      my $bump_end   = $bump_start + $glyph->width + 3;
      my $row        = $self->bump_row($bump_start, $bump_end);

      $_->transform({ translatey => 1.5 * $row * ($h + 2) }) for $glyph, $zmenu;

      $self->push($glyph, $zmenu);

      # Force to the end of the legend
      $config->{'P_variation_legend'}{$type} ||= { shape => 'Triangle' };
    } else {
      my $glyph = $self->Rect({
        x             => $x - $h / 2,
        y             => 0,
        width         => $h,
        height        => $h,
        colour        => $colour,
        absolutey     => 1,
        absolutewidth => 1,
        href          => $self->_url({
          type   => 'Variation',
          action => 'VariationProtein',
          v      => $snp->{'snp_id'},
          vf     => $snp->{'vdbid'},
          res    => $x,
          cod    => $snp->{'ambigcode'} ? join('', map { $_ == $snp->{'codon_var_pos'} ? "[$snp->{'ambigcode'}]" : $snp->{'codon_seq'}->[$_] } 0..2) : '',
          ar     => $snp->{'pep_snp'},
          al     => $snp->{'allele'}
        })
      });

      my $bump_start = int($glyph->x * $pix_per_bp);
      my $bump_end   = $bump_start + $glyph->width + 3;
      my $row        = $self->bump_row($bump_start, $bump_end);

      $glyph->y($glyph->y + 1.5 * $row * ($h + 2));
      $self->push($glyph);

      $config->{'P_variation_legend'}{$snp->{'vf'}->display_consequence} ||= { colour => $colour, shape => 'Rect' };
    }
  }
}

sub render_text {
  my $self       = shift;
  my $container  = $self->{'container'};
  my $snps       = $self->cache('image_snps');
  my $is_somatic = $self->{'my_config'}->id =~ /somatic/ ? 1 : 0;

  return unless $snps;

  my $export;

  foreach my $snp (@$snps) {
    next if $snp->{'vf'}->is_somatic != $is_somatic;

    my $codon = $snp->{'ambigcode'} ? join '', map { $_ == $snp->{'codon_var_pos'} ? "[$snp->{'ambigcode'}]" : $snp->{'codon_seq'}->[$_] } 0..2 : '';
    my $class;

    if ($snp->{'indel'}) {
      $class = $snp->{'indel'};
    } else {
      $class = $snp->{'type'} eq 'SYNONYMOUS_CODING' ? 'syn' : 'snp';
    }

    $export .= $self->_render_text($container, 'Variation', {
      headers => [ 'variation_name', 'alleles', 'class', 'type', 'alternative_residues', 'codon' ],
      values  => [ $snp->{'snp_id'}, $snp->{'allele'}, $class, $snp->{'type'}, $snp->{'pep_snp'}, $codon ]
    }, {
      start  => $snp->{'position'},
      end    => $snp->{'position'} + $snp->{'length'},
      source => $snp->{'snp_source'}
    });
  }

  return $export;
}
=cut

1;
