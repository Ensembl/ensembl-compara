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
  my $phenotype_id = $hub->param('ph') || $hub->param('id');
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
      my $dbc = $self->hub->database('core');
      my $ga  = $dbc->get_adaptor('Gene');
      foreach my $id (grep $_, split /,/, $va->{'associated_gene'}) {
        $id =~ s/\s//g;
        my @genes = @{$ga->fetch_all_by_external_name($id)||[]};
        next unless @genes;
        foreach (@genes) {
          $associated_genes{$variation_id}{$id} = $_->description;
        }
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
    my @assoc_gene_links;
    while (my ($id, $desc) = each (%{$associated_genes{$variation_id} || {}})) {
      next if $id =~ /intergenic|pseudogene/i;
      push @assoc_gene_links, sprintf('<a href="%s" title="%s">%s</a>', 
        $hub->url({ type => 'Gene', action => 'Summary', g => $id, v => $name, vf => $dbID }),
        $desc,
        $id);
    }
 
    # making the location 10kb if it a one base pair
    if ($end == $start) {
      $start -= 5000;
      $end   += 5000;
    }
    
    # make zmenu link
    my $zmenu_url = $hub->url({
      type    => 'ZMenu',
      ftype   => 'Xref',
      action  => 'Variation',
      v       => $name,
      vf      => $dbID,
      vdb     => 'variation',
      p_value => $p_value_logs{$variation_id}
    });

    #the html id is used to match the SNP on the karyotype (html_id in area tag) with the row in the feature table (table_class in the table row)
    push @results, {
      region         => $seq_region,
      start          => $start,
      end            => $end,
      strand         => $vf->strand,
      html_id        => qq{${name}_$dbID},
      label          => $name,
      href           => $zmenu_url,       
      p_value        => $p_value_logs{$variation_id},
      somatic        => $vf->is_somatic,
      extra          => {
        'source'     => $vf->source,
        'genes'      => join(', ', @assoc_gene_links),
        'phenotypes' => join(', ', @{$associated_phenotypes{$variation_id} || []}),
        'p-values'   => ($p_value_logs{$variation_id} ? sprintf('%.1f', $p_value_logs{$variation_id}) : ''), 
      },
    };
  }
  my $extra_columns = [
        {'key' => 'source',     'title' => 'Source',                  'sort' => ''},
        {'key' => 'genes',      'title' => 'Associated Gene(s)',      'sort' => 'html'},
        {'key' => 'phenotypes', 'title' => 'Phenotype(s) associated with this variant', 'sort' => ''},
        {'key' => 'p-values',   'title' => 'P value (negative log)',  'sort' => 'numeric'},
  ];
  return [\@results, $extra_columns];
}


1;
