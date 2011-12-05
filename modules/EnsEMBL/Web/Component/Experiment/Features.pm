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

    $source_link    ||= $self->srx_link($source_label) if $source_label =~ /^SRX/;
    $evidence_type    =~ s/\s/&nbsp;/g;
    $project_name     =~ s/\s/&nbsp;/g;

    $table->add_row({
      'source'        => $source_link  ? sprintf('<a href="%s">%s</a>', $source_link, $source_label) : $source_label,
      'project'       => $project_link ? sprintf('<a href="%s">%s</a>', $project_link, $project_name) : $project_name,
      'evidence_type' => $evidence_type,
      'cell_type'     => sprintf('<a href="%s">%s</a>', $self->efo_link(encode_entities($feature_set_info->{'efo_id'})), encode_entities($feature_set_info->{'cell_type_name'})),
      'feature_type'  => encode_entities($feature_set_info->{'feature_type_name'}),
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