# $Id$

package EnsEMBL::Web::Component::Gene::GenePhenotype;

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
  
  # Gene phenotypes  
  my $html = $phenotype ? '' : $self->gene_phenotypes('RenderAsTables', [ 'MIM disease' ]);
  
  # Check if a variation database exists for the species.
  if ($hub->database('variation')) {
    # Variation phenotypes
    if ($phenotype) {
      my $table_rows = $self->variation_table($phenotype, $display_name);
      my $table      = $table_rows ? $self->make_table($table_rows, $phenotype) : undef;

      $html .= $self->render_content($table, $phenotype);
    } else {
      $html .= $self->render_content($self->stats_table($display_name)); # no sub-table selected, just show stats
    }
  }
  
  return $html;
}


sub make_table {
  my ($self, $table_rows, $phenotype) = @_;
    
  my $columns = [
    { key => 'ID',       sort => 'html'                                                        },
    { key => 'chr' ,     sort => 'position',  title => 'Chr: bp'                               },
    { key => 'Alleles',  sort => 'string',                                  align => 'center' },
    { key => 'class',    sort => 'string',    title => 'Class',              align => 'center' },
    { key => 'psource',  sort => 'string',    title => 'Phenotype Sources'                    },
    { key => 'pstudy',    sort => 'string',    title => 'Phenotype Studies'                    },
    { key => 'status',   sort => 'string',    title => 'Validation',         align => 'center' },
  ];

  my $table_id = $phenotype;
     $table_id =~ s/[^\w]/_/g;
  
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
    
    $html = $self->toggleable_table("$phenotype associated variants", $table_id, $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>});
  } else {
    $html = qq{<a id="$self->{'id'}_top"></a><h2>Phenotypes associated with the gene from variation annotations</h2>} . $table->render;
  }

  return $html;
}

sub stats_table {
  my ($self, $gene_name) = @_;  
  my $hub        = $self->hub;
  my $va_adaptor = $self->hub->database('variation')->get_VariationAnnotationAdaptor;
  my ($total_counts, %phenotypes, @va_ids);
  
  my $columns = [
    { key => 'count',   title => 'Number of variants', sort => 'numeric_hidden', width => '10%', align => 'right'  },   
    { key => 'view',    title => '',                   sort => 'none',           width => '5%',  align => 'center' },
    { key => 'phen',    title => 'Phenotype',          sort => 'string',         width => '45%'                    },
    { key => 'source',  title => 'Source(s)',          sort => 'string',         width => '30%'                    },
    { key => 'kview',   title => 'Karyotype',          sort => 'none',           width => '10%'                    },
  ];
  
  foreach my $va (@{$va_adaptor->fetch_all_by_associated_gene($gene_name)}) {
    my $var_name   = $va->variation->name;  
    my $phe        = $va->phenotype_description;
    my $phe_source = $va->source_name;
    my $phe_ext    = $va->external_reference;
    
    $phenotypes{$phe} ||= { id => $va->{'_phenotype_id'} };
    push @{$phenotypes{$phe}{'count'}},  $var_name   unless grep $var_name   eq $_, @{$phenotypes{$phe}{'count'}};
    push @{$phenotypes{$phe}{'source'}}, $phe_source unless grep $phe_source eq $_, @{$phenotypes{$phe}{'source'}};
    
    $total_counts->{$var_name} = 1;
  }  
  
  my $warning_text = qq{<span style="color:red">(WARNING: table may not load for this number of variants!)</span>};
  my ($url, @rows);
  
  foreach (sort keys %phenotypes) {
    my $phenotype    = $phenotypes{$_};
    my $table_id     = $_;
       $table_id     =~ s/[^\w]/_/g;
    my $phe_count    = scalar @{$phenotype->{'count'}};
    my $warning      = $phe_count > 10000 ? $warning_text : '';
    my $sources_list = join ', ', map $self->source_link($_), @{$phenotype->{'source'}};
    my $kview        = '-';
       $kview        = sprintf '<a href="%s">[View on Karyotype]</a>', $hub->url({ type => 'Phenotype', action => 'Locations', ph => $phenotype->{'id'}, name => $_ }) unless /HGMD/;
       
    push @rows, {
      phen   => "$_ $warning",
      count  => $phe_count,
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => $_ }), $table_id),
      source => $sources_list,
      kview  => $kview
    };
  }
  
  # add the row for ALL variations if there are any
  if (my $total = scalar keys %$total_counts) {
    my $warning = $total > 10000 ? $warning_text : '';
  
    push @rows, {
      phen   => "All variations with a phenotype annotation $warning",
      count  => qq{<span class="hidden">-</span>$total}, # create a hidden span to add so that ALL is always last in the table
      view   => $self->ajax_add($self->ajax_url(undef, { sub_table => 'ALL' }), 'ALL'),
      source => '-',
      kview  => '-'
    };
  }
  
  return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', sorting => [ 'type asc' ], exportable => 0 });
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
  my $va_adaptor    = $hub->database('variation')->get_VariationAnnotationAdaptor;
  my (@rows, %list_sources, $list_variations);
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Phenotype',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  my $phenotype_sql = $phenotype;
  $phenotype_sql =~ s/'/\\'/; # Escape quote character
  
  my $va_adaptor = $self->hub->database('variation')->get_VariationAnnotationAdaptor;
  
  my %list_sources;
  my $list_variations;
      
  foreach my $va (@{$va_adaptor->fetch_all_by_associated_gene($gene_name)}) {
      
    next if ($phenotype ne $va->phenotype_description && $phenotype ne 'ALL');
    
    #### Phenotype ####
    my $var        = $va->variation;
    my $var_name   = $var->name;
    my $validation = $var->get_all_validation_states || [];
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
                                        'validation' =>  (join(', ',  @$validation) || '-'),
                                        'chr'        => $location,
                                        'allele'     => $allele
                                      };
    }
      
    # List the phenotype sources for the variation
    my $phe_source = $va->source_name;
    my $ref_source = $va->external_reference;
    
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
        my $s_link = $self->source_link($p_source, $ref, $var_name);
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
            status  => $list_variations->{$var_name}{'validation'},
            chr     => $list_variations->{$var_name}{'chr'},
            psource => join(', ',@sources_list),
            pstudy  => join(', ',@ext_ref_list),
          };
          
          push @rows, $row;
    }
  }    
  return \@rows;
}


sub source_link {
  my ($self, $source, $ext_id, $vname) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  my $url       = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  
  if ($ext_id && $ext_id ne 'no-ref') {
    if ($url =~ /ega/) {
      $url       =~ s/###ID###/$ext_id/;
    } elsif ($url =~/gwastudies/) {
      $ext_id    =~ s/pubmed\///; 
      $url          =~ s/###ID###/$ext_id/;
    } elsif ($url =~/omim/) {
      if ($vname) {
        $vname = "search?search=".$vname;
        $url  =~ s/###ID###/$vname/; 
      } else {
        $ext_id    =~ s/MIM\://; 
        $url  =~ s/###ID###/$ext_id/;
      }     
    } else {
      $url =~ s/###ID###/$vname/;
    }
  } else {
    $url =~ s/###ID###//; # Only general source link
  }
  return $url ? qq{<a rel="external" href="$url">[$source]</a>} : $source;
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


sub gene_phenotypes {
  my $self             = shift;
  my $output_as_table  = shift;
  my $types_list       = shift;
  my $object           = $self->object;
  my $obj              = $object->Obj;
  my $g_name           = $obj->stable_id;
  my @keys             = ('MISC');
  my @similarity_links = @{$object->get_similarity_hash($obj)};
  my $html             = qq{<br /><a id="gene_phenotype"></a><h2>List of phenotype(s) associated with the gene $g_name</h2>};
  my (@rows, $text, $current_key, $list_html);
  
  $self->_sort_similarity_links($output_as_table, @similarity_links);
  
  # to preserve the order, we use @links for access to keys
  foreach my $link (map @{$object->__data->{'links'}{$_} || []}, @keys) {
    my $key = $link->[0];
    
    next unless grep $key eq $_, @$types_list;
    
    push @rows, { dbtype => $key, dbid => $text } if $key ne $current_key && defined $current_key;
    
    $current_key = $key;
    
    $list_html .= qq{<tr><th style="white-space:nowrap;padding-right:1em"><strong>$key:</strong></th><td>};
    $text      .= "$link->[1]<br />";
  }  
  
  push @rows, { dbtype => $current_key, phenotype => $text } if defined $current_key;
  
  if ($output_as_table) {
    return $html . $self->new_table([ 
        { key => 'dbtype',      align => 'left', title => 'Database type' },
        { key => 'phenotype',   align => 'left', title => 'Phenotype'     }
      ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 })->render;
  } else {
    return "<table>$list_html</table>";
  }
}

1;
