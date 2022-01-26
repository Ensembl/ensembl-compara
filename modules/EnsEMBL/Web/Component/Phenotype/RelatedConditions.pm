=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

package EnsEMBL::Web::Component::Phenotype::RelatedConditions;



use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::NewTable::NewTable;
use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::Component::Phenotype);
use Data::Dumper;
sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;

  my $html; 

  my $ontology_accession = $hub->param('oa');

  if ($ontology_accession) {
    my $html_legend = '';
    my $relation_types = $self->relation_types(" &quot;$ontology_accession&quot;");
    # Generate a legend for the releation icons
    foreach my $type ('equal', 'child', 'is_about') {
      $html_legend .= '<div style="line-height:22px">'.
                      '<img style="vertical-align:middle" src="'.$relation_types->{$type}{'icon'}.'"/>'.
                      '<span style="vertical-align:middle"> : '.$relation_types->{$type}{'help'}.'</span>'.
                      '</div>';
    }

    my $table = $self->make_table($ontology_accession);
    $html .= $table->render($hub,$self).$html_legend;
  }
  elsif ($hub->param('ph')) {
    if ($self->get_all_ontology_data) {
      $html .= '<h3>Please select an ontology accession in the form displayed above</h3>';
    }
  }
  else {
    my $msg = q{You need to specify an ontology accession ID in the URL, e.g. <a href="/Homo_sapiens/PhenotypeOntologyTerm/Summary?oa=EFO:0003900">.../Homo_sapiens/PhenotypeOntologyTerm/Summary?oa=EFO:0003900</a>};
    $html .= $self->_warning("Missing parameter!", $msg);
  }
}

sub table_content {
  my ($self,$callback) = @_;

  my $hub = $self->hub;

  my $ontology_accession = $hub->param('oa');
  
  my $adaptor = $self->hub->database('go')->get_OntologyTermAdaptor;

  my $ontologyterm_obj = $adaptor->fetch_by_accession($ontology_accession);
  return undef unless $ontologyterm_obj;

  # Get phenotypes associated with the ontology accession
  my %accessions = ($ontology_accession => $ontologyterm_obj->name);

  # Get phenotypes associated with the child terms of the ontology accession
  my $child_onto_objs = $adaptor->fetch_all_by_parent_term( $ontologyterm_obj );
  my %is_about;
  foreach my $child_onto (@{$child_onto_objs}){
    $accessions{$child_onto->accession} = $child_onto->name;
    my $parents = $child_onto->parents('is_about');
    foreach my $parent (@$parents) {
      if ($parent->accession eq $ontology_accession) {
        $is_about{$child_onto->accession} = 1;
      }
    }
  }
  
  return $self->get_phenotype_data($callback,\%accessions,\%is_about);
}

sub get_phenotype_data {
  my $self = shift;
  my $callback = shift;
  my $accessions = shift;
  my $is_about   = shift;

  my $hub = $self->hub;
 
  my $vardb   = $hub->database('variation');
  my $phen_ad = $vardb->get_adaptor('Phenotype');
  my $pf_ad   = $vardb->get_adaptor('PhenotypeFeature');

  my %ftypes = ('Variation' => 'var', 
                'Structural Variation' => 'sv',
                'Gene' => 'gene',
                'QTL' => 'qtl'
               );

  ROWS: foreach my $accession (keys(%$accessions)){
    my $phenotypes = $phen_ad->fetch_all_by_ontology_accession($accession);
    my $accession_term = $accessions->{$accession};

    foreach my $pheno (@{$phenotypes}){
      next if $callback->free_wheel();

      unless($callback->phase eq 'outline') {
        my $number_of_features = $pf_ad->count_all_type_by_phenotype_id($pheno->dbID());
        my $not_null = 0;
        
        
        my ($onto_acc_hash) = grep { $_->{'accession'} eq $accession } @{$pheno->{'_ontology_accessions'}};
        my $mapping_type = $onto_acc_hash->{'mapping_type'};

        my $onto_type;
        if ($accession eq $hub->param('oa')) {
          $onto_type = 'equal';
        }
        else {
          $onto_type = ($is_about->{$accession}) ? 'is_about' : 'child';
        }

        my $row = {
             ph          => $pheno->dbID,
             oa          => $accession,
             onto_relation  => $onto_type,
             onto_url    => $hub->url({ action => "Phenotype", action => "Locations",  oa => $accession, ph => undef }),
             onto_text   => $accession_term // $accession,
             description => $pheno->description,
             raw_desc    => $pheno->description,
             asso_type   => $mapping_type,
           };


        foreach my $type (keys(%ftypes)) {
          if ($number_of_features->{$type}) {
            $not_null = 1;
            my $count = $number_of_features->{$type};
            $row->{$ftypes{$type}."_count"} = $count;
          }
          else {
            $row->{$ftypes{$type}."_count"} = '-';
          }
        }
        next if ($not_null == 0);

        $callback->add_row($row);
        last ROWS if $callback->stand_down;
      }
    }
  }
}


sub make_table {
  my ($self,$ontology_accession) = @_;

  my $hub = $self->hub;

  my $ontology_accession = $hub->param('oa');

  my $adaptor = $self->hub->database('go')->get_OntologyTermAdaptor;
  my $ontologyterm_obj = $adaptor->fetch_by_accession($ontology_accession);

  my $onto_name = ($ontologyterm_obj) ? ' &quot;'.$ontologyterm_obj->name.'&quot;' : '';

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);

  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my @exclude;

  my @columns = ({
    _key => 'description', _type => 'string no_filter',
    label => "Phenotype/Disease/Trait description",
    width => 2,
    link_url => {
      'type'      => 'Phenotype',
      'action'    => 'Locations',
      'ph'        => ["ph"],
      __clear     => 1
    }
  },{
    _key => 'ph', _type => 'numeric unshowable no_filter'
  },{
    _key => 'oa', _type => 'numeric unshowable no_filter'
  },{
    _key => 'onto_url', _type => 'string no_filter unshowable',
  },{
    _key => 'onto_text', _type => 'iconic',
    label => 'Mapped ontology Term',
    url_column => 'onto_url',
    filter_label => 'Mapped ontology term',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 1,
    width => 2
  },{
    _key => 'onto_relation', _type => 'iconic',
    label => "Relationship with $ontology_accession",
    helptip => "Mapped ontology term relationship with $onto_name ($ontology_accession)"
  },{
    _key => 'var_count', _type => 'numeric no_filter',
    label => 'Variant',
    helptip => 'Variant phenotype association count',
    width => 1
  },{
    _key => 'sv_count', _type => 'numeric no_filter',
    label => 'Structural Variant',
    helptip => 'Structural Variant phenotype association count',
    width => 1
  },{
    _key => 'gene_count', _type => 'numeric no_filter',
    label => 'Gene',
    helptip => 'Gene phenotype association count',
    width => 1
  },{
    _key => 'qtl_count', _type => 'numeric no_filter',
    label => 'QTL',
    helptip => 'Quantitative trait loci (QTL) phenotype association count',
    width => 1
  });

  $table->add_columns(\@columns,\@exclude);

  # Set decorator for the ontology term releation
  my $onto_type = $table->column('onto_relation');
  my $relation_types = $self->relation_types($onto_name);
  foreach my $type ('equal', 'child', 'is_about') {
    $onto_type->icon_url($type, $relation_types->{$type}{'icon'});
    $onto_type->icon_helptip($type, $relation_types->{$type}{'help'});
  }

  return $table;
}

# Return the icon and help text regarding the ontology term relation
sub relation_types {
  my $self      = shift;
  my $onto_name = shift;

  my $types = { 'equal'    => { 'icon' => '/i/val/is_equal.png', 'help' => "Equivalent to the ontology term$onto_name" },
                'child'    => { 'icon' => '/i/val/tree.png',     'help' => "Child term of$onto_name"                   },
                'is_about' => { 'icon' => '/i/val/is_about.png', 'help' => "Term related to$onto_name"                 }
              };
  return $types;
}

1;

