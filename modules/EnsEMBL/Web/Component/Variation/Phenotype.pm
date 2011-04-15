# $Id$

package EnsEMBL::Web::Component::Variation::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $data = $object->get_external_data;
  
  return 'We do not have any external data for this variation' unless scalar @$data;
  
  my $is_somatic = $object->Obj->is_somatic;
  my $study      = $is_somatic ? 'Tumour site' : 'Study'; 
  my ($table_rows, $supporting_evidence) = $self->table_data($data);
  my $table      = $self->new_table([], [], { data_table => 1 });
   

  $table->add_columns(
    { key => 'disease', title => 'Disease/Trait',         align => 'left', sort => 'html' },  
    { key => 'source',  title => 'Source(s)',             align => 'left', sort => 'html' },
  );
  if ($supporting_evidence!=0) {
  	 $table->add_columns(
      { key => 's_evidence', title => 'Supporting evidence(s)', align => 'left', sort => 'html' }
	);
  }
  
  $table->add_columns(
		{ key => 'study',   title => $study,                  align => 'left', sort => 'html' },
    { key => 'genes',   title => 'Associated Gene(s)',    align => 'left', sort => 'none' },
    { key => 'variant', title => 'Associated variant',    align => 'left', sort => 'none' },
  );
  
  if (!$is_somatic) {
    $table->add_columns(
      { key => 'allele',  title => 'Most associated allele', align => 'left', sort => 'none'    },
      { key => 'pvalue',  title => 'P value',               align => 'left', sort => 'numeric' }
    );
  }
  
  $table->add_rows(@$_) for values %$table_rows;
	
  return $table->render;
};

sub table_data { 
  my ($self, $external_data) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $is_somatic = $object->Obj->is_somatic;
  my %rows;
  my $has_evidence = 0;
   
  foreach my $va (@$external_data) { 
    my $disorder = $va->phenotype_description;
    
    if ($is_somatic) {
      $disorder =~ s/\:/ /;
      $disorder =~ s/\:/\: /;
      $disorder =~ s/\_/ /g;
    }
    
    my @data_row;
        
    if (exists $rows{lc $disorder}) { 
      @data_row = @{$rows{lc $disorder}};
    }
    
    my $id           			 = $va->{'_phenotype_id'};
    my $code         			 = $va->phenotype_name;
    my $source_name  			 = $va->source_name;
		my $study_name         = $va->study_name;
    my $disease_url  			 = $hub->url({ type => 'Location', action => 'Genome', id => $id, ftype => 'Phenotype', somatic => $is_somatic, phenotype_name => $disorder }); 
		my $source             = $self->source_link($source_name, $study_name, $va->external_reference, $code);
		my $external_reference = $self->external_reference_link($va->external_reference) || $va->external_reference; # use raw value if can't be made into a link
    my $associated_studies = $va->associated_studies; # List of Study objects
		
		# Add the supporting evidence source(s)
		my $a_study_source='';
		if (defined($associated_studies)) {
			$a_study_source = $self->supporting_evidence_link($associated_studies, $va->external_reference, $code);
		}

    if ($is_somatic) { 
      my @tumour_info      = split /\:/, $disorder;
      my $tissue           = $tumour_info[1];
      my $tissue_formatted = $tissue;
      my $source_study     = uc($source_name) . '_STUDY'; 
      $tissue              =~ s/^\s+//;
      $tissue_formatted    =~ s/\s+/\_/g; 
      $external_reference  = $hub->get_ExtURL_link($tissue, $source_study, $tissue_formatted);
    }
   
    my $gene         = $self->gene_links($va->associated_gene);
    my $allele       = $self->allele_link($va->external_reference, $va->associated_variant_risk_allele) || $va->associated_variant_risk_allele;
    my $variant_link = $self->variation_link($va->variation->name);
    my $pval         = $va->p_value;
    
    my $disease;
    $disease = $code ? qq{<dt>$disorder ($code)} : qq{<dt>$disorder} if $disorder =~ /^\w+/;
    $disease .= qq{ <a href="$disease_url">[View on Karyotype]</a></dt>} unless $disease =~ /HGMD_MUTATION/;
    
	
	
    my $row = {
      disease => $disease,
      source  => $source,
      study   => $external_reference, 
      genes   => $gene,
      allele  => $allele,
      variant => $variant_link,
      pvalue  => $pval
    };
	
	if ($a_study_source ne ''){
		$row->{s_evidence} = $a_study_source;
		$has_evidence = 1;
	}
    
    push @data_row, $row;
    $rows{lc $va->phenotype_description} = \@data_row;
  } 

  return \%rows,$has_evidence;
}

sub gene_links {
  my ($self, $data) = @_;
  
  return unless $data;
  
  my $hub   = $self->hub;
  my @genes = split /,/, $data;
  my @links;
  
  my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core');
  my $arch_adaptor = $hub->get_adaptor('get_ArchiveStableIdAdaptor', 'core');
  
  foreach my $g (@genes) {
    
    # try to fetch gene
    my $linkable = 0;
    
    # external name
    $linkable = 1 if scalar @{$gene_adaptor->fetch_all_by_external_name($g)};
    # stable_id
    unless($linkable) {
      $linkable = 1 if $gene_adaptor->fetch_by_stable_id($g);
    }
    # archive stable_id
    unless($linkable) {
      $linkable = 1 if $arch_adaptor->fetch_by_stable_id($g);
    }
    
    if ($linkable) {
      my $url = $hub->url({ type => 'Gene', action => 'Summary', g => $g });
      push @links, qq{<a href="$url">$g</a>};
    } else { 
      push @links, $g;
    }
  }
  
  my $gene_links = join ',', @links; 
  
  return $gene_links;
}


sub source_link {
  my ($self, $source, $ega_id, $ext_id, $code) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  my $url       = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  
  if ($url =~ /ega/) {
    $url       =~ s/###ID###/$ega_id/;
    $url       =~ s/###D###/$code/;
  } elsif ($url =~/gwastudies/) {
    $ext_id    =~ s/pubmed\///; 
    $url          =~ s/###ID###/$ext_id/;       
  } else {
    my $name = $self->object->Obj->name;
    $url =~ s/###ID###/$name/;
  }
	return $source if $url eq "";
  
  return qq{<a rel="external" href="$url">[$source]</a>};
}


sub external_reference_link {
  my ($self, $study, $allele) = @_;
  
  if($study =~ /pubmed/) {
    return qq{<a rel="external" href="http://www.ncbi.nlm.nih.gov/$study">$study</a>};
  }
  
  elsif($study =~ /^MIM\:/) {
    my $link;
    
    foreach my $mim(split /\,\s*/, $study) {
      my $id = (split /\:/, $mim)[-1];
      my $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
      my @parts = split /\"/, $sub_link;
      $parts[1] .= '#'.$id.'Variants'.$allele if defined($allele);
      $parts[-1] =~ s/\>[^\<]+\</\>$allele\</ if (defined($allele));
      $sub_link = join '"', @parts;
      $link .= ', '.$sub_link;
      $link =~ s/^\, //g;
    }
    
    return $link;
  }
  else {
    return '';
  }
}


# Supporting evidence links
sub supporting_evidence_link {
	my ($self, $associated, $ext_id, $code) = @_;
	my $as_html = '';
	my $count = 0;
	my $se_by_line = 2;
	foreach my $st (@{$associated}) {
		if ($as_html ne '') { $as_html .= ', '; }
		if ($count==$se_by_line) {
			$as_html .= '<br />';
			$count = 0;
		}
		my $a_url = $st->url;
		if (!defined($a_url)) {
			$as_html .= $self->source_link($st->source,$st->name,$ext_id,$code);
		}
		else {
			my $a_source = $st->source;
			if ($st->name) { $a_source = $st->name; }
			$as_html .= qq{<a rel="external" href="$a_url">[$a_source]</a>};
		}
		$count++;
	}
	return $as_html;
}


sub allele_link {
	my ($self, $study, $allele) = @_;
	
	# Only create allele-specific link if the study is a OMIM record and the allele is defined
	return '' unless ($study =~ /^MIM\:/ && defined($allele));
	return $self->external_reference_link($study,$allele);
}


sub variation_link {
  my ($self, $v) = @_;
  my $url = $self->hub->url({ type => 'Variation', action => 'Summary', v => $v });
  return qq{<a href="$url">$v</a>};
}

1;
