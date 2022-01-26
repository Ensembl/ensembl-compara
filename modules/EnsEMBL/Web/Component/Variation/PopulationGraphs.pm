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

package EnsEMBL::Web::Component::Variation::PopulationGraphs;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $pop_freq  = $self->object->format_group_population_freqs();
  
  return unless defined $pop_freq;
  
  my $graph_id    = 0;
  my $height      = 50;
  my $width       = 118;
  my $max_width   = 150;
  my $max_pie_chart_count = 35;
  my (@graphs, $pop_tree, %sub_pops, @alleles);

  my $vf         = $hub->param('vf');
  my $vf_object  = $vf ? $hub->database('variation')->get_VariationFeatureAdaptor->fetch_by_dbID($vf) : undef;
  my $ref_allele = $vf_object ? $vf_object->ref_allele_string : '';
  
  my @inputs = (
    q{<input class="graph_config" type="hidden" name="legendpos" value="'east'" />},
    q{<input class="graph_config" type="hidden" name="legendmark" value="'arrow'" />},
    q{<input class="graph_dimensions" type="hidden" value="[25,25,20]" />},
  );
  
  # Get alleles list
  my $project_name;
  my $pop_width = $width;
  my $has_100 = 0;
  foreach my $pop_name (sort keys %$pop_freq) {
    my $values = '';

    $pop_tree = $self->update_pop_tree($pop_tree, $pop_name, $pop_freq->{$pop_name}{'sub_pop'}) if defined $pop_freq->{$pop_name}{'sub_pop'};

    $project_name = $pop_freq->{$pop_name}{'group'} if (!$project_name);

    foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {
      foreach my $allele (keys %{$pop_freq->{$pop_name}{'freq'}{$ssid}}) {
        my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$allele};
        my $allele_length = length($allele);
        my $new_width = ($allele_length > 1) ? $width + (($allele_length - 1) * 5) : $width;
        $pop_width = $new_width if ($new_width > $pop_width);
        $has_100 = 1 if ($freq == 1);
        push (@alleles, $allele) if $freq > 0 && !(grep $allele eq $_, @alleles);
      }
    }
  }
  $width = ($pop_width > $max_width) ? $max_width : $pop_width;
  $width += 5 if ($has_100 == 1);
  
  my $nb_alleles = scalar @alleles;
  
  if ($nb_alleles > 2) {
    while ($nb_alleles != 2) {
      $height += 5;
      $nb_alleles--;
    }
  }
  
  # Create graphs
  my $population_count = scalar keys %$pop_freq;
  my $too_many_populations = ($population_count > $max_pie_chart_count);
  foreach my $pop_name (sort { ($a !~ /ALL/ cmp $b !~ /ALL/) || $a cmp $b } keys %$pop_freq) {
    if ($too_many_populations) {
      next if ($pop_name !~ /ALL/);
    }
    my $values     = '';
    my $short_name = $self->get_short_name($pop_name);
    my $pop_desc   = $pop_freq->{$pop_name}{'desc'};
    if (!$pop_desc || $pop_desc eq '') {
      $pop_desc = $short_name;
      $pop_desc =~ s/_/ /g;
    }
    $pop_desc = $self->strip_HTML($pop_desc);

    # Constructs the array for the pie charts: [allele,frequency]
    foreach my $al (sort { ($a !~ /$ref_allele/ cmp $b !~ /$ref_allele/) || $a cmp $b } @alleles) {
      foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {
        my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$al};
        next unless $freq;
        
        $values .= ',' if $values ne '';
        $freq    = $self->format_number($freq);
        $freq    = 0.5 if $freq < 0.5; # Fixed bug if freq between 0 and 0.5
        my $a_label = $al;
        if (length($al)>4) {
          $a_label = substr($al,0,4).'...';
        }
        $values .= "[$freq,'$a_label']";
        last;
      }
    }

    push @inputs, qq{<input type="hidden" class="graph_data" value="[$values]" />};

    # Main "ALL" population OR no population structure
    if ($short_name =~ /ALL/ || scalar(keys(%$pop_tree)) == 0) {
      push @graphs, sprintf('
        <div class="pie_chart_holder">
          <div class="pie_chart%s">
            <div style="margin:4px">
              <span class="_ht ht" style="font-size:1em;font-weight:bold" title="%s">%s</span>
            </div>
            <div id="graphHolder%s" style="width:%ipx;height:%ipx"></div>
          </div>
        </div>
      ', $short_name eq 'ALL' ? ' all_population' : '', $pop_desc, $short_name, $graph_id, $width, $height);
    }
    # Super-population
    elsif ($pop_tree->{$short_name}) {
      push @graphs, sprintf('
        <div class="pie_chart_holder">
          <div class="pie_chart">
            <div style="margin:4px">
              <span class="_ht ht" style="font-size:1em;font-weight:bold" title="%s">%s</span>
            </div>
            <div id="graphHolder%s" style="width:%ipx;height:%ipx"></div>
          </div>
          <a class="toggle %s _slide_toggle set_cookie" href="#" style="margin-left:5px" rel="population_freq_%s" title="Click to toggle sub-population frequencies">Sub-populations</a>
        </div>
      ', $pop_desc, $short_name, $graph_id, $width, $height, 
         $hub->get_cookie_value("toggle_population_freq_$short_name") eq 'open' ? 'open' : 'closed', 
         $short_name, $short_name);
    }
    # Sub-populations
    else {
      foreach (grep $pop_tree->{$_}{$short_name}, keys %$pop_tree) {
        push @{$sub_pops{$_}}, sprintf('
          <div class="pie_chart_holder">
            <div class="pie_chart">
              <div style="margin:4px">
                <span class="_ht ht" style="font-size:1em;font-weight:bold" title="%s">%s</span>
              </div>
              <div id="graphHolder%s" style="width:%ipx;height:%ipx"></div>
            </div>
          </div>
        ', $pop_desc, $short_name, $graph_id, $width, $height);
      }
    }
    
    $graph_id++;
  }
  
  my $html = sprintf(
    '<h2>%s allele frequencies</h2><div><input type="hidden" class="panel_type" value="PopulationGraph" />%s</div><div class="population_genetics_pie">%s</div>',
    $project_name,
    join('', @inputs),
    join('', @graphs)
  );
  
  foreach my $sp (sort keys %sub_pops) {
    my $sub_html = join '', @{$sub_pops{$sp}};
    my $show     = $hub->get_cookie_value("toggle_population_freq_$sp") eq 'open';
    
    $html .= sprintf('
      <div class="population_freq_%s population_genetics_pie" id="population_freq_%s">
        <div class="toggleable" %s>
          <div><p><b>%s sub-populations</b></p></div>
          %s
        </div>
      </div>
    ', $sp, $sp, $show ? '' : 'style="display:none"', $sp, $sub_html);
  }

  return $html;
}

sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  return 'unknown' if (!defined($number) || $number eq 'unknown');

  $number = $number * 100;
  return sprintf '%.2f', $number;
}


sub update_pop_tree {
  my ($self, $p_tree, $p_name, $sub_list) = @_;
  my $p_short_name = $self->get_short_name($p_name);
  
  foreach my $sub_pop (keys %$sub_list) {
    my $sub_name       = $sub_list->{$sub_pop}{'Name'};
    my $sub_short_name = $self->get_short_name($sub_name);
    
    $p_tree->{$p_short_name}{$sub_short_name} = 1;
  }
  
  return $p_tree;
}

sub get_short_name {
  my $self   = shift;
  my $p_name = shift;
  my @composed_name = split(':', $p_name);
  my $short_name = $composed_name[$#composed_name]; 

  if ($short_name =~ /phase_\d+_(.+)$/) {
    $short_name = $1;
  }

  return $short_name;
}

1;
