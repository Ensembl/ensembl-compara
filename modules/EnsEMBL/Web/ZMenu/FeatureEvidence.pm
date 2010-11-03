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

    $motif_features{$mf->start .':'. $mf->end} = [ $bm_ftname.$other_names_txt,  $mf->score, $mf->binding_matrix->name];
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

  if (scalar (keys %motif_features) >> 0  ){
    $self->add_entry ({
    label_html => undef,
    });
    $self->add_subheader('<span align="center">PWM Information</span>');

    my $pwm_table = '<table cellpadding="0" cellspacing="0" style="border:0; padding:0px; margin:0px;">
                     <tr><th>Name</th><th>ID</th><th>Score</th></tr>';

    foreach my $motif (sort keys %motif_features){
      my ($name, $score, $binding_matrix_name) = @{$motif_features{$motif}};
      my $bm_link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
      $pwm_table .= sprintf( '<tr><td>%s</td><td>%s</td><td>%s</td></tr>',
        $name,
        $bm_link,
        $score
      );
    }

    $pwm_table .= "</table>";
    $self->add_entry({
      label_html => $pwm_table
    });
  }    
}

1;
