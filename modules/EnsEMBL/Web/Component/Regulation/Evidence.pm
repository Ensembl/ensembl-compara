# $Id$

package EnsEMBL::Web::Component::Regulation::Evidence;

use strict;

use base qw(EnsEMBL::Web::Component::Regulation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self          = shift;
  my $object        = $self->object;
  my $context       = $self->hub->param('context') || 200;
  my $object_slice  = $object->get_bound_context_slice($context); 
     $object_slice  = $object_slice->invert if $object_slice->strand < 1;
  my $evidence_data = $object->get_evidence_data($object_slice, 1);
  
  return '<p>There is no evidence for this regulatory feature </p>' unless scalar keys %$evidence_data;

  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'cell asc', 'type asc', 'location asc' ]});
  
  $table->add_columns(
    { key => 'cell',     title => 'Cell type',     align => 'left', sort => 'string'   },
    { key => 'type',     title => 'Evidence type', align => 'left', sort => 'string'   },
    { key => 'feature',  title => 'Feature name',  align => 'left', sort => 'string'   },
    { key => 'location', title => 'Location',      align => 'left', sort => 'position' },
  ); 

  my @rows;

  foreach my $cell_line (sort keys %{$evidence_data}) {
    my $core_features  = $evidence_data->{$cell_line}{'core'}{'block_features'};
    my $other_features = $evidence_data->{$cell_line}{'other'}{'block_features'};
    
    # Process core features first
    foreach my $features ($core_features, $other_features) {
      foreach my $f_set (sort { $features->{$a}[0]->start <=> $features->{$b}[0]->start } keys %$features) { 
        my $feature_name = [split /:/, $f_set]->[1];
        
        foreach my $f (sort { $a->start <=> $b->start } @{$features->{$f_set}}) {
          my $f_start = $object_slice->start + $f->start - 1;
          my $f_end   = $object_slice->start + $f->end   - 1;
          
          push @rows, { 
            type     => $f->feature_type->evidence_type_label,
            location => $f->slice->seq_region_name . ":$f_start-$f_end",
            feature  => $feature_name,
            cell     => $cell_line
          };
          
          push @rows, @{$self->get_motif_rows($f, $cell_line)} if $features == $core_features;
        }
      }
    }
  }
  
  $table->add_rows(@rows);

  return $table->render;
}

sub get_motif_rows {
  my ($self, $f, $cell_line) = (@_);
  my $hub = $self->hub;
  my @motif_rows; 

  foreach my $mf (@{$f->get_associated_MotifFeatures}) {
    my ($name, $binding_matrix_name) = split /:/, $mf->display_label;

    push @motif_rows, {
      type     => $f->feature_type->evidence_type_label,
      location => $mf->seq_region_name . ':' . $mf->seq_region_start . '-' . $mf->seq_region_end,
      feature  => sprintf('%s (%s)', $name, $hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name)),
      cell     => $cell_line
    };
  }
  
  return \@motif_rows;
}

1;
