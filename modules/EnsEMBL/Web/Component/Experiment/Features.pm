package EnsEMBL::Web::Component::Experiment::Features;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Experiment);

sub caption       { 'Experimental Meta Data' }
sub short_caption { 'Experimental Meta Data' }

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
    $table->add_row({
      'source'        => $feature_set_info->{'source_link'} ? sprintf('<a href="%s">%s</a>', $feature_set_info->{'source_link'}, $feature_set_info->{'source_label'}) : $feature_set_info->{'source_label'},
      'project'       => $feature_set_info->{'project_url'} ? sprintf('<a href="%s">%s</a>', $feature_set_info->{'project_url'}, $feature_set_info->{'project_name'}) : $feature_set_info->{'project_name'},
      'evidence_type' => $feature_set_info->{'evidence_label'},
      'cell_type'     => $feature_set_info->{'cell_type_name'},
      'feature_type'  => $feature_set_info->{'feature_type_name'},
      'gene'          => join(', ', map {sprintf('<a href="%s">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_}), $_)} @{$feature_set_info->{'xref_genes'}} ),
      'motif'         => join(', ', map {sprintf('<a href="%s">%s</a>', $self->motif_link($_), $_)} @{$feature_set_info->{'binding_motifs'}} ),
    });
  }

  my $total_experiments = $object->total_experiments;
  my $shown_experiments = @$feature_sets_info;
  my $html;
  if ($object->is_single_feature_view) {
    $html = "Showing single experiment out of $total_experiments experiments";
  }
  elsif ($total_experiments == $shown_experiments) {
    $html = "Showing all  $total_experiments experiments";
  }
  else {
    my @filters = values %{$object->applied_filters};
    $html = sprintf('<p class="space-below">Filters applied: %s</p><p class="space-below">Showing %s/%s experiments</p>',
       join(' and ', reverse (pop(@filters), join(', ', @filters) || ())),
       $shown_experiments,
       $total_experiments
    );
  }

  return $html.$table->render;
}

sub motif_link {
  ## TODO?
  return "http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=$_[1]&rm=present&collection=CORE";
}

1;