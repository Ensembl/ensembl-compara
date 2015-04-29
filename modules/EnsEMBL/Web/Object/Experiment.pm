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

package EnsEMBL::Web::Object::Experiment;

### NAME: EnsEMBL::Web::Object::Experiment
### Web::Object drived object for Experiment tab

use strict;

use base qw(EnsEMBL::Web::Object);

use constant URL_ANCHOR => 'ExperimentalMetaData';

sub new {
  ## @overrides
  ## @constructor
  ## Populates the data from the db and caches it before returning the object
  my $self                  = shift->SUPER::new(@_);
  my $hub                   = $self->hub;
  my $param                 = $hub->param('ex');

  my $funcgen_db_adaptor    = $hub->database('funcgen');
  my $feature_set_adaptor   = $funcgen_db_adaptor->get_FeatureSetAdaptor;
  my $feature_type_adaptor  = $funcgen_db_adaptor->get_FeatureTypeAdaptor;

  my $param_to_filter_map   = $self->{'_param_to_filter_map'}   = {'all' => 'All', 'cell_type' => 'Cell/Tissue', 'evidence_type' => 'Evidence type', 'project' => 'Project', 'feature_type' => 'Feature type'};
  my $grouped_feature_sets  = $self->{'_grouped_feature_sets'}  = $funcgen_db_adaptor->get_FeatureSetAdaptor->fetch_feature_set_filter_counts;
  my $feature_sets_info     = $self->{'_feature_sets_info'}     = [];
  my $feature_sets          = [];

  $self->{'_filter_to_param_map'} = { reverse %{$self->{'_param_to_filter_map'}} };

  # Get the feature set according to the url param
  if ($param =~ /^name\-(.+)$/) {
    $feature_sets = [ $feature_set_adaptor->fetch_by_name($1) || () ];
  }
  else {
    my $constraints = {};
    if ($param ne 'all') {

      my $filters = $self->applied_filters($param);

      while (my ($filter, $value) = each(%$filters)) {
        if ($filter eq 'cell_type') {
          my $cell_type_adaptor = $funcgen_db_adaptor->get_CellTypeAdaptor;
          $constraints->{'cell_types'} = [ map $cell_type_adaptor->fetch_by_name($_), @$value ];
        }
        elsif ($filter eq 'evidence_type') {
          $constraints->{'evidence_types'} = $value;
        }
        elsif ($filter eq 'project') {
          my $experimental_group_adaptor = $funcgen_db_adaptor->get_ExperimentalGroupAdaptor;
          $constraints->{'projects'} = [ map $experimental_group_adaptor->fetch_by_name($_), @$value ];
        }
        elsif ($filter eq 'feature_type') {
          $constraints->{'feature_types'} = [ map $feature_type_adaptor->fetch_by_name($_), @$value ];
        }
      }
    }
    $feature_sets = $feature_set_adaptor->fetch_all_displayable_by_type('annotated', keys %$constraints ? {'constraints' => $constraints} : ());
  }

  my $binding_matrix_adaptor = $funcgen_db_adaptor->get_BindingMatrixAdaptor;

  # Get info for all feature sets and pack it in an array of hashes
  foreach my $feature_set (@$feature_sets) {

    my $experiment = $feature_set->experiment;

    if (! defined $experiment) {
      warn "Failed to get Experiment for FeatureSet:\t".$feature_set->name;
      next;
    }

    my $experiment_group  = $experiment->experimental_group;
    $experiment_group     = undef unless $experiment_group->is_project;
    my $project_name      = $experiment_group ? $experiment_group->name : '';
    my $source_info       = $experiment->source_info; # returns [[source_label, source_link], [source_label, source_link], ...]
    my $cell_type         = $feature_set->cell_type;
    my $cell_type_name    = $cell_type->name;
    my $feature_type      = $feature_set->feature_type;
    my $evidence_label    = $feature_type->evidence_type_label;

    push @$feature_sets_info, {
      'source_info'         => $source_info,
      'project_name'        => $project_name,
      'project_url'         => $experiment_group ? $experiment_group->url : '',
      'feature_set_name'    => $feature_set->name,
      'feature_type_name'   => $feature_type->name,
      'evidence_label'      => $evidence_label,
      'cell_type_name'      => $cell_type_name,
      'efo_id'              => $cell_type->efo_id,
      'xref_genes'          => [ map $_->primary_id, @{$feature_type->get_all_Gene_DBEntries} ],
      'binding_motifs'      => [ map {$_->name} map { @{$binding_matrix_adaptor->fetch_all_by_FeatureType($_)} } ($feature_type, @{$feature_type->associated_feature_types}) ]
    };

    $cell_type_name and $grouped_feature_sets->{'Cell/Tissue'}{$cell_type_name}{'filtered'}++;
    $evidence_label and $grouped_feature_sets->{'Evidence type'}{$evidence_label}{'filtered'}++;
    $project_name   and $grouped_feature_sets->{'Project'}{$project_name}{'filtered'}++;
  }

  return $self;
}

sub short_caption   { 'Experiment'  }
sub caption         { 'Experiment Sources Summary'  }
sub default_action  { 'Sources'     }

sub get_grouped_feature_sets {
  ## Gets a data structure of feature sets grouped according to Project, Cell/Tissue and Evidence Type
  ## @return HashRef with keys Project, Cell/Tissue, Evidence Type and All
  return shift->{'_grouped_feature_sets'};
}

sub get_feature_sets_info {
  ## Gets the array of all information about all feature sets according to the url param 'ex'
  ## @return ArrayRef
  return shift->{'_feature_sets_info'};
}

sub is_single_feature_view {
  ## Tells whether a single feature should be displayed - acc to the ex param
  my $self = shift;
  return $self->hub->param('ex') =~ /^name\-/ ? 1 : undef;
}

sub is_feature_type_filter_on {
  ## Tells whether feature type filter is applied
  my $self    = shift;
  my $filters = $self->applied_filters;
  return exists $filters->{'feature_type'};
}

sub total_experiments {
  ## Gets the number of all experiments without any filter applied
  ## @return int
  return shift->{'_grouped_feature_sets'}{'All'}{'All'}{'count'} || 0;
}

sub applied_filters {
  ## Returns the filters applied to filter the feature sets info
  ## @return HashRef with keys as filter names
  my $self = shift;

  if (@_) {
    my $param   = shift;
    my $filters = $self->{'_param_filters'} = [];
    for (split chop $param, $param) {
      if (exists $self->{'_param_to_filter_map'}->{$_}) {
        push @$filters, $_, {};
      }
      else {
        $_ and ref $filters->[-1] and $filters->[-1]{$_} = 1;
      }
    }
  }

  return { map {ref $_ ? [ keys %$_ ] : $_} @{$self->{'_param_filters'} || []} };
}

sub is_filter_applied {
  ## Checks whether a filter is already applied or not
  ## @return 1 or undef accordingly
  my $self    = shift;
  my $filters = $self->applied_filters;

  # If a specific filter not provided
  return scalar keys %$filters ? 1 : 0 unless @_;

  my ($filter_name, $value) = @_;

  # if filter param is provided
  if ($filter_name) {
    $_ eq $value and return 1 for @{$filters->{$filter_name} || []};
  }

  # if filter title is provided
  if ($filter_name = $self->{'_filter_to_param_map'}{$filter_name}) {
    $_ eq $value and return 1 for @{$filters->{$filter_name} || []};
  }
  return undef;
}

sub get_filter_title {
  ## Returns the title for a filter param based upon the param_to_filter_map
  ## @param Filter param
  ## @return Filter title or blank string
  return shift->{'_param_to_filter_map'}{pop @_};
}

sub get_url {
  ## Takes filter name(s) and value(s) and returns corresponding url
  ## @param Hashref with keys as filter names (or params) and values as filter values
  ## @param Flag to tell whether to add, remove the given filters from existing filters, or ignore the existing filters
  ##  - 0  Ignore the existing filters
  ##  - 1  Add the given filters to existing ones
  ##  - -1 Remove the given filters from the existing ones
  ## @return URL string
  my ($self, $filters, $flag) = @_;

  my $param;

  # All
  if (!scalar keys %$filters || exists $filters->{'All'}) {
    $param = 'all';

  # Other filters
  } else {
    my $params = $flag ? $self->applied_filters : {};
    while (my ($filter, $value) = each %$filters) {
      my $param_for_filter = exists $self->{'_param_to_filter_map'}{$filter} ? $filter : $self->{'_filter_to_param_map'}{$filter};
      if ($param_for_filter) {
        $params->{$param_for_filter} ||= [];
        if ($flag >= 0) {
          push @{$params->{$param_for_filter}}, $value;
        }
        else {
          $params->{$param_for_filter} = [ map {$_ eq $value ? () : $_} @{$params->{$param_for_filter}} ];
          delete $params->{$param_for_filter} unless @{$params->{$param_for_filter}};
        }
      }
    }
  
    my $param_str   = join '', map {ref $_ ? @$_ : $_} %$params;
    my $delimiters  = [ qw(_ ,), ('a'..'z'), ('A'..'Z'), (1..9) ];
    my $counter     = 0;
    my $delimiter   = '-';
    $delimiter      = $delimiters->[$counter++] while $delimiter && index($param_str, $delimiter) >= 0;
  
    $param = join($delimiter, (map {$_, sort @{$params->{$_}}} sort keys %$params), '') || 'all';
  }

  return sprintf('%s#%s', $self->hub->url({'ex' => $param}), $self->URL_ANCHOR);
}

1;
