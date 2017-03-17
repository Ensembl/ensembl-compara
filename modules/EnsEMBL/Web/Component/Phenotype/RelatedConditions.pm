=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute
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
    my $table = $self->make_table($ontology_accession);
    $html .= $table->render($hub,$self);
  }
  elsif ($hub->param('ph')) {
    $html .= '<h3>Please select an ontology accession in the form displayed above</h3>';
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

  foreach my $child_onto (@{$child_onto_objs}){
    $accessions{$child_onto->accession} = $child_onto->name;
  }
  
  return $self->get_phenotype_data($callback,\%accessions);
}

sub get_phenotype_data {
  my $self = shift;
  my $callback = shift;
  my $accessions = shift;

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
        my $row = {
             ph          => $pheno->dbID,
             oa          => $accession,
             onto_type   => ($accession eq $hub->param('oa'))?'equal':'child',
             onto_url    => $self->external_ontology($accession,$accession_term),
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
    _key => 'onto_type', _type => 'iconic no_filter unshowable',
    label => 'Ontology Term',
  },{
    _key => 'onto_url', _type => 'string no_filter unshowable',
    label => 'Ontology Term',
    width => 2,
  },{
    _key => 'onto_text', _type => 'iconic',
    label => 'Ontology Term',
    icon_source => 'onto_type',
    url_column => 'onto_url',
    url_rel => 'external',
    filter_label => 'Mapped ontology term',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 1,
    width => 2,
  },{
    _key => 'var_count', _type => 'string no_filter',
    label => 'Variant',
    helptip => 'Variant phenotype association count',
    width => 1
  },{
    _key => 'sv_count', _type => 'string no_filter',
    label => 'Structural Variant',
    helptip => 'Structural Variant phenotype association count',
    width => 1
  },{
    _key => 'gene_count', _type => 'string no_filter',
    label => 'Gene',
    helptip => 'Gene phenotype association count',
    width => 1
  },{
    _key => 'qtl_count', _type => 'string no_filter',
    label => 'QTL',
    helptip => 'Quantitative trait loci (QTL) phenotype association count',
    width => 1
  });

  $table->add_columns(\@columns,\@exclude);

  my $onto_type = $table->column('onto_type');
  $onto_type->icon_url('equal',"/i/val/equal.png");
  $onto_type->icon_helptip('equal','Equivalent to the ontology term');
  $onto_type->icon_url('child','/i/val/arrow_down.png');
  $onto_type->icon_helptip('child','Equivalent to the child ontology term');

  return $table;
}

1;

