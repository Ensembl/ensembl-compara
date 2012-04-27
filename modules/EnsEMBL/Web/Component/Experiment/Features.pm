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
    my $source_label  = encode_entities($feature_set_info->{'source_label'});
    my $source_link   = encode_entities($feature_set_info->{'source_link'} || '');
    my $project_name  = encode_entities($feature_set_info->{'project_name'});
    my $project_link  = encode_entities($feature_set_info->{'project_url'} || '');
    my $evidence_type = encode_entities($feature_set_info->{'evidence_label'});
    my $ctype_name    = encode_entities($feature_set_info->{'cell_type_name'});
    my $ftype_name    = encode_entities($feature_set_info->{'feature_type_name'});

    $source_link    ||= $self->srx_link($source_label) if $source_label =~ /^SRX/;
    $evidence_type    =~ s/\s/&nbsp;/g;
    $project_name     =~ s/\s/&nbsp;/g;

    my $filters       = {
      'project_name'    => $object->is_filter_applied('project', $feature_set_info->{'project_name'}),
      'evidence_label'  => $object->is_filter_applied('evidence_type', $feature_set_info->{'evidence_label'}),
      'cell_type'       => $object->is_filter_applied('cell_type', $feature_set_info->{'cell_type_name'}),
      'feature_type'    => $object->is_single_feature_type_name_view
    };

    $table->add_row({
      'source'        => $source_link  ? sprintf('<a href="%s">%s</a>', $source_link, $source_label) : $source_label,
      'project'       => !$project_name ? '' : sprintf('%s <a class="hover_show" href="%s" title="View all experiments with project: %s">%s filter</a>',
        $project_link ? sprintf('<a href="%s">%s</a>', $project_link, $project_name) : $project_name,
        $hub->url({'ex' => $object->get_url_param({'project' => $feature_set_info->{'project_name'}}, $filters->{'project_name'} ? -1 : 0)}),
        $project_name,
        $filters->{'project_name'} ? 'remove' : 'apply'
      ),
      'evidence_type' => sprintf('%s <a class="hover_show" href="%s" title="View all experiments with evidence type: %1$s">%s filter</a>',
        $evidence_type,
        $hub->url({'ex' => $object->get_url_param({'evidence_type' => $feature_set_info->{'evidence_label'}}, $filters->{'evidence_type'} ? -1 : 0)}),
        $filters->{'evidence_type'} ? 'remove' : 'apply'
      ),
      'cell_type'     => sprintf('%s <a class="hover_show" href="%s" title="View all experiments with cell type: %s">%s filter</a>',
        sprintf('<a href="%s">%s</a>', $self->efo_link(encode_entities($feature_set_info->{'efo_id'})), $ctype_name),
        $hub->url({'ex' => $object->get_url_param({'cell_type' => $feature_set_info->{'cell_type_name'}}, $filters->{'cell_type'} ? -1 : 0)}),
        $ctype_name,
        $filters->{'cell_type'} ? 'remove' : 'apply'
      ),
      'feature_type'  => sprintf('%s <a class="hover_show" href="%s" title="View all experiments with feature type name: %1$s">%s filter</a>',
        $ftype_name,
        $hub->url({'ex' => $object->get_url_param($filters->{'feature_type'} ? {} : {'ftname' => $feature_set_info->{'feature_type_name'}})}),
        $filters->{'feature_type'} ? 'remove' : 'apply'
      ),
      'gene'          => join(', ', map {sprintf('<a href="%s">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_}), $_)} @{$feature_set_info->{'xref_genes'}} ),
      'motif'         => join(', ', map {sprintf('<a href="%s">%s</a>', $self->motif_link($_), $_)} @{$feature_set_info->{'binding_motifs'}} ),
    });
  }

  my $total_experiments = $object->total_experiments;
  my $shown_experiments = @$feature_sets_info;
  my $html;
  if ($object->is_single_feature_view) {
    $html = "Showing a single experiment out of $total_experiments experiments";
  }
  elsif ($object->is_single_feature_type_name_view) {
    $html = sprintf('%s&nbsp;(<a href="%s" title="Show all experiments">%s</a>)',
      $shown_experiments
        ? sprintf('Showing %s experiments with feature type name: %s', $shown_experiments, encode_entities($feature_sets_info->[0]{'feature_type_name'}))
        : 'No experiment found for the given feature type name.',
      $hub->url({'ex' => $object->get_url_param({})}),
      $shown_experiments ? 'Remove Filter' : 'Show all');
  }
  elsif ($total_experiments == $shown_experiments) {
    $html = "Showing all  $total_experiments experiments";
  }
  else {
    my $applied_filters = $object->applied_filters;
    my $display_filters = {};
    for my $filter_key (sort keys %$applied_filters) {
      my $filter_title = $object->get_filter_title($filter_key);
      $display_filters->{$filter_title} = [ map sprintf('%s (<a href="%s">remove</a>)', $_, $hub->url({'ex' => $object->get_url_param({$filter_title, $_}, -1)})), @{$applied_filters->{$filter_key}} ];
    }

    $html = sprintf('<p class="space-below">Showing %s/%s experiments</p><p class="space-below">Filters applied: %s</p>',
       $shown_experiments,
       $total_experiments,
       join('', map sprintf('<p class="space-below"><b>%s</b>: %s</p>', $_, join(' and ', reverse (pop(@{$display_filters->{$_}}), join(', ', @{$display_filters->{$_}}) || ()))), sort keys %$display_filters)
    );
  }

  return $html.$table->render;
}

sub motif_link {
  ## TODO - move somewhere else
  return "http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=$_[1]&amp;rm=present&amp;collection=CORE";
}

sub srx_link {
  ## TODO - move somewhere else
  return "http://www.ebi.ac.uk/ena/data/view/$_[1]";
}

sub efo_link {
  ## TODO - move somewhere else
  return "http://bioportal.bioontology.org/ontologies/46432?p=terms&amp;conceptid=$_[1]";
}

1;