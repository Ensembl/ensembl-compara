=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Data::Bio::Variation;

### NAME: EnsEMBL::Web::Data::Bio::Variation
### Base class - wrapper around a Bio::EnsEMBL::Variation API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Variation

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;

use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  ### Converts a set of API objects into simple parameters 
  ### for use by drawing code and HTML components
  
  my $self     = shift;
  my @data     = grep {$_->type ne 'SupportingStructuralVariation'} @{$self->data_objects || []}; # Skip the Supporting Structural Variation phenotype features
  my $hub      = $self->hub;
  my @phen_ids = $hub->param('ph');
  my $ga       = $hub->database('core')->get_adaptor('Gene');
  my (@results, %associated_genes, %p_value_logs, %p_values, %phenotypes_sources, %phenotypes_studies,%gene_ids);

  # Threshold to display the variations on the karyotype view. Use BioMart instead.
  my $max_features    = 1000;
  my $count_features  = scalar @data;

  if ($count_features > $max_features) {

    my $biomart_link = ($hub->species_defs->ENSEMBL_MART_ENABLED && $hub->species =~ /homo_sapiens/i) ? '?VIRTUALSCHEMANAME=default'.
                          '&ATTRIBUTES=hsapiens_snp.default.snp.refsnp_id|hsapiens_snp.default.snp.chr_name|'.
                          'hsapiens_snp.default.snp.chrom_start|hsapiens_snp.default.snp.associated_gene'.
                          '&FILTERS=hsapiens_snp.default.filters.phenotype_description.&quot;'.$hub->param('name').'&quot;'.
                          '&VISIBLEPANEL=resultspanel' : '/';


    throw exception('TooManyFeatures', qq(There are <b>$count_features</b> genomic locations associated with this phenotype. Please, use <a href="/biomart/martview$biomart_link">BioMart</a> to retrieve a table of all the variants associated with this phenotype instead as there are too many to display on a karyotype.));
  }

  # getting associated phenotypes and associated genes
  foreach my $pf (@data) {
    my $object_id   = $pf->object_id;
    my $source_name = $pf->source_name;
       $source_name =~ s/_/ /g;
    my $study_xref  = ($pf->study) ? $pf->study->external_reference : undef;
    my $external_id = ($pf->external_id) ? $pf->external_id : undef;
    my $attribs     = $pf->get_all_attributes;

    $phenotypes_sources{$object_id}{$source_name}{'study_xref'} = $study_xref;
    $phenotypes_sources{$object_id}{$source_name}{'external_id'} = $external_id;
    $phenotypes_sources{$object_id}{$source_name}{'xref_id'} = $attribs->{'xref_id'} if ($attribs->{'xref_id'});
    $phenotypes_studies{$object_id}{$study_xref} = 1 if ($study_xref);
    
    # only get the p value log 10 for the pointer matching phenotype id and variation id
    if (grep $pf->{'_phenotype_id'} == $_, @phen_ids) {
      $p_value_logs{$object_id} = -(log($pf->p_value) / log(10)) unless $pf->p_value == 0;      
      $p_values{$object_id}     = $pf->p_value;

      # if there is more than one associated gene (comma separated), split them to generate the URL for each of them
      foreach my $id (grep $_, split /,/, $pf->associated_gene) {
        $id =~ s/\s//g;
        if ($gene_ids{$id}) {
          $associated_genes{$object_id}{$id} = $gene_ids{$id};
        }
        else {
          foreach my $gene (@{$ga->fetch_all_by_external_name($id) || []}) {
            $associated_genes{$object_id}{$id} = $gene->description;
            $gene_ids{$id} = $gene->description;
          }
        }
      }
    }
  }
  
  my %seen;
  
  foreach my $pf (@data) {
    if (ref($pf) =~ /UnmappedObject/) {
      push @results, $self->unmapped_object($pf);
      next;
    }
    
    # unique key on name and location
    my $name        = $pf->object_id;
    my $seq_region  = $pf->seq_region_name;
    my $start       = $pf->seq_region_start;
    next if $seen{$name.$seq_region.$start};
    $seen{$name.$seq_region.$start} = 1;
    
    my $object_type = $pf->type;
    my $end         = $pf->seq_region_end;
    my $dbID        = $pf->dbID;
    my $id_param    = $object_type;
       $id_param    =~ s/[a-z]//g;
       $id_param    = lc $id_param;

    my (@assoc_gene_links, %url_params);  
       
    # preparing the URL for all the associated genes and ignoring duplicate one   
    while (my ($id, $desc) = each (%{$associated_genes{$name} || {}})) {    
      next if $id =~ /intergenic|pseudogene/i;    
     
      push @assoc_gene_links, sprintf(    
        '<a href="%s" title="%s">%s</a>',   
        $hub->url({ type => 'Gene', action => 'Summary', g => $id }),    
        $desc,    
        $id   
      );    
    }
 
    # making the location 10kb if it a one base pair
    if ($end == $start) {
      $start -= 5000;
      $end   += 5000;
    }
    
    # make zmenu link
    if ($object_type =~ /^(Gene|Variation|StructuralVariation)$/) {
      %url_params = (
        type      => 'ZMenu',
        ftype     => $object_type,
        action    => 'Phenotype',
        $id_param => $name,
        vdb       => 'variation'
      );
      
      $url_params{'p_value'} = $p_value_logs{$name} if defined $p_value_logs{$name};
      $url_params{'regions'} = sprintf '%s:%s-%s', $seq_region, $pf->seq_region_start, $pf->seq_region_end if $object_type eq 'Variation';
    } else {
      # use simple feature for QTL and SupportingStructuralVariation
      %url_params = (
        type          => 'ZMenu',
        ftype         => 'Xref',
        action        => 'SimpleFeature',
        display_label => $name,
        logic_name    => $object_type,
        bp            => "$seq_region:$start-$end",
      );
    }
    
    # make source link out
    my $sources;
    foreach my $source(keys %{$phenotypes_sources{$name} || {}}) {
      $sources .= ($sources ? ', ' : '').$self->_pf_source_link($name,$source,$phenotypes_sources{$name}{$source}{'external_id'},$phenotypes_sources{$name}{$source}{'xref_id'},$pf);
    }
    
    push @results, {
      region  => $seq_region,
      start   => $start,
      end     => $end,
      strand  => $pf->strand,
      html_id => "${name}_$dbID", # The html id is used to match the feature on the karyotype (html_id in area tag) with the row in the feature table (table_class in the table row)
      label   => $name,
      href    => \%url_params,
      p_value => $p_value_logs{$name},
      extra   => {
        feat_type   => $object_type,
        genes       => join(', ', @assoc_gene_links) || '-',
        phe_sources => $sources,
        phe_studies => $self->_pf_external_reference_link($phenotypes_studies{$name}),
        orig_source => (keys %{$phenotypes_sources{$name}})[0],
        'p-values'  => ($p_value_logs{$name} ? sprintf('%.1f', $p_value_logs{$name}) : '-'), 
      },
    };
  }
  
  return [ \@results, [
    { key => 'feat_type',   title => 'Feature type',            sort => ''        },
    { key => 'genes',       title => 'Reported gene(s)',        sort => 'html'    },
    { key => 'phe_sources', title => 'Annotation source(s)',    sort => ''        },
    { key => 'phe_studies', title => 'Study',                   sort => ''        },
    { key => 'p-values',    title => 'P value (negative log)',  sort => 'numeric' },
  ]];
}

sub _pf_external_reference_link {
  my ($self, $xrefs) = @_;
  
  my $html; 
 
  foreach my $xref (sort keys(%$xrefs)) {
    my $link;
    if($xref =~ /(pubmed|PMID)/) {
      foreach my $pmid (split(',',$xref)) {
        my $id = $pmid;
           $id =~ s/pubmed\///;
           $id =~ s/PMID://;
        $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
        $link =~ s/###ID###/$id/;
        $pmid =~ s/\//:/g;
        $pmid =~ s/pubmed/PMID/;
        $html .= qq{<a rel="external" href="$link">$pmid</a>; };
      }
    }
    elsif($xref =~ /^MIM\:/) {
      foreach my $mim (split /\,\s*/, $xref) {
        my $id = (split /\:/, $mim)[-1];
        my $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
        $link .= ', '.$sub_link;
        $link =~ s/^\, //g;
      }
      $html .= "$link; ";
    }
    else {
      $html .= "$xref; ";
    }
  }
  $html =~ s/;\s$//;
  
  return $html;
}


sub _pf_source_link {
  my ($self, $obj_name, $source, $ext_id, $ext_ref_id, $pf) = @_;

  my $source_uc = uc $source;
     $source_uc =~ s/\s/_/g;

  if ($source eq 'Animal QTLdb') {
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $self->hub->species)));
    
    return $self->hub->get_ExtURL_link(
      $source,
      $source_uc,
      { ID => $obj_name, SP => $species}
    );
  }
  if ($source eq 'GOA') {
    return $self->hub->get_ExtURL_link(
      $source,
      'QUICK_GO_IMP',
      { ID => $ext_id, PR_ID => $ext_ref_id}
    );
  }
  if ($source_uc eq 'RGD') {
    return $source if (!$ext_id);
    return $self->hub->get_ExtURL_link(
      $source,
      $source_uc.'_SEARCH',
      { ID => $ext_id }
    );
  }
  if ($source_uc eq 'ZFIN') {
    my $phe = $pf->phenotype->description;
       $phe =~ s/,//g;
    return $self->hub->get_ExtURL_link(
      $source,
      $source_uc.'_SEARCH',
      { ID => $phe }
    );
  }
  
  my $url   = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  my $label = $source;
  my $name;
  if ($url =~/ebi\.ac\.uk\/gwas/) {
    $name = $obj_name;
  } 
  elsif ($url =~ /clinvar/) {
    $ext_id =~ /^(.+)\.\d+$/;
    $name = ($1) ? $1 : $ext_id;
  } 
  elsif ($url =~ /omim/) {
    $name = "search?search=".($ext_id || $obj_name);
  } else {
    $name = $ext_id || $obj_name;
  }
  
  $url =~ s/###ID###/$name/;
  
  my $tax = $self->hub->species_defs->TAXONOMY_ID;
  $url =~ s/###TAX###/$tax/;
  
  return $source if $url eq "";
  
  return qq{<a rel="external" href="$url">$label</a>};
}

1;
