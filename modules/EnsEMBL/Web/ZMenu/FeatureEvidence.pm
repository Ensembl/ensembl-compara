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
    # get region clicked on
    my $nearest_feature =1;
    my $nearest         = 1e12; # Arbitrary large number
    my ($left, $right, $min, @feat);
    my $click_start = $hub->param('click_start');
    my $click_end = $hub->param('click_end');

    foreach my $motif (keys %motif_features ){
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
    $self->add_subheader('<span align="center">PWM Information</span>');

    my $pwm_table = '<table cellpadding="0" cellspacing="0" style="border:0; padding:0px; margin:0px;">
                     <tr><th>Name</th><th>ID</th><th>Score</th></tr>';

    foreach my $motif (sort keys %motif_features){
      my ($name, $score, $binding_matrix_name) = @{$motif_features{$motif}};
      my $style;
      if (scalar @feat == 1 && $feat[0] eq $motif ){
        $style = 'style="background-color: #BBCCFF"';
      }
      my $bm_link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
      $pwm_table .= sprintf( '<tr><td %s>%s</td><td %s>%s</td><td %s>%s</td></tr>',
        $style,
        $name,
        $style,
        $bm_link,
        $style,
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
