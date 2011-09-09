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
  my $db       = $self->param('db') || 'core';
  my $features = {};
  
  my $id         = $self->param('id');   
  return $self->problem('fatal', 'No ID', $self->_help) unless $id;
  my $dbc        = $self->hub->database('variation');
  return unless $dbc;
  $dbc->include_failed_variations(1);
  my $a          = $dbc->get_adaptor('VariationFeature');
  my $func       = $self->param('somatic') ? 'fetch_all_somatic_with_annotation' : 'fetch_all_with_annotation';
  my $variations = $a->$func(undef, undef, $id);
  
  if ($variations and scalar @$variations > 0) {
    $features->{'Variation'} = EnsEMBL::Web::Data::Bio::Variation->new($self->hub, @$variations);

    ## Get associated genes
    my $vardb        = $self->hub->database('variation');
    my $vaa          = $vardb->get_adaptor('VariationAnnotation');
    my %associated_gene;
  
    foreach my $va (@{$vaa->fetch_all_by_VariationFeature_list($variations) || []}) {
      if ($va->{'_phenotype_id'} eq $id) {
        # if there is more than one associated gene (comma separated), split them to generate the URL for each of them
        foreach my $gene_id (grep $_, split /,/, $va->{'associated_gene'}) {
          $gene_id =~ s/\s//g;
          next if $gene_id =~ /intergenic/i;
          my $gene_objects = $self->_create_Gene('core', $gene_id);
          unless ($associated_gene{$gene_id}) {
            $associated_gene{$gene_id} = $gene_objects;
          }
        }
      }
    } 
    if (keys %associated_gene) {
      my $genes;
      while (my ($gene_id, $gene_objects) = each(%associated_gene)) {
        push @$genes, @{$gene_objects || []};
      }
      $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes);
    }
  }
  my $object = $self->new_object('Phenotype', $features, $self->__data);

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
  my $url       = $self->hub->url({ __clear => 1, action => 'Locations', 
                                    id => $sample{'PHENOTYPE_ID'}, 
                                    name => encode_entities($sample{'PHENOTYPE_NAME'}) });

  $help_text .= sprintf('
  <p>
    This view requires a phenotype identifier in the URL. For example:
  </p>
  <blockquote class="space-below"><a href="%s">%s</a> (%s)</blockquote>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url),
    $sample{'PHENOTYPE_NAME'}
  );

  return $help_text;
}


1;
