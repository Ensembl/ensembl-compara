package EnsEMBL::Web::Object::Experiment;

### NAME: EnsEMBL::Web::Object::Experiment
### Web::Object drived object for Experiment tab

use strict;

use base qw(EnsEMBL::Web::Object);

sub new {
  ## @overrides
  ## @constructor
  ## Populates data from the database and caches them for further use, after creating the object
  my $self = shift->SUPER::new(@_);
  my $hub  = $self->hub;

  my $funcgen_db_adaptor          = $hub->database('funcgen');
  my $feature_set_adaptor         = $funcgen_db_adaptor->get_FeatureSetAdaptor;
  my $feature_type_adaptor        = $funcgen_db_adaptor->get_FeatureTypeAdaptor;
  my $binding_matrix_adaptor      = $funcgen_db_adaptor->get_BindingMatrixAdaptor;

  my $regulatory_evidence_labels  = $feature_type_adaptor->get_regulatory_evidence_labels;

  # Initialise summary filter caches
  my $all_cache           = {};
  my $cell_tissue_cache   = {};
  my $evidence_type_cache = {};
  my $project_cache       = {};
  my $feature_name_cache  = {};

  # Cache filters for each FeatureSet
  for my $feature_set (@{$feature_set_adaptor->fetch_all_displayable_by_type('annotated')}) {

    my $experiment = $feature_set->get_Experiment;
    if (!$experiment) {
      warn "Failed to get Experiment for FeatureSet:\t".$feature_set->name;
      next;
    }

    my $experiment_group  = $experiment->experimental_group;
    $experiment_group     = undef unless $experiment_group->is_project;
    my $project_name      = $experiment_group ? $experiment_group->name : '';
    my $project_url       = $experiment_group ? $experiment_group->url : '';
    my $source_info       = $experiment->source_info; # return [ source_label, source_link ]
    my $cell_type         = $feature_set->cell_type;
    my $cell_type_name    = $cell_type->name;
    my $feature_type      = $feature_set->feature_type;
    my $evidence_label    = $feature_type->evidence_type_label;
    my $feature_set_name  = $feature_set->name;

    my $feature_set_info  = {
      'source_label'        => $source_info->[0],
      'source_link'         => $source_info->[1],
      'project_name'        => $project_name,
      'project_url'         => $project_url,
      'evidence_label'      => $evidence_label,
      'cell_type_name'      => $cell_type_name,
      'efo_id'              => $cell_type->efo_id,
      'feature_set_name'    => $feature_set_name,
      'feature_type_name'   => $feature_type->name,
      'xref_genes'          => [ map $_->primary_id, @{$feature_type->get_all_Gene_DBEntries} ],
      'binding_motifs'      => [ map {$_->name} map { @{$binding_matrix_adaptor->fetch_all_by_FeatureType($_)} } ($feature_type, @{$feature_type->associated_feature_types}) ]
    };

    #Cache info wrt Cell/Tissue, Evidence types, project names and feature set name
    $all_cache->{'All'}                       ||= {'feature_sets' => [], 'description'  => 'All Experiments'                                            };
    $cell_tissue_cache->{$cell_type_name}     ||= {'feature_sets' => [], 'description'  => $cell_type->description                                      };
    $evidence_type_cache->{$evidence_label}   ||= {'feature_sets' => [], 'description'  => $regulatory_evidence_labels->{$evidence_label}{'long_name'}  };
    $project_cache->{$project_name}           ||= {'feature_sets' => [], 'description'  => $experiment_group ? $experiment_group->description : ''      };
    $feature_name_cache->{$feature_set_name}  ||= [];

    push @{$all_cache->{'All'}{'feature_sets'}},                      $feature_set_info;
    push @{$cell_tissue_cache->{$cell_type_name}{'feature_sets'}},    $feature_set_info;
    push @{$evidence_type_cache->{$evidence_label}{'feature_sets'}},  $feature_set_info;
    push @{$project_cache->{$project_name}{'feature_sets'}},          $feature_set_info;
    push @{$feature_name_cache->{$feature_set_name}},                 $feature_set_info;
  }

  $self->{'_feature_set_cache'} = {
    'All'           => $all_cache,
    'Cell/Tissue'   => $cell_tissue_cache,
    'Evidence Type' => $evidence_type_cache,
    'Project'       => $project_cache
  };
  
  $self->{'_feature_set_by_name_cache'} = $feature_name_cache;

  return $self;
}

sub short_caption {
  my $self = shift;
  if ($self->hub->param('ex') =~ /^name\-/) {
    my $feature_set_info = $self->get_feature_sets_info;
    if (@$feature_set_info) {
      return 'Experiment: '.$feature_set_info->[0]->{'feature_set_name'};
    }
  }
  return 'Experiment';
}

sub caption                   { 'Experiment'                          }
sub default_action            { 'Features'                            }
sub get_grouped_feature_sets  { return shift->{'_feature_set_cache'}; } ## Returns the cached hash for all feature type wrt Cell/Tissue, Evidence types and project names

sub get_feature_sets_info {
  ## Gets the array of all information about all feature sets saved in the cache, according to the url param 'ex'
  ## @return ArrayRef
  my $self    = shift;
  my $param   = $self->hub->param('ex');

  if ($param =~ /^([^\-]+)\-(.+)$/) {

    return $self->{'_feature_set_by_name_cache'}{$2} || [] if $1 eq 'name';
    return $self->{'_feature_set_cache'}{$self->get_filter_from_url_param($1)}{$2}{'feature_sets'} || [];
  }
  return [];
}

sub get_url_param_for_filter {
  ## Takes a filter name and returns corresponding param name for the url
  ## @param Filter name - as in keys on the cached hash
  ## @return String to go inside the URL param 'ex' as value
  my ($self, $filter, $_reverse) = @_;
  my $map = {'All' => 'All', 'Cell/Tissue' => 'CellTissue', 'Evidence Type' => 'EvidenceType', 'Project' => 'Project'};
  if ($_reverse) {
    return {reverse %{$map}}->{$filter};
  }
  return $map->{$filter};
}

sub get_filter_from_url_param {
  ## Takes a param name for the url and returns corresponding filter name
  ## @param Prifix in the value of param 'ex'
  ## @return String Filter name - as in keys on the cached hash
  my ($self, $param) = @_;
  return $self->get_url_param_for_filter($param, 1);
}

1;