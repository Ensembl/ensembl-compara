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
  my $features     = $feat_adap->fetch_all_by_hit_name($id) || [];
  my $click_start  = $hub->param('click_start');
  my $click_end    = $hub->param('click_end');

  $self->caption($id);

  if ($features->[0]->analysis->logic_name =~ /intron/) {
    warn 'multiple intron objects, not good, code is written for single ones' if scalar @$features > 1;
    
    $self->add_entry({
      type  => 'Location',
      label => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end,
    });
    
    $self->add_entry({
      type  => 'Read coverage',
      label => $features->[0]->score,
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
    label_html => $features->[0]->analysis->description
  });
}

1;
