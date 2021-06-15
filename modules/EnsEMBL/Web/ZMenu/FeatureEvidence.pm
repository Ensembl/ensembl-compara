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

package EnsEMBL::Web::ZMenu::FeatureEvidence;

use strict;

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $db_adaptor          = $hub->database($hub->param('fdb'));
  my $peak_calling        = $db_adaptor->get_PeakCallingAdaptor->fetch_by_name($hub->param('fs')); 
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;
  my $slice               = $hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $end);
  my @peaks               = @{$db_adaptor->get_PeakAdaptor->fetch_all_by_Slice($slice)};
  my $peak;
  
  foreach (@peaks) { 
    if ($_->peak_calling_id eq $peak_calling->dbID && $_->start == 1 && $_->end == $length) {
      $peak = $_;
      last;
    }
  }

  my $summit   = $peak->summit || 'undetermined';
  
  $self->caption($peak_calling->get_FeatureType->evidence_type_label);
  
  $self->add_entry({
    type  => 'Feature',
    label => $peak_calling->display_label
  });

  my $source_label = $peak_calling->get_source_label;

  if(defined $source_label){

    $self->add_entry({
      type        => 'Source',
      label_html  =>  sprintf '<a href="%s">%s</a> ',
                      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => 'name-'.$peak_calling->name}),
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

  $self->_add_motif_feature_table($self->get_motif_features_by_peak($peak));

}

1;
