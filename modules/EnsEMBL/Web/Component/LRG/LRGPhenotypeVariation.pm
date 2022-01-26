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

package EnsEMBL::Web::Component::LRG::LRGPhenotypeVariation;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $phenotype = $hub->param('sub_table');
  my $object    = $self->object;
  my $lrg_slice = $object->slice;
  my $html;

  # Check if a variation database exists for the species.
  if ($hub->database('variation')) {
    my $no_data = '<p>No phenotype, disease or trait has been associated with variants in this gene.</p>';
    # Variation phenotypes
    if ($phenotype) {
      my $table_rows = $self->variation_table($phenotype);
      my $table      = $table_rows ? $self->make_table($table_rows, $phenotype) : undef;

      $html .= $self->render_content($table, $phenotype);
    } else {
      $html .= $self->render_content($self->stats_table($lrg_slice)); # no sub-table selected, just show stats
    }
  }
  
  return $html;
}


sub make_table {
  my ($self, $table_rows, $phenotype) = @_;

  my $columns = [
    { key => 'ID',      sort => 'html',           title => 'Variant ID'                          },
    { key => 'chr' ,    sort => 'position',       title => 'Chr: bp'                             },
    { key => 'Alleles', sort => 'string',                                      align => 'center' },
    { key => 'class',   sort => 'string',         title => 'Class',            align => 'center' },
    { key => 'psource', sort => 'string',         title => 'Phenotype Sources'                   },
    { key => 'pstudy',  sort => 'string',         title => 'Phenotype Studies'                   },
    { key => 'pvalue',  sort => 'numeric_hidden', title => 'p-value'                             },
  ];

  push (@$columns, { key => 'phe',   sort => 'string',    title => 'Phenotypes' }) if ($phenotype eq 'ALL');
  my $table_id = $phenotype;
     $table_id =~ s/[^\w]/_/g;
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 1, id => $table_id."_table" });
}


sub render_content {
  my ($self, $table, $phenotype) = @_;
  my $stable_id = $self->object->stable_id;
  my $html;
  
  if ($phenotype) {
    my $table_id = $phenotype;
       $table_id =~ s/[^\w]/_/g;
    
    $html = $self->toggleable_table("$phenotype associated variants", $table_id, $table, 1, qq(<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>));
  } else {
    $html = qq(<a id="$self->{'id'}_top"></a><h2>Phenotype, disease and trait associated with the genomic location of this LRG, from variant annotations</h2>) . $table->render;
  }

  return $html;
}

sub stats_table {
  my ($self, $obj_slice) = @_;  
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $pf_adaptor   = $self->hub->database('variation')->get_PhenotypeFeatureAdaptor;
  my ($total_counts, %phenotypes, @va_ids);

  my $columns = [
    { key => 'phen',    title => 'Phenotype, disease and trait', sort => 'string', width => '35%'  },
    { key => 'source',  title => 'Source(s)', sort => 'string', width => '11%'  },
    { key => 'count',   title => 'Number of variants',  sort => 'numeric_hidden', width => '10%',   align => 'right'  },
    { key => 'view',    title => 'Show/hide details',   sort => 'none',           width => '10%',   align => 'center' }
  ];

   
  foreach my $pf ($obj_slice ? @{$pf_adaptor->fetch_all_by_Slice_type($obj_slice,'Variation')} : ()) {
    my $phe_source = $pf->source_name;
    next if ($self->check_source($phe_source));

    my $var_name = $pf->object_id;  
    my $phe      = $pf->phenotype->description;
   
    $phenotypes{$phe} ||= { id => $pf->{'_phenotype_id'} , name => $pf->{'_phenotype_name'}};
    $phenotypes{$phe}{'count'}{$var_name} = 1;
    $phenotypes{$phe}{'source'}{$phe_source} = 1;
    
    $total_counts->{$var_name} = 1;
  }  
  
  my $warning_text = qq{<span style="color:red">(WARNING: details table may not load for this number of variants!)</span>};
  my ($url, @rows);
  
  
  my $mart_somatic_url = '//www.ensembl.org/biomart/martview?VIRTUALSCHEMANAME=default'.
                         '&ATTRIBUTES=hsapiens_snp_som.default.snp.refsnp_id|hsapiens_snp_som.default.snp.chr_name|'.
                         'hsapiens_snp_som.default.snp.chrom_start|hsapiens_snp_som.default.snp.associated_gene'.
                         '&FILTERS=hsapiens_snp_som.default.filters.phenotype_description.&quot;###PHE###&quot;'.
                         '&VISIBLEPANEL=resultspanel';
  my $max_lines = 1000;
  
  # add the row for ALL variations if there are any
  if (my $total = scalar keys %$total_counts) {
    my $warning = $total > $max_lines ? $warning_text : '';
  
    push @rows, {
      phen   => "ALL variants with a phenotype annotation $warning",
      count  => qq{<span class="hidden">-</span>$total}, # create a hidden span to add so that ALL is always last in the table
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => 'ALL' }), 'ALL'),
      source => '-',
      lview  => '-'
    };
  }
  
  foreach (sort {$a cmp $b} keys %phenotypes) {
    my $phenotype    = $phenotypes{$_};
    my $phe_desc     = $_;
    my $table_id     = $phe_desc;
       $table_id     =~ s/[^\w]/_/g;
    my $phe_count    = scalar (keys(%{$phenotype->{'count'}}));
    my $warning      = $phe_count > $max_lines ? $warning_text : '';
    my $sources_list = join ', ', map $self->source_link($_, undef, undef, undef, $phe_desc), sort {$a cmp $b} keys(%{$phenotype->{'source'}});
    my $phe_url      = $_;
    
    # Associate loci link
    if ($hub->species_defs->ENSEMBL_CHROMOSOMES) {
      $phe_url = sprintf (
                   '<a href="%s" title="%s">%s</a>',
                   $hub->url({
                     type => 'Phenotype',
                     action => 'Locations',
                     ph => $phenotype->{'id'}
                   }),
                   'View associate loci',
                   $_
                 ) unless /(HGMD|COSMIC)/;
    }
       
    push @rows, {
      phen   => "$phe_url $warning",
      count  => $phe_count,
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => $_ }), $table_id),
      source => $sources_list
    };
  }
  
  if (scalar @rows) {
    return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', data_table_config => {iDisplayLength => 10}, exportable => 0 });
  }
}


sub variation_table {
  my ($self, $phenotype) = @_;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $obj_slice     = $object->slice;
  my $g_region      = $obj_slice->seq_region_name;
  my $g_start       = $obj_slice->start;
  my $g_end         = $obj_slice->end;
  my $phenotype_sql = $phenotype;
     $phenotype_sql =~ s/'/\\'/; # Escape quote character
  my $pf_adaptor    = $hub->database('variation')->get_PhenotypeFeatureAdaptor;
  my $max_items_per_source = 2;
  my (@rows, %list_sources, %list_phe, $list_variations);

  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Phenotype',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  my $all_flag = ($phenotype eq 'ALL') ? 1 : 0;
  
  my $submitter_max_length = 20;
    
  foreach my $pf (@{$pf_adaptor->fetch_all_by_Slice_type($obj_slice,'Variation')}) {
    
    next unless ($pf->is_significant);  
    next if ($phenotype ne $pf->phenotype->description && $all_flag == 0);
    
    my $phe_source = $pf->source_name;
    next if ($self->check_source($phe_source));

    #### Phenotype ####
    my $var        = $pf->object;
    my $var_name   = $var->name;
    my $list_sources;

    if (!$list_variations->{$var_name}) {
      my $pf_region = $pf->seq_region_name;
      my $pf_start  = $pf->start;
      my $pf_end    = $pf->end;

      my $location = "$pf_region:$pf_start" . ($pf_start == $pf_end ? '' : "-$pf_end");
 
      my $allele;
      foreach my $vf (@{$var->get_all_VariationFeatures()}) {
        my $vf_allele = $vf->allele_string;
        
        $vf_allele =~ s/(.{20})/$1\n/g;
        
        $allele = $vf_allele;
        last;
      }
    
      $list_variations->{$var_name} = { 'class'  => $var->var_class,
                                        'chr'    => $location,
                                        'allele' => $allele
                                      };
    }
      
    # List the phenotype sources for the variation
    my $phe_source = $pf->source_name;
    my $ref_source = $pf->external_reference;
       $ref_source = $pf->external_id if (!$ref_source);

    $list_phe{$var_name}{$pf->phenotype->description} = 1 if ($all_flag == 1);

    if ($list_sources{$var_name}{$phe_source}{'ref'}) {
      push (@{$list_sources{$var_name}{$phe_source}{'ref'}}, $ref_source) if $ref_source;
    }
    else {
      if ($ref_source) {
        $list_sources{$var_name}{$phe_source}{'ref'} = [$ref_source];
      }
      else {
        $list_sources{$var_name}{$phe_source}{'ref'} = ['no_ref'];
      }
    }

    # List sumbitters and study (ClinVar)
    if ($phe_source =~ /clinvar/i) {
      my $submitter_names_list = $pf->submitter_names;
      if ($submitter_names_list) {
        foreach my $submitter_name (@$submitter_names_list) {
          $list_sources{$var_name}{$phe_source}{'submitter'}{$ref_source}{$submitter_name} = 1;
        }
      }
      my $attributes = $pf->get_all_attributes();
      if ($attributes->{'MIM'}) {
        my @studies = split(',',$attributes->{'MIM'});
        foreach my $study (@studies) {
          $list_sources{$var_name}{$phe_source}{'clinvar_study'}{$ref_source}{$study} = 1;
        }
      }
    }

    # List the phenotype association p-values for the variation
    my $p_value = $pf->p_value;
    if ($p_value) {
      if ($list_sources{$var_name}{$phe_source}{'p-value'}) {
        push (@{$list_sources{$var_name}{$phe_source}{'p-value'}}, $p_value);
      }
      else {
        $list_sources{$var_name}{$phe_source}{'p-value'} = [$p_value];
      }
    }
  }  

  foreach my $var_name (sort (keys %list_sources)) {
    my %sources_list;
    my %source_exp_list;
    my @ext_ref_list;
    my @pvalues_list;
    my ($max_exp, $max_pval);
    foreach my $p_source (sort (keys (%{$list_sources{$var_name}}))) {

      foreach my $ref (@{$list_sources{$var_name}{$p_source}{'ref'}}) {
        # Source link
        my $s_link   = $self->source_link($p_source, $ref, $var_name, undef, $phenotype);
        my $exp_data = $p_source;
        
        # Sumbitter data (ClinVar)
        if ($list_sources{$var_name}{$p_source}{'submitter'} && $list_sources{$var_name}{$p_source}{'submitter'}{$ref}) {
          my @submitter_names_list = keys(%{$list_sources{$var_name}{$p_source}{'submitter'}{$ref}});
          my $submitter_names = join('|',@submitter_names_list);
          my $submitter_label = $submitter_names;
             $submitter_label = substr($submitter_names,0,$submitter_max_length).'...' if (length($submitter_names) > $submitter_max_length);
          my $submitter_prefix  = 'Submitter';
             $submitter_prefix .= 's' if (scalar(@submitter_names_list) > 1);
          $s_link .= " [$submitter_label]";
          $s_link = qq{<span class="_ht" title="$submitter_prefix: $submitter_names">$s_link</span>};
          $exp_data = "$p_source [$submitter_names]";
        }
        if (!grep {$s_link eq $_} @{$sources_list{$p_source}}) {
          push(@{$sources_list{$p_source}}, $s_link);
        }
        $source_exp_list{$p_source}{$exp_data} = 1;

        # Study link
        my $ext_link = $self->external_reference_link($p_source, $ref, $phenotype);
        if ($ext_link ne '-' && !grep {$ext_link eq $_} @ext_ref_list) {
          push(@ext_ref_list, $ext_link);
        }

        # Study link (ClinVar)
        if ($p_source =~ /clinvar/i) {
          if ($list_sources{$var_name}{$p_source}{'clinvar_study'} && $list_sources{$var_name}{$p_source}{'clinvar_study'}{$ref}) {
            my @data = keys(%{$list_sources{$var_name}{$p_source}{'clinvar_study'}{$ref}});
            foreach my $ext_ref (@data) {
              my $clinvar_ext_link = $hub->get_ExtURL_link('MIM:'.$ext_ref, 'OMIM', $ext_ref);
              if (!grep {$clinvar_ext_link eq $_} @ext_ref_list) {
                push(@ext_ref_list, $clinvar_ext_link);
              }
            }
          }
        }
      }

      # P-value data
      if ($list_sources{$var_name}{$p_source}{'p-value'}) {
        foreach my $pval (@{$list_sources{$var_name}{$p_source}{'p-value'}}) {
          if (!grep {$pval eq $_} @pvalues_list) {
            push(@pvalues_list, $pval);
            # Get the minimal exponential value of the p-values
            $pval =~ /^(\d+)\.?.*e-0?(\d+)$/i;
            if (!$max_exp) {
              $max_exp  = $2;
              $max_pval = $1;
            }
            elsif ($max_exp < $2) {
              $max_exp  = $2;
              $max_pval = $1;
            }
          }
        }
      }
    }

    if (scalar(keys(%sources_list))) {
    
      my $var_url = "$base_url;v=$var_name";

      # Sort by the lowest p-value first
      @pvalues_list = sort { $b =~ /e-0?$max_exp$/ <=> $a =~ /e-0?$max_exp$/ } @pvalues_list if (scalar @pvalues_list);

      @pvalues_list = map { $self->render_p_value($_, 1) } @pvalues_list;

      my $source_data = "";
      foreach my $source (sort(keys(%sources_list))) {
        my $div_id = 'src_'.$var_name.'_'.$source;
           $div_id =~ s/ //g;
        my @export_data = $source_exp_list{$source};
        my $source_content = $self->display_items_list($div_id,"$source entries",$source,$sources_list{$source},\@export_data,1,$max_items_per_source);

        $source_data .= ', ' if ($source_data ne "");
        if (scalar(@{$sources_list{$source}}) < $max_items_per_source ) {
          $source_data .= sprintf(qq{<span class="_no_export">%s</span><span class="hidden export">%s</span>}, $source_content,join(',',@export_data));
        }
        else {
          $source_data .= $source_content;
        }
      }

      my $row = {
            ID      => qq{<a href="$var_url">$var_name</a>},
            class   => $list_variations->{$var_name}{'class'},
            Alleles => $list_variations->{$var_name}{'allele'},
            chr     => $list_variations->{$var_name}{'chr'},
            psource => $source_data,
            pstudy  => (scalar @ext_ref_list) ? join(', ',@ext_ref_list) : '-',
            pvalue  => (scalar @pvalues_list) ? qq{<span class="hidden">$max_exp.$max_pval</span>} . join(', ', @pvalues_list) : '-'
      };

      $row->{'phe'} = join('; ',keys(%{$list_phe{$var_name}})) if ($all_flag == 1);

      push @rows, $row;
    }
  }    
  return \@rows;
}


sub source_link {
  my ($self, $source, $ext_id, $vname, $gname, $phenotype) = @_;
  
  my $source_uc = uc $source;
     $source_uc =~ s/\s/_/g;

  if ($ext_id) {
    $source_uc .= '_ID' if $source_uc =~ /COSMIC/;
    $source_uc  = $1 if $source_uc =~ /(HGMD)/;
  }
  $source_uc .= '_SEARCH' if $source_uc =~ /UNIPROT/;
  my $url = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};

  if ($url =~/ebi\.ac\.uk\/gwas/) {
    my $search = ($vname) ? $vname : $phenotype;
    $url =~ s/###ID###/$search/;
  }
  elsif ($url =~ /omim/ && $ext_id && $ext_id ne 'no-ref') {
    $ext_id =~ s/MIM\://;
    $url =~ s/###ID###/$ext_id/;
  }
  elsif ($url =~ /clinvar/ && $ext_id && $ext_id ne 'no-ref') {
    $ext_id =~ /^(.+)\.\d+$/;
    $ext_id = $1 if ($1);
    $url =~ s/###ID###/$ext_id/;
  }
  elsif ($vname || $gname) {
    if ($url =~ /omim/) {
      my $search = "search?search=".($vname || $gname);
      $url =~ s/###ID###/$search/; 
    } 
    elsif ($url =~ /hgmd/) {
      $url =~ s/###ID###/$gname/;
      $url =~ s/###ACC###/$vname/;
    } 
    elsif ($url =~/cosmic/) {
      if ($vname) {
        my $cname = ($vname =~ /^COSM(\d+)/) ? $1 : $vname;
        $url =~ s/###ID###/$cname/;
      }
      else {
        $url =~ s/###ID###/$gname/;
      }
    }
    else {
      $url =~ s/###ID###/$vname/;
    }
  }
  elsif ($url =~ /(.+)\?/) { # Only general source link
    $url = $1;
  }
  else {
    $url =~ s/###ID###//;
  }
  return $url ? qq{<a rel="external" href="$url">$source</a>} : $source;
}


sub external_reference_link {
  my ($self, $source, $study, $phenotype) = @_;
  my $hub = $self->hub;
  
  if ($study =~ /(pubmed|PMID)/) {
    my $study_id = $study;
       $study_id =~ s/pubmed\///;
       $study_id =~ s/PMID://;
    my $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
       $link =~ s/###ID###/$study_id/;
    $study =~ s/\//:/g;
    $study =~ s/pubmed/PMID/;
    return qq{<a rel="external" href="$link">$study</a>};
  }
  elsif ($study =~ /^MIM\:/) {
    my $id = (split /\:/, $study)[-1];
    my $link = $hub->get_ExtURL_link($study, 'OMIM', $id);
    $link =~ s/^\, //g;
    return $link;
  }
  elsif ($phenotype =~ /cosmic/i) {
    my @tumour_info      = split /\:/, $phenotype;
    my $tissue           = pop(@tumour_info);
    $tissue              =~ s/^\s+//;
    my $tissue_formatted = $tissue;
    my $source_study     = uc($source) . '_STUDY'; 
    $tissue_formatted    =~ s/\s+/\_/g; 
    return $hub->get_ExtURL_link($tissue, $source_study, $tissue_formatted);
  }
  else {
    return '-';
  }
}

sub check_source {
  my $self        = shift;
  my $source_name = shift;

  return ($source_name eq 'COSMIC') ? 1 : 0;
}

1;
