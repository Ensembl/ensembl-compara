package EnsEMBL::Web::ZMenu::Supporting_alignment;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $id           = $object->param('id');
  my $db           = $object->param('fdb') || $object->param('db') || 'core'; 
  my $object_type  = $object->param('ftype');
  my $db_adaptor   = $object->database(lc($db));
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;
  my $features     = $feat_adap->fetch_all_by_hit_name($id) || [];
  my $click_start  = $object->param('click_start');
  my $click_end    = $object->param('click_end');

  $self->caption($id);

  if ($features->[0]->analysis->logic_name =~ /intron/) {

    if (scalar(@$features) > 1) { warn "multiple intron objects, not good, code is written for single ones";}

    my $r = $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end;
    $self->add_entry({
      type  => 'Location',
      label => $r,
    });

    my $score = $features->[0]->score;
    $self->add_entry({
      type  => 'Read coverage',
      label => $score,
    });
  }

  else {
    my $longest_feat_dbID;
    my $length = 0;
    #code below assumes longest feature supports the transcript - quicker than getting a slice for each feature
    #and identifying (transcript)_supporting_features using fetch_all_by_Slice_constraint
    #will need modifying for single exon Zv9 RNASeq transcripts - either with API call on feature, or by hit name or logic_name
    foreach my $feat (@$features) {
      if (($feat->end - $feat->start + 1) > $length) {
	$longest_feat_dbID = $feat->dbID;
	$length = $feat->end - $feat->start + 1;
      }
    }
    foreach my $feat (@$features) {
      if ( ($click_start < $feat->end) && ($click_end > $feat->start) ) {
	my $type = $feat->dbID eq $longest_feat_dbID ? 'transcript RPKM' : 'exon RPKM';
	my $evalue = sprintf ("%.4f",$feat->{'p_value'});
	$self->add_entry({
	  type  => $type,
	  label => $evalue,
	});
      }
    }
  }

  #don't bother showing the usual featureview link since the names are unique
#  $self->add_entry({ 
#    label => 'View all hits',
#    link  => $object->_url({
#      type   => 'Location',
#      action => 'Genome',
#      ftype  => $object_type,
#      id     => $id,
#      db     => $db
#    })
#  });

  $self->add_entry({
    label_html => $features->[0]->analysis->description
  });

}

1;
