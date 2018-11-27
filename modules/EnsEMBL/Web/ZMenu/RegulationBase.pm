=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::RegulationBase;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub _add_nav_entries {
  my ($self,$evidence) = @_;

  my @zmenu_links = qw(regulation_view);

  my $config = $self->hub->param('config');
  if(grep { $config eq $_ } @zmenu_links) {
    my $cell_type_url = $self->hub->url('MultiSelector', {
      type => 'Regulation',
      action   => 'CellTypeSelector',
      image_config => $config,
    });
    my $evidence_url = $self->hub->url('MultiSelector', {
      type => 'Regulation',
      action => 'EvidenceSelector',
      image_config => $config,
    });
    $self->add_entry({ label => "Select other cell types", link => $cell_type_url, link_class => 'modal_link' });
    $self->add_entry({ label => "Select evidence to show", link => $evidence_url, link_class => 'modal_link' });
  }
  if($evidence&1) {
    my $signal_url = $self->hub->url({
      action => $self->hub->param('act'),
      plus_signal => $config,
    });
    $self->add_entry({ label => "Also show raw signal", link => $signal_url });
  }
}

sub get_motif_features_by_epigenome {
  my ($self, $reg_feat, $cell_line) = @_;
  return {} unless ($reg_feat && $cell_line);
  my @motif_features = @{$reg_feat->fetch_all_MotifFeatures_with_matching_Peak};
  my $motifs = {};

  foreach my $mf (@motif_features) {
    my $peak = $mf->fetch_overlapping_Peak_by_Epigenome($cell_line);
    if ($peak) {
      my $mf_info = $self->_format_mf_info($mf);
      $motifs->{$mf->start .':'. $mf->end} = $mf_info if $mf_info;
    }
  }
  return $motifs;
}

sub get_motif_features_by_peak {
  my ($self, $peak) = @_;
  my @motif_features = @{$peak->fetch_all_MotifFeatures};
  my $motifs = {};

  foreach my $mf (@motif_features) {
      my $mf_info = $self->_format_mf_info($mf);
      $motifs->{$mf->start .':'. $mf->end} = $mf_info if $mf_info;
  }

  return $motifs; 
}

sub _format_mf_info {
  my ($self, $mf) = @_;

  my $matrix = $mf->binding_matrix;
  return undef unless $matrix;

  my $matrix_id = '<a href="#" class="_motif">'.$mf->binding_matrix->stable_id.'</a>';
  my @names = @{$matrix->get_TranscriptionFactorComplex_names||[]};
  my $name_string = '';
  if (scalar @names) {
    ## We don't want the string to be too long, but names can be very variable in length
    $name_string = $names[0];
    my $i = 1;
    my $max_length = 12;
    for ($i = 1; $i < scalar @names; $i++) {
      if (length($names[$i]) < ($max_length - length($name_string))) {
        $name_string .= ', '.$names[$i];
      }
      else {
        last;
      }
    }
    $name_string .= '...' if scalar @names > $i;
  }
  return [$mf->stable_id, $name_string, $matrix_id, $mf->score];
} 

sub _add_motif_feature_table {
  my ($self, $motif_features) = @_;
  return unless scalar keys %{$motif_features||{}} > 0;
  
  $self->add_subheader('Motif Information');

  # get region clicked on
  my $click_start = $self->hub->param('click_start');
  my $click_end   = $self->hub->param('click_end');
  my ($start, $end, @feat);

  foreach my $motif (keys %$motif_features) {
    ($start, $end) = split /:/, $motif;
    push @feat, $motif unless $start > $click_end || $end < $click_start;
  }

  my $pwm_table = '
        <table cellpadding="0" cellspacing="0">
          <tr>
            <th style="width:20%">Motif feature</th>
            <th style="width:30%">Transcription factors</th>
            <th style="width:30%">Binding matrix</th>
            <th style="width:20%">Score</th>
          </tr>
  ';

  foreach my $motif (sort keys %$motif_features) {
    my ($stable_id, $tfactors, $binding_matrix, $score) = @{$motif_features->{$motif}};

    my $nice_score = sprintf('%.4f', $score);
    $pwm_table .= qq(<tr>
                        <td>$stable_id</td>
                        <td>$tfactors</td>
                        <td>$binding_matrix</td>
                        <td>$nice_score</td>
                      </tr>);
  }

  $pwm_table .= '</table>';

  $self->add_entry({ label_html => $pwm_table });
}

1;

