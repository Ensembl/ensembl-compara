
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
  my $self        = shift;
  my $hub         = $self->hub;
  my $phenotype   = $hub->param('sub_table');
	my $object      = $self->object;
	
	my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;
	
	# Gene phenotypes  
	my $html = $self->gene_phenotypes('RenderAsTables',['MIM disease']);
	
	# Variation phenotypes
  if ($phenotype){
		
		$phenotype ||= 'ALL';
		my $table_rows = $self->variation_table($phenotype, $display_name);
    my $table      = $table_rows ? $self->make_table($table_rows, $phenotype) : undef;
		return $self->render_content($table, $phenotype);
  } 
	else {
		my $table = $self->stats_table($display_name); # no sub-table selected, just show stats
    return $html.$self->render_content($table);
  }
}

sub make_table {
  my ($self, $table_rows, $phenotype) = @_;
    
  my $columns = [
    { key => 'ID',         sort => 'html'                                       	   	              },
    { key => 'chr' ,       sort => 'position',      title => 'Chr: bp'          	 	                },
    { key => 'Alleles',    sort => 'string',                                   		align => 'center' },
    { key => 'class',      sort => 'string',        title => 'Class',          		align => 'center' },
    { key => 'psource', 	 sort => 'string',        title => 'Phenotype Sources'                    },
		{ key => 'status',     sort => 'string',        title => 'Validation',     		align => 'center' },
  ];

  
	my $table_id = $phenotype;
	$table_id =~ s/[^\w]/_/g;
	
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 0, id => $table_id."_table" });
}

sub render_content {
  my ($self, $table, $phenotype) = @_;
  my $stable_id = $self->object->stable_id;
  my $html;
  
  if ($phenotype) {
    my $table_id = $phenotype;
		$table_id =~ s/[^\w]/_/g;
	
    $html = qq{
      <h2 style="float:left"><a href="#" class="toggle open" rel="$table_id">$phenotype associated variants</a></h2>
      <span style="float:right;"><a href="#$self->{'id'}_top">[back to top]</a></span>
      <p class="invisible">.</p>
    };

  } 
	else {
    $html = qq{<a id="$self->{'id'}_top"></a><h2>Phenotypes associated with the
gene from variation annotations</h2>};
  }
  
  $html .= sprintf '<div class="toggleable">%s</div>', $table->render;

  return $html;
}

sub stats_table {
	my ($self, $gene_name) = @_;	
  
	my $hub = $self->hub;
	
  my $columns = [
    { key => 'count', 	title => 'Number of variants', sort => 'numeric_hidden', width => '10%', align => 'right'  },   
    { key => 'view',  	title => '',                   sort => 'none',           width => '5%',  align => 'center' },
		{ key => 'phen',  	title => 'Phenotype',          sort => 'string',         width => '45%'                    },
		{ key => 'source',  title => 'Source(s)',      		 sort => 'string',         width => '30%'                    },
		{ key => 'kview',   title => 'Karyotype',          sort => 'none',           width => '10%'                    },
  ];

  my $total_counts;
  my $phenotypes;
  my $va_adaptor = $self->hub->database('variation')->get_VariationAnnotationAdaptor;
	my @va_ids;
	
  foreach my $va (@{$va_adaptor->fetch_all_by_associated_gene($gene_name)}) {
		my $var_name = $va->variation->name;	
				
    # Phenotype information
    my $phe        = $va->phenotype_description;
    my $phe_source = $va->source_name;
    my $phe_ext    = $va->external_reference;
    if (defined($phenotypes->{$phe})) {
      if (!grep{$var_name eq $_} @{$phenotypes->{$phe}{count}}) {
        push(@{$phenotypes->{$phe}{count}},$var_name);
      }
      if (!grep{$phe_source eq $_} @{$phenotypes->{$phe}{source}}) {
        push(@{$phenotypes->{$phe}{source}},$phe_source);
      }
    }
    else { 
      $phenotypes->{$phe}{count}  = [$var_name]; 
      $phenotypes->{$phe}{source} = [$phe_source];
	  	$phenotypes->{$phe}{id}     = $va->{'_phenotype_id'};
    }
    $total_counts->{$var_name} = 1;
  }	

  my @rows;
  
  my $warning_text = qq{<span style="color:red;">(WARNING: table may not load for this number of variants!)</span>};
  my $url;
	
  foreach my $phe (sort(keys %$phenotypes)) {
		$url = $self->ajax_url(undef,{sub_table => $phe});
		
		my $phe_count = scalar(@{$phenotypes->{$phe}{count}});
		my $warning = $phe_count > 10000 ? $warning_text : '';
		my $table_id = $phe;
		$table_id =~ s/[^\w]/_/g;
		my $view_html = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$table_id">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
       };
			 
		# Sources
		my $sources_list = '';
		foreach my $source (@{$phenotypes->{$phe}{source}}) {
			$sources_list .= ', ' if ($sources_list ne '');
			$sources_list .= $self->source_link($source);
		}
		
		my $kview = '-';
		if ($phe !~ /HGMD/) {
			my $phe_id = $phenotypes->{$phe}{id}; 
			my $kurl = $hub->url({ type => 'Phenotype', action => 'Locations', id => $phe_id, name => $phe }); 
			$kview = qq{<a href="$kurl">[View on Karyotype]</a>};
		}
		
    push @rows, {
        phen   => $phe.' '.$warning,
        count  => $phe_count,
        view   => $view_html,
				source => $sources_list,
				kview  => $kview
		};
	}
  
  # add the row for ALL variations if there are any
  if (my $total   = scalar keys %$total_counts) {
    $url = $self->ajax_url(undef,{sub_table => 'ALL'});
  
    # create a hidden span to add so that ALL is always last in the table
    my $hidden_span = qq{<span class="hidden">-</span>};
  
    my $view_html = qq{
	  <a href="$url" class="ajax_add toggle closed" rel="ALL">
	      <span class="closed">Show</span><span class="open">Hide</span>
	      <input type="hidden" class="url" value="$url" />
	      </a>
	  };
  

    my $warning = $total > 10000 ? $warning_text : '';
  
  	push @rows, {
	  		phen   => "All variations with a phenotype annotation $warning",
				count  => $hidden_span . $total,
				view   => $view_html,
				source => '-',
				kview  => '-'
    };
  }
  return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', sorting => [ 'type asc' ], exportable => 0 });
}


sub variation_table {
  my ($self, $phenotype, $gene_name) = @_;
  my $hub         = $self->hub;
	my $object      = $self->object;
  my @rows;
  
	# Gene coordinates
	my $gene_slice = $object->get_Slice;
	my $g_region   = $gene_slice->seq_region_name;
	my $g_start    = $gene_slice->start;
	my $g_end      = $gene_slice->end;
	
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
																			  'validation' =>	(join(', ',  @$validation) || '-'),
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
		foreach my $p_source (sort (keys (%{$list_sources{$var_name}}))) {
		
			foreach my $ref (@{$list_sources{$var_name}{$p_source}}) {
					#$sources_list .= ', ' if ($sources_list ne '');
					my $s_link = $self->source_link($p_source, $ref);
					if (!grep {$s_link eq $_} @sources_list) {
						push(@sources_list, $s_link);
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
        	};
          
      		push @rows, $row;
		}
	}		
  return \@rows;
}

sub source_link {
  my ($self, $source, $ext_id) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  my $url       = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
	# With study link
	if ($ext_id and $ext_id ne 'no-ref') {
		if ($url =~/gwastudies/i) {
    	$ext_id    =~ s/pubmed\///; 
    	$url       =~ s/###ID###/$ext_id/;
		} elsif ($url =~/omim/i) {
    	$ext_id    =~ s/MIM\://; 
    	$url  =~ s/###ID###/$ext_id/;
			$source .= ':'.$ext_id;     
  	}
	}
	# Only general source link
	else { $url       =~ s/###ID###//; }
	
	return $source if $url eq "";
  
  return qq{<a rel="external" href="$url">[$source]</a>};
}


sub gene_phenotypes {
  my $self            = shift;
	my $output_as_table = shift;
	my $types_list      = shift;
	
	my $object = $self->object;
	my $obj    = $object->Obj;
	my $g_name = $obj->stable_id;
	
	my $list_html;
	my @keys = ('MISC');
	my @similarity_links = @{$object->get_similarity_hash($obj)};
	$self->_sort_similarity_links($output_as_table, @similarity_links);
	my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
	# in order to preserve the order, we use @links for acces to keys
  
	my $html = qq{<br /><a id="gene_phenotype"></a><h2>List of phenotype(s) associated with the gene $g_name</h2>};
	
	my @rows;
	my $text;
	my $current_key;
	
	foreach my $link (@links) {
		my $key = $link->[0];
		
		next if (! grep {$key eq $_}  @$types_list);
		
		if ($key ne $current_key && defined($current_key)) {
			push @rows, { dbtype => $key, dbid => $text };
		}
		$current_key = $key;
		      
    $list_html .= qq{<tr><th style="white-space: nowrap; padding-right: 1em"><strong>$key:</strong></th><td>};
    $text .= "$link->[1]<br />";
		
	}	
	
	push @rows, { dbtype => $current_key, phenotype => $text } if (defined($current_key));
	
	if ($output_as_table) {
	
    return $html . $self->new_table([ 
      	{ key => 'dbtype',      align => 'left', title => 'Database type' },
      	{ key => 'phenotype',   align => 'left', title => 'Phenotype'     }
    	], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 })->render;
  } 
	else {
    return "<table>$list_html</table>";
  }
}
1;
