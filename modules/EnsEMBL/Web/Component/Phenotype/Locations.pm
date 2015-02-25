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

package EnsEMBL::Web::Component::Phenotype::Locations;

### Module to replace Karyoview

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::Component::Location::Genome);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $ph_id     = $self->hub->param('ph');
  my $features  = {};
  my $error;

  ## Get features to draw
  try {
    $features = $object->convert_to_drawing_parameters if $ph_id && $object && $object->can('convert_to_drawing_parameters');
  } catch {
    if ($_->type eq 'TooManyFeatures') {
      $error = $self->_warning("Too many to display", $_->message(1));
    } else {
      throw $_;
    }
  };

  return $error if $error;
  return $self->_render_features([ $ph_id ], $features);
}

sub _configure_Gene_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->SUPER::_configure_Gene_table($feature_type, $feature_set);
  $info->{'header'} = 'Genes associated with phenotype '.$self->object->get_phenotype_desc;
  return $info; 
}

sub _configure_Variation_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];

  my $header = 'Features associated with phenotype '.$self->object->get_phenotype_desc;
  my $table_style = {'sorting' => ['p-values desc']};

  my $column_order = [qw(names loc)];
  my $column_info = {
    'names'       => {'label' => 'Name(s)', 'title' => 'Feature type ID (e.g. variant ID: rs123, gene ID:ENSG00000000001)', 'sort' => 'html'},
    'loc'         => {'label' => 'Genomic location (strand)', 'title' => 'Position of the feature (e.g. chromosome number, start and end coordinates, forward or reverse strand)', 'sort' => 'position_html'},
    'feat_type'   => {'label' => 'Feature type', 'title' => 'Variant, gene, or QTL'},
    'genes'       => {'label' => 'Reported gene(s)', 'title' => 'The gene reported to be associated with the phenotype'},
    'phe_sources' => {'label' => 'Annotation source(s)', 'title' => 'Project or database reporting the association'},
    'phe_studies' => {'label' => 'Study', 'title' => 'Link to the pubmed article or other source showing the association', 'sort' => 'html'},
    'p-values'    => {'label' => 'P value (negative log)', 'title' => 'The probability that the association is significant (a higher number indicates a higher probability)'},
  };

  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_pf_location_link($feature)},
              'names'   => {'value' => $self->_pf_link($feature)},
              'options' => {'class' => $feature->{'html_id'}},
              };

    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }
  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows,
          'custom_columns' => $column_info, 'table_style' => $table_style};
}
    
sub _pf_location_link {
  my ($self, $f) = @_;
  return 'Unmapped' unless $f->{'region'};
  my $coords = $f->{'region'}.':'.$f->{'start'}.'-'.$f->{'end'};
  
  my $type = lc($f->{'extra'}->{'feat_type'});
  my $link = sprintf(
          '<a href="%s">%s:%d-%d(%d)</a>',
          $self->hub->url({
            type    => 'Location',
            action  => 'View',
            r       => $coords,
            v       => $f->{'label'},
            ph      => $self->hub->param('ph'),
            contigviewbottom => 'phenotype_'.$type.'=gene_nolabel',
            __clear => 1,
          }),
          $f->{'region'}, $f->{'start'}, $f->{'end'},
          $f->{'strand'}
  );
  return $link;
}

sub _pf_link {
  my ($self, $f) = @_;
  
  my $type = $f->{'extra'}->{'feat_type'};
  
  my $link;
  
  # no links for SSVs yet, link to search
  if($type eq 'SupportingStructuralVariation') {
    my $params = {
      'type'   => 'Search',
      'action' => 'Results',
      'q'      => $f->{'label'},
      __clear  => 1
    };
    
    $link = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  }
  
  # link to ext DB for QTL
  elsif($type eq 'QTL') {
    my $source = $f->{'extra'}->{'phe_sources'};
    $source =~ s/ /\_/g;
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $self->hub->species)));
    
    $link = $self->hub->get_ExtURL_link(
      $f->{'label'},
      $source,
      { ID => $f->{'label'}, SP => $species}
    );
  }
  
  # link to gene or variation page
  else {
    # work out the ID param (e.g. v, g, sv)
    # TODO - get these from Controller::OBJECT_PARAMS (controller should be made accessible via Hub)
    my $id_param = $type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);

    my $display_label = '';
    if ($type eq 'Gene') {
      $display_label = $self->object->get_gene_display_label($f->{'label'});
      $display_label = " ($display_label)" if $display_label;

      # LRG
      if ($f->{'label'} =~ /(LRG)_\d+$/) {
        $type = $1;
        $id_param = lc($type);
      }
    }

    my $params = {
      'type'      => $type,
      'action'    => 'Phenotype',
      'ph'        => $self->hub->param('ph'),
      $id_param   => $f->{'label'},
      __clear     => 1
    };
  
    $link = sprintf('<a href="%s">%s%s</a>', $self->hub->url($params), $f->{'label'}, $display_label);
  }
  
  return $link;
}

1;
