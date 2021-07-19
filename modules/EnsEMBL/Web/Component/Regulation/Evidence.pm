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
    { key => 'source',   title => 'Source',        align => 'left', sort => 'position' },
  ); 

  my @rows;

  foreach my $cell_line (sort keys %$evidence_data) {
    my $experiments = $evidence_data->{$cell_line};
    foreach my $experiment (sort keys %$experiments) {
      my $peak_calling = $experiments->{$experiment};
      next unless (ref($peak_calling) =~ /PeakCalling/);
      my $feature_type = $peak_calling->get_FeatureType;
      my $feature_name = $feature_type->name;
    
      my $source_link = $self->hub->url({
            type => 'Experiment',
            action => 'Sources',
            ex => 'name-'.$peak_calling->name
      });
       
      push @rows, { 
        type     => $feature_type->evidence_type_label,
        feature  => $feature_name,
        cell     => $cell_line,
        source   => sprintf(q(<a href="%s">%s</a>),
                  $source_link,
                  $peak_calling->get_source_label),
      };
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


1;
