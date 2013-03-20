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
  my @phen_ids     = $hub->param('ph');
  my $species      = $hub->species;
  my $vardb        = $hub->database('variation');
  my $pfa          = $vardb->get_adaptor('PhenotypeFeature');
  my @results;
  
  my (%associated_phenotypes, %associated_genes, %p_value_logs, %p_values, %phenotypes_sources);
  
  # getting associated phenotypes and associated genes
  foreach my $pf (@{$data || []}) {
    my $variation_name = $pf->{'_object_id'};

    $associated_phenotypes{$variation_name}{$pf->phenotype->description} = 1;
    my $source_name = $pf->source;
       $source_name =~ s/_/ /g;
    $phenotypes_sources{$variation_name}{$source_name} = 1;
    
    
    if (grep @phen_ids, $pf->{'_phenotype_id'}) {      
      # only get the p value log 10 for the pointer matching phenotype id and variation id
      #warn ">>> PVAL ".$va->{'p_value'};
      $p_value_logs{$variation_name} = -(log($pf->p_value) / log(10)) unless $pf->p_value == 0;      
      $p_values{$variation_name} = $pf->p_value;
      
      # if there is more than one associated gene (comma separated), split them to generate the URL for each of them
      my $dbc = $self->hub->database('core');
      my $ga  = $dbc->get_adaptor('Gene');
      foreach my $id (grep $_, split /,/, $pf->associated_gene) {
        $id =~ s/\s//g;
        my @genes = @{$ga->fetch_all_by_external_name($id)||[]};
        next unless @genes;
        foreach (@genes) {
          $associated_genes{$variation_name}{$id} = $_->description;
        }
      }
    }
  }
  
  foreach my $pf (@$data) {
    if (ref($pf) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($pf);
      push @results, $unmapped;
      next;
    }
    
    my $object_type = $pf->type;
    
    # getting all genes located in that specific location
    my $seq_region   = $pf->seq_region_name;
    my $start        = $pf->seq_region_start;
    my $end          = $pf->seq_region_end;
    my $name         = $pf->object_id;
    my $dbID         = $pf->dbID;
    
    # preparing the URL for all the associated genes and ignoring duplicate one
    my @assoc_gene_links;
    while (my ($id, $desc) = each (%{$associated_genes{$name} || {}})) {
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
    my $id_param = $object_type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);
    
    my %url_params = ();
    
    if($object_type eq 'Gene' || $object_type eq 'Variation' || $object_type eq 'StructuralVariation') {
      %url_params = (
        type      => 'ZMenu',
        ftype     => 'Xref',
        action    => $object_type,
        $id_param => $name,
        vdb     => 'variation'
      );
      
      $url_params{p_value} = $p_value_logs{$name} if defined($p_value_logs{$name});
    }
    
    # use simple feature for QTL and SupportingStructuralVariation
    else {
      %url_params = (
        type          => 'ZMenu',
        ftype         => 'Xref',
        action        => 'SimpleFeature',
        display_label => $name,
        logic_name    => $object_type,
        bp            => $seq_region.":".$start."-".$end,
      );
    }
    
    my $zmenu_url = $hub->url(\%url_params);

    #the html id is used to match the feature on the karyotype (html_id in area tag) with the row in the feature table (table_class in the table row)
    push @results, {
      region          => $seq_region,
      start           => $start,
      end             => $end,
      strand          => $pf->strand,
      html_id         => qq{${name}_$dbID},
      label           => $name,
      href            => $zmenu_url,       
      p_value         => $p_value_logs{$name},
      extra           => {
        'feat_type'   => $object_type,
        'genes'       => join(', ', @assoc_gene_links) || '-',
        'phenotypes'  => join('; ', sort keys %{$associated_phenotypes{$name} || {}}),
        'phe_sources' => join(', ', sort keys %{$phenotypes_sources{$name} || {}}),
        'p-values'    => ($p_value_logs{$name} ? sprintf('%.1f', $p_value_logs{$name}) : '-'), 
      },
    };
  }
  
  my $extra_columns = [
        {'key' => 'feat_type',   'title' => 'Feature type',           'sort' => ''},
        {'key' => 'genes',       'title' => 'Reported gene(s)',       'sort' => 'html'},
        {'key' => 'phenotypes',  'title' => 'Associated phenotype(s)', 'sort' => ''},
        {'key' => 'phe_sources', 'title' => 'Annotation source(s)', 'sort' => ''},
        {'key' => 'p-values',    'title' => 'P value (negative log)', 'sort' => 'numeric'},
  ];
  return [\@results, $extra_columns];
}

1;
