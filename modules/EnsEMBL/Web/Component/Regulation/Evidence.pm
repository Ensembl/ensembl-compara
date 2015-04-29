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
  my $api_data = $object->get_evidence_data($object_slice,{});
  my $evidence_data = $api_data->{'data'};
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'cell asc', 'type asc', 'location asc' ]});
  
  $table->add_columns(
    { key => 'cell',     title => 'Cell type',     align => 'left', sort => 'string'   },
    { key => 'type',     title => 'Evidence type', align => 'left', sort => 'string'   },
    { key => 'feature',  title => 'Feature name',  align => 'left', sort => 'string'   },
    { key => 'location', title => 'Location',      align => 'left', sort => 'position' },
    { key => 'source',   title => 'Source',        align => 'left', sort => 'position' },
  ); 

  my @rows;

  foreach my $cell_line (sort keys %$evidence_data) {
#    next unless !defined($cells) or scalar(grep { $_ eq $cell_line } @$cells);
    my $core_features     = $evidence_data->{$cell_line}{'core'}{'block_features'};
    my $non_core_features = $evidence_data->{$cell_line}{'non_core'}{'block_features'};
    
    # Process core features first
    foreach my $features ($core_features, $non_core_features) {
      foreach my $f_set (sort { $features->{$a}[0]->start <=> $features->{$b}[0]->start } keys %$features) { 
        my $feature_name = [split /:/, $f_set]->[1];
        
        foreach my $f (sort { $a->start <=> $b->start } @{$features->{$f_set}}) {
          my $f_start = $object_slice->start + $f->start - 1;
          my $f_end   = $object_slice->start + $f->end   - 1;

          my $source_link = $self->hub->url({
            type => 'Experiment',
            action => 'Sources',
            ex => 'name-'.$f->feature_set->name
          });
          
          push @rows, { 
            type     => $f->feature_type->evidence_type_label,
            location => $f->slice->seq_region_name . ":$f_start-$f_end",
            feature  => $feature_name,
            cell     => $cell_line,
            source   => sprintf(q(<a href="%s">%s</a>),
                  $source_link,
                  $f->feature_set->source_label),
          };
          
          push @rows, @{$self->get_motif_rows($f, $cell_line)} if $features == $core_features;
        }
      }
    }
  }
  
  $table->add_rows(@rows);

#  $self->cell_line_button('reg_summary');

  if(scalar keys %$evidence_data) {
    return $table->render;
  } else {
    return "<p>There is no evidence for this regulatory feature in the selected cell lines</p>";
  }
}

sub get_motif_rows {
  my ($self, $f, $cell_line) = (@_);
  my $hub = $self->hub;
  my @motif_rows; 

  foreach my $mf (@{$f->get_associated_MotifFeatures}) {
    my @A = split /:/, $mf->display_label;
    my ($name, $binding_matrix_name) = $A[0], $A[-1];
    my $link = $hub->get_ExtURL_link($binding_matrix_name, 'JASPAR', $binding_matrix_name);
    $name .= " ($link)" if $link;

    push @motif_rows, {
      type     => $f->feature_type->evidence_type_label,
      location => $mf->seq_region_name . ':' . $mf->seq_region_start . '-' . $mf->seq_region_end,
      feature  => $name,
      cell     => $cell_line
    };
  }
  
  return \@motif_rows;
}

1;
