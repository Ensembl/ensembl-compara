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

package EnsEMBL::Web::Component::Experiment::Features;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Experiment);


sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;
  my $table   = $self->new_table(
    [
      { 'key' => 'source',        'title' => 'Source'                     },
      { 'key' => 'project',       'title' => 'Project'                    },
      { 'key' => 'evidence_type', 'title' => 'Evidence Type'              },
      { 'key' => 'cell_type',     'title' => 'Cell type'                  },
      { 'key' => 'feature_type',  'title' => 'Evidence'                   },
      { 'key' => 'gene',          'title' => 'Transcription Factor Gene'  },
      { 'key' => 'motif',         'title' => 'PWMs'                       }
    ],
    [],
    {'data_table' => 1}
  );

  my $feature_sets_info = $object->get_feature_sets_info;

  for my $feature_set_info (@$feature_sets_info) {
    (my $evidence_type = encode_entities($feature_set_info->{'evidence_label'})) =~ s/\s/&nbsp;/g;

    my @links;
    foreach my $source (@{$feature_set_info->{'source_info'}}){
     push @links, $self->source_link($source->[0], $source->[1],
                    $feature_set_info->{'experimental_group'});
    }
    my $source_link  = join ' ', @links;
    
    $table->add_row({
      'source'        => $source_link,
      'project'       => $self->project_link($feature_set_info->{'project_name'}, $feature_set_info->{'project_url'} || ''),
      'evidence_type' => $evidence_type,
      'cell_type'     => $self->cell_type_link($feature_set_info->{'cell_type_name'}, $feature_set_info->{'efo_id'}),
      'feature_type'  => $self->evidence_link($feature_set_info->{'feature_type_name'}),
      'gene'          => $self->gene_links($feature_set_info->{'xref_genes'}),
      'motif'         => $self->motif_links($feature_set_info->{'binding_motifs'}),
    });
  }

  my $total_experiments = $object->total_experiments;
  my $shown_experiments = @$feature_sets_info;
  my $html              = sprintf('<a name="%s"></a>', $object->URL_ANCHOR);
  if ($object->is_single_feature_view) {
    $html = "<p>Showing a single experiment out of $total_experiments experiments</p>";
  }
  elsif ($total_experiments == $shown_experiments) {
    $html .= "<p>Showing all $total_experiments experiments</p>";
  }
  else {
    my $applied_filters = $object->applied_filters;
    my $display_filters = {};
    for my $filter_key (sort keys %$applied_filters) {
      my $filter_title = $object->get_filter_title($filter_key);
      $display_filters->{$filter_title} = [ map sprintf('%s (<a href="%s">remove</a>)',
        $_,
        $object->get_url({$filter_title, $_}, -1),
      ), @{$applied_filters->{$filter_key}} ];
    }

    $html .= sprintf('<p>Showing %s/%s experiments</p><div class="tinted-box"><p class="half-margin">Filters applied: %s</p></div>',
       $shown_experiments,
       $total_experiments,
       join('; ', map sprintf('%s', join '; ', (@{$display_filters->{$_}})), sort keys %$display_filters)
    );
  }

  return $html.$table->render;
}

sub source_link {
  my ($self, $source_label, $source_link,$project_name) = @_;

  unless($source_link) {
    $source_link = $self->hub->source_url("REGSRC_".uc($project_name),{
      ID => $source_label,
    });
  }

  return $source_link
    ? sprintf('<a href="%s" title="View source">%s</a>',
      encode_entities($source_link),
      encode_entities($source_label)
    )
    : encode_entities($source_label)
  ;
}

sub project_link {
  my ($self, $project_name, $project_link) = @_;
  ($project_name = encode_entities($project_name)) =~ s/\s/&nbsp;/g;
  return $project_link
    ? sprintf('<a href="%s" title="View Project\'s webpage">%s</a>',
      encode_entities($project_link),
      $project_name
    )
    : $project_name
  ;
}

sub cell_type_link {
  my ($self, $ctype_name, $efo_id) = @_;
  return $efo_id
    ? sprintf('<a href="http://bioportal.bioontology.org/ontologies/46432?p=terms&amp;conceptid=%s" title="View Experimental Factor Ontology for %s on BioPortal">%2$s</a>',
      encode_entities($efo_id),
      encode_entities($ctype_name)
    )
    : encode_entities($ctype_name)
  ;
}

sub evidence_link {
  my ($self, $feature_type_name) = @_;
  my $object = $self->object;

  return $object->is_feature_type_filter_on
    ? encode_entities($feature_type_name)
    : sprintf('<a href="%s" title="%s experiments with feature type name %s">%3$s</a>',
        $object->get_url({'feature_type' => $feature_type_name}, 1),
        $object->is_filter_applied ? 'Filter' : 'View all', 
        encode_entities($feature_type_name),
    )
  ;
}

sub motif_links {
  my ($self, $pfms) = @_;
  return join ', ', map sprintf('<a class="_motif" href="#">%s</a>', $_->stable_id), @$pfms;
}

sub gene_links {
  my ($self, $genes) = @_;
  my $hub = $self->hub;
  return $self->join_with_and(map sprintf('<a href="%s" title="View gene">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_, 'db' => 'core'}), $_), @$genes);
}

1;
