# $Id$

package EnsEMBL::Web::Component::Regulation::Evidence;

use strict;

use base qw(EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self                  = shift;
  my $object                = $self->object;
  my $context               = $self->hub->param('context') || 200;
  my $object_slice          = $object->get_bound_context_slice($context); 
     $object_slice          = $object_slice->invert if $object_slice->strand < 1;
  my $evidence_multicell    = $object->get_multicell_evidence_data($object_slice, 1); 
  my $evidence_by_cell_line = $object->get_evidence_data($object_slice, 1); 
  
  $evidence_by_cell_line->{'MultiCell'} = $evidence_multicell->{'MultiCell'};

  return '<p>There is no evidence for this regulatory feature </p>' unless scalar keys %$evidence_by_cell_line;

  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'cell asc', 'type asc', 'location asc' ]});
  $table->add_columns(
    { 'key' => 'cell',     'title' => 'Cell type',     'align' => 'left', sort => 'string'   },
    { 'key' => 'type',     'title' => 'Evidence type', 'align' => 'left', sort => 'string'   },
    { 'key' => 'feature',  'title' => 'Feature name',  'align' => 'left', sort => 'string'   },
    { 'key' => 'location', 'title' => 'Location',      'align' => 'left', sort => 'position' },
  ); 

  my @rows;
  my %seen_evidence_type;

  foreach my $cell_line (sort keys %{$evidence_by_cell_line}){ 
    # Process core features first
    my $core_features = $evidence_by_cell_line->{$cell_line}{'focus'}{'block_features'}; 
    foreach my $f_set (sort { $core_features->{$a}->[0]->start <=> $core_features->{$b}->[0]->start  } keys %$core_features){ 
      my $feature_name = $f_set;
      my @temp = split (/:/, $feature_name);
      $feature_name = $temp[1]; 
      my $features = $core_features->{$f_set};
      foreach my $f ( sort { $a->start <=> $b->start } @$features){
        my $f_start = ($object_slice->start + $f->start) -1;
        my $f_end = ($object_slice->start + $f->end) -1;
        my $location = $f->slice->seq_region_name .":".$f_start ."-" . $f_end;
        my $row = { 
          'type'      => 'Core',
          'location'  => $location,
          'feature'   => $feature_name,
          'cell'      => $cell_line
        };
        push @rows, $row;
        my $motif_rows = $self->get_motif_rows($f, $cell_line);
        @rows = (@rows, @{$motif_rows});
      }
    } 
    # then process other features
    my $other_features =  $evidence_by_cell_line->{$cell_line}{'non_focus'}{'block_features'};
    foreach my $f_set ( sort { $other_features->{$a}->[0]->start <=> $other_features->{$b}->[0]->start} keys %$other_features){ 
      my $feature_name = $f_set;
      my @temp = split (/:/, $feature_name);
      $feature_name = $temp[1]; 
      my $features = $other_features->{$f_set};
      foreach my $f ( sort { $a->start <=> $b->start } @$features){
        my $f_start = ($object_slice->start + $f->start) -1;
        my $f_end = ($object_slice->start + $f->end) -1;
        my $location = $f->slice->seq_region_name .":".$f_start ."-" . $f_end;
        my $row = {
          'type'      => 'Other',
          'location'  => $location,
          'feature'   => $feature_name,
          'cell'      => $cell_line
        };
        push @rows, $row;
      }
    }
  }
  
  $table->add_rows(@rows);

  return $table->render;
}

sub get_motif_rows {
  my ($self, $f, $cell_line) = (@_);

  my @motif_rows; 

  foreach my $mf (@{$f->get_associated_MotifFeatures}){
    my ($name, $binding_matrix_name)   = split(/:/, $mf->display_label);
    my $link = $self->hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
    my $feature_name = sprintf '%s (%s)', $name, $link;
    my $location = $mf->seq_region_name .':' . $mf->seq_region_start .'-'. $mf->seq_region_end;   
 
    my $row = {
      'type'      => 'Core PWM',
      'location'  => $location,
      'feature'   => $feature_name,
      'cell'      => $cell_line
    };

    push @motif_rows, $row;
  }
  return \@motif_rows;
}

1;
