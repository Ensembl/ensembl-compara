=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Gene::ComparaTree;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub _new {
  ## @override
  ## Code depends upon referer
  ## TODO use of hub->referer should go away
  my $self = shift->SUPER::_new(@_);

  $self->{'function'} = $self->hub->referer->{'ENSEMBL_FUNCTION'};
  $self->{'code'}     = join '::', 'Gene::ComparaTree', $self->{'function'} || ();

  return $self;
}

sub init_cacheable {
  ## @override
  my $self = shift;

  my $defaults = {
    'collapsability'  => 'gene',
    'clusterset_id'   => 'default',
    'colouring'       => 'background',
    'exons'           => 'on',
    'super_tree'      => 'off',
  };

  # This config is stored in DEFAULTS.ini
  my $species_defs = $self->hub->species_defs;
  my @bg_col = @{ $species_defs->TAXON_GENETREE_BGCOLOUR };
  my @fg_col = @{ $species_defs->TAXON_GENETREE_FGCOLOUR };
  foreach my $name ( @{ $species_defs->TAXON_ORDER } ) {
    my $this_bg_col = shift @bg_col || 0;
    my $this_fg_col = shift @fg_col || 0;
    $defaults->{"group_${name}_bgcolour"} = $this_bg_col if $this_bg_col ne '0';
    $defaults->{"group_${name}_fgcolour"} = $this_fg_col if $this_fg_col ne '0';
    $defaults->{"group_${name}_display"} = 'default';
  }

  $self->set_default_options($defaults);
  $self->image_config_type('genetreeview');
  $self->title('Gene Tree');
}

sub field_order {
  ## Abstract method implementation
  my $self = shift;

  return qw(collapsability clusterset_id exons super_tree colouring), map sprintf('group_%s_display', $_), $self->_groups;
}

sub form_fields {
  ## Abstract method implementation
  my $self      = shift;
  my $fields    = {};
  my $function  = $self->{'function'};

  $fields->{'collapsability'} = {
    'type'    => 'dropdown',
    'select'  => 'select',
    'name'    => 'collapsability',
    'label'   => 'Display options for tree image',
    'values'  => [
      { 'value' => 'gene',         'caption' => 'Show current gene only'        },
      { 'value' => 'paralogs',     'caption' => 'Show paralogs of current gene' },
      { 'value' => 'duplications', 'caption' => 'Show all duplication nodes'    },
      { 'value' => 'all',          'caption' => 'Show fully expanded tree'      }
    ],
  };

  $fields->{'clusterset_id'} = {
    'type'    => 'dropdown',
    'name'    => 'clusterset_id',
    'label'   => 'Model used for the tree reconstruction',
    'values'  => [ { 'value' => 'default', 'caption' => 'Final (merged) tree' } ], # more values inserted by init_form_non_cacheable method
  };

  $fields->{'exons'} = {
    'type'  => 'checkbox',
    'label' => 'Show exon boundaries',
    'name'  => 'exons',
    'value' => 'on',
  };

  $fields->{'super_tree'} = {
    'type'  => 'checkbox',
    'label' => 'Show super-tree',
    'name'  => 'super_tree',
    'value' => 'on',
  };

  my @groups = ($self->hub->param('strain') || $self->hub->species_defs->IS_STRAIN_OF) ? () : $self->_groups; #hide these options for strain view or strain species

  if (@groups) {
    my $taxon_labels = $self->hub->species_defs->TAXON_LABEL;

    $fields->{'colouring'} = {
      'type'    => 'dropdown',
      'select'  => 'select',
      'name'    => 'colouring',
      'label'   => 'Colour tree according to taxonomy',
      'values'  => [
        { 'value' => 'none',       'caption' => 'No colouring'  },
        { 'value' => 'background', 'caption' => 'Background'    },
        { 'value' => 'foreground', 'caption' => 'Foreground'    }
      ],
    };

    foreach my $group (@groups) {
      $fields->{"group_${group}_display"} = {
        'type'    => 'dropdown',
        'select'  => 'select',
        'name'    => "group_${group}_display",
        'label'   => "Display options for ".($taxon_labels && $taxon_labels->{$group} || $group),
        'values'  => [
          { 'value' => 'default',  'caption' => 'Default behaviour' },
          { 'value' => 'hide',     'caption' => 'Hide genes'        },
          { 'value' => 'collapse', 'caption' => 'Collapse genes'    }
        ],
      };
    }
  }

  return $fields;
}

sub init_form_non_cacheable {
  ## @override
  my $self  = shift;
  my $cdb   = shift || $self->{'cdb'} || 'compara';
  my $hub   = $self->hub;
  my $form  = $self->SUPER::init_form_non_cacheable(@_);
  my %other_clustersets;

  if($hub->param('g')) {
    my $database           = $hub->database($cdb);
    my $member             = $database->get_GeneMemberAdaptor->fetch_by_stable_id($hub->core_params->{'g'});
    my $adaptor            = $database->get_GeneTreeAdaptor;
    my $gene_tree          = $adaptor->fetch_default_for_Member($member);
    %other_clustersets     = map { $_->clusterset_id => 1 } @{$adaptor->fetch_all_linked_trees($gene_tree)};

    delete $other_clustersets{'default'};
  }

  if (my $dropdown = $form->get_elements_by_name('clusterset_id')->[0]) {
    $dropdown->add_option({ 'value' => $_, 'caption' => $_ }) for sort keys %other_clustersets;
  }

  return $form;
}

sub _groups {
  ## @private
  return (@{ $_[0]->species_defs->TAXON_ORDER });
}

1;
