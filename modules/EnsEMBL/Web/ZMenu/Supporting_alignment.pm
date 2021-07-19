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

package EnsEMBL::Web::ZMenu::Supporting_alignment;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $id           = $hub->param('id');
  my $db           = $hub->param('fdb') || $hub->param('db') || 'core'; 
  my $object_type  = $hub->param('ftype');
  my $db_adaptor   = $hub->database(lc $db);
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;
  my $click_start  = $hub->param('click_start');
  my $click_end    = $hub->param('click_end');
  my $logic_name   = $hub->param('ln');
  my $features     = $feat_adap->fetch_all_by_hit_name($id) || [];
  my ($feature)    = $logic_name ? grep $_->analysis->logic_name eq $logic_name, @$features : $features->[0];

  $self->caption($id);
  
  if ($feature->analysis->logic_name =~ /intron/) {
    $self->add_entry({
      type  => 'Location',
      label => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end,
    });
    
    $self->add_entry({
      type  => 'Read coverage',
      label => $feature->score,
    });
  } else {
    my $longest_feat_dbID;
    my $length = 0;
    
    # Code below assumes longest feature supports the transcript - quicker than getting a slice for each feature
    # and identifying (transcript)_supporting_features using fetch_all_by_Slice_constraint
    # will need modifying for single exon Zv9 RNASeq transcripts - either with API call on feature, or by hit name or logic_name
    foreach my $feat (@$features) {
      if (($feat->end - $feat->start + 1) > $length) {
        $longest_feat_dbID = $feat->dbID;
        $length = $feat->end - $feat->start + 1;
      }
    }
    
    foreach my $feat (@$features) {
      if (($click_start < $feat->end) && ($click_end > $feat->start)) {
        my $type   = $feat->dbID eq $longest_feat_dbID ? 'transcript RPKM' : 'exon RPKM';
        my $evalue = sprintf '%.4f', $feat->{'p_value'};
        
        $self->add_entry({
          type  => $type,
          label => $evalue,
        });
      }
    }
  }

  $self->add_entry({
    label_html => $feature->analysis->description
  });
}

1;
