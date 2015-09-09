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

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use List::Util qw(first);

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $rf   = $hub->param('rf');
  
  return unless $rf; 
  
  my $cell_line = $hub->param('cl');
  my $reg_feature;
  
  foreach (@{$hub->database('funcgen')->get_RegulatoryFeatureAdaptor->fetch_all_by_stable_ID($rf)}) {
    if ($cell_line) {
      $reg_feature = $_ if $_->feature_set->cell_type->name =~ /$cell_line/i;
    } elsif ($_->feature_set->cell_type->name =~ /multi/i) {
      $reg_feature = $_;
    }
  }
  
  my $object         = $self->new_object('Regulation', $reg_feature, $self->object->__data);
  my %motif_features = %{$object->get_motif_features};
 
  my $cell_type = $reg_feature->feature_set->cell_type->name;
  $self->caption("Regulatory Feature - $cell_type");
  
  $self->add_entry({
    type  => 'Stable ID',
    label => $object->stable_id,
    link  => $object->get_summary_page_url
  });
  
  $self->add_entry({
    type  => 'Type',
    label => $object->feature_type->name
  });
  
  $self->add_entry({
    type        => 'Core bp',
    label       => $object->location_string,
    link        => $object->get_location_url,
    link_class  => '_location_change _location_mark'
  });
  
  unless ($object->bound_start == $object->seq_region_start && $object->bound_end == $object->seq_region_end) {
    $self->add_entry({
      type        => 'Bounds bp',
      label       => $object->bound_location_string,
      link        => $object->get_bound_location_url,
      link_class  => '_location_change _location_mark'
    });
  }

  if($hub->is_new_regulation_pipeline and $cell_type ne 'MultiCell') {
    my $status = "Unknown";
    my $has_evidence = $object->has_evidence;
    if($has_evidence) {
      $status = "Active";
    } elsif(defined $has_evidence) {
      $status = "Inactive";
    }

    $self->add_entry({
      type => 'Status',
      label => $status
    });
  }

  $self->add_entry({
    type  => 'Attributes',
    label => $object->get_attribute_list
  });
  
  $self->add_entry({ label_html => 'NOTE: This feature has been projected by the <a href="/info/genome/funcgen/index.html">RegulatoryBuild</a>' }) if $reg_feature->is_projected;

  $self->_add_nav_entries;

  if (scalar keys %motif_features > 0) {
    # get region clicked on
    my $click_start = $hub->param('click_start');
    my $click_end   = $hub->param('click_end');
    my ($start, $end, @feat);
    
    foreach my $motif (keys %motif_features) {
      ($start, $end) = split /:/, $motif;
      push @feat, $motif unless $start > $click_end || $end < $click_start;
    }
    
    $self->add_subheader('Motif Information');
    
    my $pwm_table = '
      <table cellpadding="0" cellspacing="0">
        <tr><th>Name</th><th>PWM ID</th><th>Score</th></tr>
    ';
    
    foreach my $motif (sort keys %motif_features) {
      my ($name, $score, $binding_matrix_name) = @{$motif_features{$motif}};
      my $bm_link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
      my $style   = (first { $_ eq $motif } @feat) ? ' style="background:#BBCCFF"' : '';
      
      $pwm_table .= "<tr$style><td>$name</td><td>$bm_link</td><td>$score</td></tr>";
    }
    
    $pwm_table .= '</table>';
    
    $self->add_entry({ label_html => $pwm_table });
  }
}

1;
