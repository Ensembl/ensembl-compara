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

package EnsEMBL::Web::Factory::Phenotype;

### NAME: EnsEMBL::Web::Factory::Phenotype

### STATUS: Under development

### DESCRIPTION:

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Data::Bio::Slice;
use EnsEMBL::Web::Data::Bio::Gene;
use EnsEMBL::Web::Data::Bio::Variation;

use base qw(EnsEMBL::Web::Factory::Feature);

sub createObjects {
  ### Fetches all the variation features associated with a phenotype
  ### Args: db 
  ### Returns: hashref of API objects
  my $self     = shift;
  my $hub      = $self->hub;
  my $db       = $self->param('db') || 'core';
  my $features = {};

  my $dbc = $hub->database('variation');
  return unless $dbc;
  $dbc->include_non_significant_phenotype_associations(0);
 
  my @ids = $self->param('ph');

  # Retrieve the ontology accession if there is only 1 associated with a phenotype entry
  if ($self->param('ph') and !$self->param('oa')) {
    my $phen_ad = $dbc->get_adaptor('Phenotype');
    my $phen_obj = $phen_ad->fetch_by_dbID($self->param('ph'));
    my $ontology_accessions = $phen_obj->ontology_accessions();
    if (scalar(@{$ontology_accessions}) == 1) {
      $self->param('oa', $ontology_accessions->[0]);
    }
  }
  # Use the ontology accession if no ph param provided
  elsif (!@ids && $self->param('oa')) {
    my $phen_ad = $dbc->get_adaptor('Phenotype');
    my %phenotypes = map { $_->dbID => 1 } @{$phen_ad->fetch_all_by_ontology_accession( $hub->param('oa') )};
    @ids = keys(%phenotypes);
  }

  return $self->problem('fatal', 'No ID', $self->_help) if (!scalar(@ids) && $hub->action ne 'All');
  
  if (@ids) {
    my $pfs = [];
    my $genes = [];

    my $adaptor = $dbc->get_adaptor('PhenotypeFeature');

    my %associated_gene;

    foreach my $id (@ids) {

      push @$pfs, @{$adaptor->fetch_all_by_phenotype_id_source_name($id) || []};

## TODO - Get genes with no associated variation 
=pod

      if ($pfs and scalar @$pfs > 0) {

#        my %associated_gene;
  
        foreach my $pf (@{$pfs}) {
          if ($pf->{'_phenotype_id'} eq $id) {
            # if there is more than one associated gene (comma separated), split them to generate the URL for each of them            
            if($pf->associated_gene) {
              foreach my $gene_id (grep $_, split /,/, $pf->associated_gene) {
                $gene_id =~ s/\s//g;
                next if $gene_id =~ /intergenic/i;
                next unless $gene_id;
                unless ($associated_gene{$gene_id}) {
                  my $gene_objects = $self->_create_Gene('core', $gene_id);
                  $associated_gene{$gene_id} = $gene_objects;
                }
              }
            }
          }
        } 
        if (keys %associated_gene) {
          my %seen;
          while (my ($gene_id, $gene_objects) = each(%associated_gene)) {
            foreach (@{$gene_objects || []}) {
              next if $seen{$_->stable_id};
              push @$genes, $_; 
              $seen{$_->stable_id}++;
            }
          }
        }
      }

## TODO - Get genes with no associated variation 
  ## Add all genes
  if (scalar(@$genes)) {
    $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes);
  }
=cut
    }
    if ($pfs and scalar @$pfs > 0) {
      $features->{'Variation'} = EnsEMBL::Web::Data::Bio::Variation->new($self->hub, @$pfs);
    }
  }
  my $object = $self->new_object('Phenotype', $features, $self->__data);
  $object->phenotype_id(\@ids);

  $self->DataObjects($object);
}

sub _create_Gene {
  ### Fetches all the genes for a given identifier (usually only one, but could be multiple
  ### Args: db
  ### Returns: hashref containing a Data::Bio::Gene object
  my ($self, $db, $id) = @_;
  my ($genes_only, $real_id);
  
  if ($id) {
    $genes_only = 1;
    $real_id = $id;
  } else {
    $id = $self->param('id');
  }
  
  my $genes = $self->_generic_create('Gene', $id =~ /^ENS/ ? 'fetch_by_stable_id' : 'fetch_all_by_external_name', $db, $real_id, 'no_errors');
  
  return $genes_only ? $genes : { Gene => EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes) };
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Locations', ph => $sample{'PHENOTYPE_PARAM'}});

  $help_text .= sprintf('
  <p>
    This view requires a phenotype identifier in the URL. For example:
  </p>
  <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a> (%s)</div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url),
    $sample{'PHENOTYPE_TEXT'}
  );

  return $help_text;
}


1;
