package EnsEMBL::Web::Component::Experiment::Features;

use strict;

use base qw(EnsEMBL::Web::Component::Experiment);

sub caption       {'Exeriment'}
sub short_caption {'Exeriment'}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;
  my $table   = $self->new_table(
    [
      { 'key' => 'source',        'title' => 'Source'         },
      { 'key' => 'project',       'title' => 'Project'        },
      { 'key' => 'evidence_type', 'title' => 'Evidence Type'  },
      { 'key' => 'cell_type',     'title' => 'Cell type'      },
      { 'key' => 'feature_name',  'title' => 'Feature name'   },
      { 'key' => 'gene',          'title' => 'Gene'           },
      { 'key' => 'motif',         'title' => 'Binding Motifs' }
    ],
    [],
    {'data_table' => 1}
  );

  for my $feature_set_info (@{$object->get_feature_sets_info}) {
    $table->add_row({
      'source'        => $feature_set_info->{'source_link'} ? sprintf('<a href="%s">%s</a>', $feature_set_info->{'source_link'}, $feature_set_info->{'source_label'}) : $feature_set_info->{'source_label'},
      'project'       => $feature_set_info->{'project_url'} ? sprintf('<a href="%s">%s</a>', $feature_set_info->{'project_url'}, $feature_set_info->{'project_name'}) : $feature_set_info->{'project_name'},
      'evidence_type' => $feature_set_info->{'evidence_label'},
      'cell_type'     => $feature_set_info->{'cell_type_name'},
      'feature_name'  => $feature_set_info->{'feature_type_name'},
      'gene'          => join(', ', @{ [ map {sprintf('<a href="%s">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_}), $_)} @{$feature_set_info->{'xref_genes'}} ] }),
      'motif'         => join(', ', @{ [ map {sprintf('<a href="%s">%s</a>', $self->motif_link($_), $_)} @{$feature_set_info->{'binding_motifs'}} ] }),
    });
  }

  return $table->render;
}

sub motif_link {
  ## TODO?
  return "http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=$_[1]&rm=present&collection=CORE";
}

1;