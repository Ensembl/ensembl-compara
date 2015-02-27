=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::GenePhenotypeVariation;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

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
  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;
  my $html;
  
  # Check if a variation database exists for the species.
  if ($hub->database('variation')) {
    my $no_data = '<p>No phenotypes associated with variants in this gene.</p>';
    # Variation phenotypes
    if ($phenotype) {
      my $table_rows = $self->variation_table($phenotype, $display_name);
      my $table      = $table_rows ? $self->make_table($table_rows, $phenotype) : undef;

      $html .= $table ? $self->render_content($table, $phenotype) : $no_data;
    } else {
      # no sub-table selected, just show stats
      my $table = $self->stats_table($display_name);
      $html .= $table ? $self->render_content($table) : $no_data; 
    }
  }
  
  return $html;
}


sub make_table {
  my ($self, $table_rows, $phenotype) = @_;
    
  my $columns = [
    { key => 'ID',       sort => 'html',      title => 'Variant ID'                           },
    { key => 'chr' ,     sort => 'position',  title => 'Chr: bp'                              },
    { key => 'Alleles',  sort => 'string',                                  align => 'center' },
    { key => 'class',    sort => 'string',    title => 'Class',             align => 'center' },
    { key => 'psource',  sort => 'string',    title => 'Phenotype Sources'                    },
    { key => 'pstudy',   sort => 'string',    title => 'Phenotype Studies'                    },
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
    $html = qq(<a id="$self->{'id'}_top"></a><h2>Phenotypes associated with the gene from variation annotations</h2>) . $table->render;
  }

  return $html;
}

sub stats_table {
  my ($self, $gene_name) = @_;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $pf_adaptor    = $self->hub->database('variation')->get_PhenotypeFeatureAdaptor;
  my ($total_counts, %phenotypes, @va_ids);

  my $columns = [
    { key => 'phen',    title => 'Phenotype', sort => 'string', width => '35%'  },
    { key => 'source',  title => 'Source(s)', sort => 'string', width => '11%'  },
    $species_defs->ENSEMBL_CHROMOSOMES
    ? { key => 'loc',   title => 'Genomic locations', sort => 'none',   width => '16%'  }
    : (),
    $species_defs->ENSEMBL_MART_ENABLED
    ? { key => 'mart',  title => 'Biomart',   sort => 'none',   width => '13%'  }
    : (),
    { key => 'count',   title => 'Number of variants',  sort => 'numeric_hidden', width => '10%',   align => 'right'  },
    { key => 'view',    title => 'Show/hide details',   sort => 'none',           width => '10%',   align => 'center' }
  ];

  foreach my $pf ($gene_name ? @{$pf_adaptor->fetch_all_by_associated_gene($gene_name)} : ()) {
    next unless $pf->type eq 'Variation';
    my $var_name   = $pf->object->name;  
    my $phe        = $pf->phenotype->description;
    my $phe_source = $pf->source_name;
   
    $phenotypes{$phe} ||= { id => $pf->{'_phenotype_id'} , name => $pf->{'_phenotype_name'}};
    push @{$phenotypes{$phe}{'count'}},  $var_name   unless grep $var_name   eq $_, @{$phenotypes{$phe}{'count'}};
    push @{$phenotypes{$phe}{'source'}}, $phe_source unless grep $phe_source eq $_, @{$phenotypes{$phe}{'source'}};
    
    $total_counts->{$var_name} = 1;
  }  
  
  my $warning_text = qq{<span style="color:red">(WARNING: details table may not load for this number of variants!)</span>};
  my ($url, @rows);
  
  
  my $mart_somatic_url = $hub->species_defs->ENSEMBL_MART_ENABLED ? '/biomart/martview?VIRTUALSCHEMANAME=default'.
                         '&ATTRIBUTES=hsapiens_snp_som.default.snp.refsnp_id|hsapiens_snp_som.default.snp.chr_name|'.
                         'hsapiens_snp_som.default.snp.chrom_start|hsapiens_snp_som.default.snp.associated_gene'.
                         '&FILTERS=hsapiens_snp_som.default.filters.phenotype_description.&quot;###PHE###&quot;'.
                         '&VISIBLEPANEL=resultspanel' : '';
  my $max_lines = 1000;
  
  # add the row for ALL variations if there are any
  if (my $total = scalar keys %$total_counts) {
    my $warning = $total > $max_lines ? $warning_text : '';
  
    push @rows, {
      phen   => "ALL variations with a phenotype annotation $warning",
      count  => qq{<span class="hidden">-</span>$total}, # create a hidden span to add so that ALL is always last in the table
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => 'ALL' }), 'ALL'),
      source => '-',
      lview  => '-'
    };
  }
  
  foreach (sort keys %phenotypes) {
    my $phenotype    = $phenotypes{$_};
    my $table_id     = $_;
       $table_id     =~ s/[^\w]/_/g;
    my $phe_count    = scalar @{$phenotype->{'count'}};
    my $warning      = $phe_count > $max_lines ? $warning_text : '';
    my $sources_list = join ', ', map $self->source_link($_, undef, undef, $gene_name), @{$phenotype->{'source'}};
    my $loc          = '-';
    my $mart         = '-';
    
    # BioMart link
    if ($mart_somatic_url && grep {$_ eq 'COSMIC'} @{$phenotype->{source}}) {
      if ($pf_adaptor->count_all_by_phenotype_id($phenotype->{'id'}) > 250) {
        my $mart_phe_url = $mart_somatic_url;
        $mart_phe_url =~ s/###PHE###/$_/;
        $mart = qq{<a href="$mart_phe_url">View list in BioMart</a>};
      }
    }
    # Karyotype link
    if ($hub->species_defs->ENSEMBL_CHROMOSOMES) {
      $loc = sprintf '<a href="%s" class="karyotype_link">View on Karyotype</a>', $hub->url({ type => 'Phenotype', action => 'Locations', ph => $phenotype->{'id'}, name => $_ }) unless /HGMD/;
    }
       
    push @rows, {
      phen   => "$_ $warning",
      count  => $phe_count,
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => $_ }), $table_id),
      source => $sources_list,
      loc    => $loc,
      mart    => $mart,
    };
  }
 
  if (scalar @rows) { 
    return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', data_table_config => {iDisplayLength => 10}, sorting => [ 'type asc' ], exportable => 0 });
  }
}


sub variation_table {
  my ($self, $phenotype, $gene_name) = @_;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $gene_slice    = $object->get_Slice;
  my $g_region      = $gene_slice->seq_region_name;
  my $g_start       = $gene_slice->start;
  my $g_end         = $gene_slice->end;
  my $phenotype_sql = $phenotype;
     $phenotype_sql =~ s/'/\\'/; # Escape quote character
  my $db_adaptor = $hub->database('variation');
  my $pf_adaptor = $db_adaptor->get_PhenotypeFeatureAdaptor;
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
      
  foreach my $pf (grep {$_->type eq 'Variation'} @{$pf_adaptor->fetch_all_by_associated_gene($gene_name)}) {
      
    next if ($phenotype ne $pf->phenotype->description && $all_flag == 0);
    
    #### Phenotype ####
    my $var        = $pf->object;
    my $var_name   = $var->name;
    my $list_sources;

    if (!$list_variations->{$var_name}) {
      
      my $location;
      my $allele;
      foreach my $vf (@{$var->get_all_VariationFeatures()}) {
        my $vf_region = $vf->seq_region_name;
        my $vf_start  = $vf->start;
        my $vf_end    = $vf->end;
        my $vf_allele = $vf->allele_string;
        
        $vf_allele =~ s/(.{20})/$1\n/g;
        
        $location .= '<br />' if ($location);
        $allele   .= '<br />' if ($allele);
        if ($vf_region eq $g_region && $vf_start >= $g_start && $vf_end <= $g_end) {
          $location = "$vf_region:$vf_start" . ($vf_start == $vf_end ? '' : "-$vf_end");
          $allele   = $vf_allele;
          last;
        }
        else {
          $location .= "$vf_region:$vf_start" . ($vf_start == $vf_end ? '' : "-$vf_end");
          $allele   .= $vf_allele;
        }
      }
    
      $list_variations->{$var_name} = { 'class'      => $var->var_class,
                                        'chr'        => $location,
                                        'allele'     => $allele
                                      };
    }
      
    # List the phenotype sources for the variation
    my $phe_source = $pf->source_name;
    my $ref_source = $pf->external_reference;
    
    $list_phe{$var_name}{$pf->phenotype->description} = 1 if ($all_flag == 1);
    
    if ($list_sources{$var_name}{$phe_source}) {
      push (@{$list_sources{$var_name}{$phe_source}}, $ref_source) if $ref_source;
    }
    else {
      if ($ref_source) {
        $list_sources{$var_name}{$phe_source} = [$ref_source];
      }
      else {
        $list_sources{$var_name}{$phe_source} = ['no_ref'];
      }
    }
  }  

  foreach my $var_name (sort (keys %list_sources)) {
    my @sources_list;
    my @ext_ref_list;
    foreach my $p_source (sort (keys (%{$list_sources{$var_name}}))) {

      foreach my $ref (@{$list_sources{$var_name}{$p_source}}) {
        # Source link 
        my $s_link = $self->source_link($p_source, $ref, $var_name, $gene_name);
        if (!grep {$s_link eq $_} @sources_list) {
          push(@sources_list, $s_link);
        }
        # Study link
        my $ext_link = $self->external_reference_link($p_source, $ref, $phenotype);
        if (!grep {$ext_link eq $_} @ext_ref_list) {
          push(@ext_ref_list, $ext_link);
        }
      }
      
    }
    if (scalar(@sources_list)) {  
    
      my $var_url    = "$base_url;v=$var_name";
    
      my $row = {
            ID      => qq{<a href="$var_url">$var_name</a>},
            class   => $list_variations->{$var_name}{'class'},
            Alleles => $list_variations->{$var_name}{'allele'},
            chr     => $list_variations->{$var_name}{'chr'},
            psource => join(', ',@sources_list),
            pstudy  => join(', ',@ext_ref_list),
        };
          
      $row->{'phe'} = join('; ',keys(%{$list_phe{$var_name}})) if ($all_flag == 1);

      push @rows, $row;
    }
  }    
  return \@rows;
}


sub source_link {
  my ($self, $source, $ext_id, $vname, $gname) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  
  if ($ext_id) {
    $source_uc .= '_ID' if $source_uc =~ /COSMIC/;
    $source_uc  = $1 if $source_uc =~ /(HGMD)/;
  }
  my $url = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};

  if ($ext_id && $ext_id ne 'no-ref') {
    if ($url =~/gwastudies/) {
      $ext_id =~ s/pubmed\///; 
      $url    =~ s/###ID###/$ext_id/;
    } 
    elsif ($url =~ /omim/) {
      $ext_id    =~ s/MIM\://; 
      $url =~ s/###ID###/$ext_id/;
    } 
    else {
      $url =~ s/###ID###/$ext_id/;
    }
  } 
  elsif ($vname || $gname) {
    if ($url =~ /omim/) {
        my $search = "search?search=".($vname || $gname);
        $url =~ s/###ID###/$search/; 
    } 
    elsif ($url =~/hgmd/) {
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
  
  if ($study =~ /pubmed/) {
    return qq{<a rel="external" href="http://www.ncbi.nlm.nih.gov/$study">$study</a>};
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

1;
