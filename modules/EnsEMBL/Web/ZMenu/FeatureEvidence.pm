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

package EnsEMBL::Web::ZMenu::FeatureEvidence;

use strict;

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $db_adaptor          = $hub->database($hub->param('fdb'));
  my $feature_set         = $db_adaptor->get_FeatureSetAdaptor->fetch_by_name($hub->param('fs')); 
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;
  my $slice               = $hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $end);
  my @a_features          = @{$db_adaptor->get_AnnotatedFeatureAdaptor->fetch_all_by_Slice($slice)};
  my $annotated_feature;
  
  foreach (@a_features) { 
    $annotated_feature = $_ if $_->feature_set->display_label eq $feature_set->display_label && $_->start == 1 && $_->end == $length;
  }

  my $summit   = $annotated_feature->summit || 'undetermined';
  my @features = @{$annotated_feature->get_associated_MotifFeatures};
  my %motif_features;
  
  foreach my $mf (@features) {
    my %assoc_ftype_names = map { $_->feature_type->name => 1 } @{$mf->associated_annotated_features};
    my $bm_ftname         = $mf->binding_matrix->feature_type->name;
    my @other_ftnames     = grep $_ ne $bm_ftname, keys %assoc_ftype_names;
    my $other_names_txt   = scalar @other_ftnames ? sprintf(' (%s)', join ' ', @other_ftnames) : '';

    $motif_features{$mf->start . ':' . $mf->end} = [ "$bm_ftname$other_names_txt", $mf->score, $mf->binding_matrix->name ];
  }
  
  $self->caption($feature_set->feature_type->evidence_type_label);
  
  $self->add_entry({
    type  => 'Feature',
    label => $feature_set->display_label
  });


  my $source_label = $feature_set->source_label;

  if(defined $source_label){

    $self->add_entry({
      type        => 'Source',
      label_html  =>  sprintf '<a href="%s">%s</a> ',
                      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => 'name-'.$feature_set->name}),
                      $source_label
                     });
  }

  my $loc_link = sprintf '<a href="%s">%s</a>', 
                          $hub->url({'type'=>'Location','action'=>'View','r'=> $hub->param('pos')}),
                          $hub->param('pos');
  $self->add_entry({
    type        => 'bp',
    label_html  => $loc_link,
  });

  if ($hub->param('ps') !~ /undetermined/) {
    $self->add_entry({
      type  => 'Peak summit',
      label => $summit
    });
  }

  $self->_add_nav_entries($hub->param('evidence')||0);

  if (scalar (keys %motif_features) > 0  ){
    # get region clicked on
    my $nearest_feature = 1;
    my $nearest         = 1e12; # Arbitrary large number
    my $click_start     = $hub->param('click_start');
    my $click_end       = $hub->param('click_end');
    my ($left, $right, $min, @feat);

    foreach my $motif (keys %motif_features) {
      my $motif_id = $motif;
      ($left, $right) = split /\:/, $motif;
      $right += $start; 
      $left  += $start;
      $left  -= $click_start;     
      $right  = $click_end - $right;
  
      # If both are 0 or positive, feature is inside the click region.
      # If both are negative, click is inside the feature.
      if (($left >= 0 && $right >= 0) || ($left < 0 && $right < 0)) {
        push @feat, $motif_id;
        $nearest_feature = undef;
      } elsif ($nearest_feature) {
        $min = [ sort { $a <=> $b } abs($left), abs($right) ]->[0];

        if ($min < $nearest) {
          $nearest_feature = $motif_id;
          $nearest = $min;
        }
      }
    }

    # Return the nearest feature if it's inside two click widths
    push @feat, $nearest_feature if $nearest_feature && $nearest < 2 * ($click_end - $click_start);

    $self->add_entry ({
      label_html => undef,
    });
    
    $self->add_subheader('<span align="center">Motif Information</span>');

    my $pwm_table = '
    <table cellpadding="0" cellspacing="0" class="zmenu" style="border:0; padding:0px; margin:0px;">
      <tr>
        <th>Name</th>
        <th>PWM ID</th>
        <th>Score</th>
      </tr>
    ';

    foreach my $motif (sort keys %motif_features){
      my ($name, $score, $binding_matrix_name) = @{$motif_features{$motif}};
      my $style   = scalar @feat == 1 && $feat[0] eq $motif ? ' style="background-color: #BBCCFF"' : '';
      my $bm_link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
      $pwm_table .= "<tr><td$style>$name</td><td$style>$bm_link</td><td$style>$score</td></tr>";
    }

    $pwm_table .= '</table>';
    
    $self->add_entry({
      label_html => $pwm_table
    });
  }
}

1;
