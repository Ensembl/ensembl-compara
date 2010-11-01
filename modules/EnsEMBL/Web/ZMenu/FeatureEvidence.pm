# $Id$

package EnsEMBL::Web::ZMenu::FeatureEvidence;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $db_adaptor        = $hub->database($hub->param('fdb'));
  my $feature_set       = $db_adaptor->get_FeatureSetAdaptor->fetch_by_name($hub->param('fs')); 
  my ($chr, $start, $end) = split (/\:|\-/g, $hub->param('pos'));
  my $slice             = $hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $end);

  my @a_features = @{$db_adaptor->get_AnnotatedFeatureAdaptor->fetch_all_by_Slice($slice)};
  my $annotated_feature;
  foreach ( @a_features) {
    if ($_->feature_set->display_label eq $feature_set->display_label) { $annotated_feature = $_; }
  }

  my $summit         = $annotated_feature->summit || 'undetermined';
  my @features = @{$annotated_feature->get_associated_MotifFeatures};
  my %motif_features;
  foreach my $mf (@features){
    my %assoc_ftype_names;
    map {$assoc_ftype_names{$_->feature_type->name} = undef} @{$mf->associated_annotated_features};
    my $bm_ftname = $mf->binding_matrix->feature_type->name;
    my @other_ftnames;
    foreach my $af_ftname(keys(%assoc_ftype_names)){
      push @other_ftnames, $af_ftname if $af_ftname ne $bm_ftname;
    }

    my $other_names_txt = '';

    if(@other_ftnames){
      $other_names_txt = ' ('.join(' ', @other_ftnames).')';
    }

    $motif_features{$mf->start .':'. $mf->end} = [ $bm_ftname.$other_names_txt,  $mf->score];
  }
  


  $self->caption('Evidence');
  
  $self->add_entry({
    type  => 'Feature',
    label => $feature_set->display_label
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $hub->param('pos')
  });

  if ($hub->param('ps') !~ /undetermined/) {
    $self->add_entry({
      type  => 'Peak summit',
      label => $summit
    });
  }
  foreach my $motif (sort keys %motif_features){
    my ($name, $score) = @{$motif_features{$motif}};
    $self->add_entry({
      type  => $name,
      label => $score
    });
  }
}

1;
