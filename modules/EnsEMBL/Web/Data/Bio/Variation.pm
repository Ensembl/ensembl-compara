package EnsEMBL::Web::Data::Bio::Variation;

### NAME: EnsEMBL::Web::Data::Bio::Variation
### Base class - wrapper around a Bio::EnsEMBL::Variation API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Variation

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  ### Converts a set of API objects into simple parameters 
  ### for use by drawing code and HTML components
  
  my $self         = shift;
  my $data         = $self->data_objects;
  my $hub          = $self->hub;
  my $phenotype_id = $hub->param('id'); # getting associated phenotype with the variation
  my $species      = $hub->species;
  my $vardb        = $hub->database('variation');
  my $vaa          = $vardb->get_adaptor('VariationAnnotation');
  my @results;
  
  my (%associated_phenotypes, %associated_genes, %p_value_logs, %p_values);
  
  # getting associated phenotypes and associated genes
  foreach my $va (@{$vaa->fetch_all_by_VariationFeature_list($data) || []}) {
    my $variation_id = $va->{'_variation_id'};
    
    push @{$associated_phenotypes{$variation_id}}, $va->{'phenotype_description'};
    
    if ($va->{'_phenotype_id'} eq $phenotype_id) {      
      # only get the p value log 10 for the pointer matching phenotype id and variation id
      $p_value_logs{$variation_id} = -(log($va->{'p_value'}) / log(10)) unless $va->{'p_value'} == 0;
      
      $p_values{$variation_id} = $va->{'p_value'};
      
      # if there is more than one associated gene (comma separated), split them to generate the URL for each of them
      foreach my $gene (grep $_, split /,/, $va->{'associated_gene'}) {
        $gene =~ s/\s//g;
        $associated_genes{$variation_id}{$gene} = $gene;
      }
    }
  }
  
  foreach my $vf (@$data) {
    if (ref($vf) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($vf);
      push @results, $unmapped;
      next;
    }
    
    # getting all genes located in that specific location
    my $seq_region   = $vf->seq_region_name;
    my $start        = $vf->seq_region_start;
    my $end          = $vf->seq_region_end;
    my $name         = $vf->variation_name;
    my $dbID         = $vf->dbID;
    my $variation_id = $vf->{'_variation_id'};
    
    # preparing the URL for all the associated genes and ignoring duplicate one
    $_ = sprintf '<a href="%s">%s</a>', $hub->url({ type => 'Gene', action => 'Summary', g => $_, v => $name, vf => $dbID }), $_ for grep !/intergenic|psuedogene/i, values %{$associated_genes{$variation_id} || {}};
    
    # making the location 10kb if it a one base pair
    if ($end == $start) {
      $start -= 5000;
      $end   += 5000;
    }
    
    # make zmenu link
    my $zmenu_url = $hub->url({
      type => 'ZMenu',
      action => 'Variation',
      v => $name,
      vf => $dbID,
      vdb => 'variation',
      p_value => $p_values{$variation_id}
    });
    
    push @results, {
      region         => $seq_region,
      start          => $start,
      end            => $end,
      strand         => $vf->strand,
      label          => $name,
      href           => $zmenu_url,
      p_value        => $p_value_logs{$variation_id},
      colour_scaling => 1,
      somatic        => $vf->is_somatic,
      extra          => [
        join(', ', map $associated_genes{$variation_id}{$_}, sort keys %{$associated_genes{$variation_id} || {}}),
        join(', ', @{$associated_phenotypes{$variation_id} || []}), 
        sprintf('%.1f', $p_value_logs{$variation_id})
      ]
    };
  }

  return [ \@results, ['Associated Gene(s)','Associated Phenotype(s)','P value (negative log)'], 'Variation' ];
}


1;
