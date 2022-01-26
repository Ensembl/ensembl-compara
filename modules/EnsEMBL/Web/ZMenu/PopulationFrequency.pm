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

package EnsEMBL::Web::ZMenu::PopulationFrequency;

use strict;

use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $vf     = $hub->param('vf');
  my $allele = $hub->param('allele');
  my $db     = $hub->param('vdb');
  my $vfa    = $hub->database($db)->get_VariationFeatureAdaptor;
  
  my $feature  = $vfa->fetch_by_dbID($vf);
  my $pop_freq = $self->object->format_group_population_freqs(1);

  my @entries = @{$self->population_frequency_popup($feature, $allele, $pop_freq)};

  if (scalar @entries == 0) {
    my $group;
    my %colours;
    $colours{$_} = "base_$_" for(qw(C G A T));
    foreach my $pop_name (sort { !$a <=> !$b || $b =~ /ALL/ cmp $a =~ /ALL/ || $a cmp $b } keys %$pop_freq) {
      my (@freqs, $af);
      $group = $pop_freq->{$pop_name}{'group'};
      my $pop_label = $pop_freq->{$pop_name}{'label'};

      # Keep the alleles order
      foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {
        foreach my $al (sort { $a cmp $b } keys (%{$pop_freq->{$pop_name}{'freq'}{$ssid}})) {
          $colours{$al} ||= "base_".(scalar(keys %colours)%4);
          my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$al};
          push @freqs, $colours{$al};
          push @freqs, $freq;
          $af .= $af ? ', ' : '';
          $af .= "$al: ";
          $af .= ($freq > 0.01) ? $freq : qq{<span style="color:red">$freq</span>};
        }

        my $img;
           $img .= sprintf '<span class="freq %s" style="width:%spx"></span>', shift @freqs, 100 * shift @freqs while @freqs;
           $af   = "<div>$af</div>";

        push @entries, { type => $pop_label, label_html => "$img$af" };
      }
    }
    if (scalar @entries != 0) {
      $self->caption('Population allele frequencies');
      $self->add_entry({ label_html => "No frequency found for the allele $allele" });
      $self->add_subheader($group);
      @entries = @{$self->add_footer($feature,\@entries)};     
    }
  }
  # Return data
  $self->add_entry($_) for @entries;
}


sub population_frequency_popup {
  my $self      = shift;
  my $feature   = shift;
  my $allele    = shift;
  my $pop_freq  = shift;

  my @entries = ();
  my $allele_header;

  my $hub = $self->hub;

#  my $extra_info = '';
  my @vf_alleles = split('/',$feature->allele_string);
  foreach my $pop_name (sort { ($a !~ /ALL/ cmp $b !~ /ALL/) || $a cmp $b } keys %$pop_freq) {

    my $group     = $pop_freq->{$pop_name}{'group'};
    my $pop_label = $pop_freq->{$pop_name}{'label'};

    foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {  
      my $allele_label;

      if ($pop_freq->{$pop_name}{'freq'}{$ssid}{$allele}) {
        $allele_label = $allele;
      }
      elsif ($allele =~ /[ATGC]+/){
        if (!grep{$allele eq $_} @vf_alleles) { # Check if allele in VF (not found in the $pop_freq hash)
          my $reverse_allele = $allele;
          reverse_comp(\$reverse_allele);
          if ($pop_freq->{$pop_name}{'freq'}{$ssid}{$reverse_allele}) {
            $allele_label = $reverse_allele;
          }
        }
      }

      if ($allele_label) {
        my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$allele_label};
        if (!$allele_header || $allele_header eq '') {
          my $allele_type = ($allele_label eq $vf_alleles[0]) ? 'Reference ' : 'Alternative';
          my $allele_strand = ($feature->seq_region_strand == 1) ? 'forward' : 'reverse';

          $allele_header = "Allele $allele_label";
          $self->caption($allele_header);
          $self->add_entry({ label_html => "$allele_type allele ($allele_strand strand)" });
          $self->add_subheader($group);

          push @entries, { type => 'Population', label_html => "Frequency $allele_label" };
        
        }
        $freq = ($freq > 0.01) ? $freq : qq{<span style="color:red">$freq</span>};
        push @entries, { type => $pop_label, label_html => $freq };
      }
    }
  }
  if (scalar @entries != 0) {
    @entries = @{$self->add_footer($feature,\@entries)};
  }

  return \@entries;
}


sub add_footer {
  my $self    = shift;
  my $feature = shift;
  my $entries = shift;

  my $url = $self->hub->url({ type => "Variation", action => "Population", vf => $feature->dbID });
  push @$entries, { label_html => "" };
  push @$entries, { label_html => qq{Frequencies <= 0.01 (1%) are displayed in <span style="color:red">red</span>.} };
  push @$entries, { label_html => qq{<a href="$url">More frequency data &rarr;</a>} };

  return $entries;
}

1;
