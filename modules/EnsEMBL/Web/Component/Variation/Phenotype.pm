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

package EnsEMBL::Web::Component::Variation::Phenotype;

use strict;

use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $vf     = $self->hub->param('vf');
  my $freq_data = $object->freqs;
  my $pop_freq  = $self->format_frequencies($freq_data);

  my $html;
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this variant', $object->not_unique_location) if $object->not_unique_location;

  my $data = $object->get_external_data();

  return 'We do not have any external data for this variant' unless (scalar @$data);

  # Select only the phenotype features which have the same coordinates as the selected variation
  my $vf_object = ($vf) ? $self->hub->database('variation')->get_VariationFeatureAdaptor->fetch_by_dbID($vf) : undef;
  if ($vf_object) {
    my $chr   = $vf_object->seq_region_name;
    my $start = $vf_object->seq_region_start;
    my $end   = $vf_object->seq_region_end;
    my @new_data = grep {$_->seq_region_name eq $chr && $_->seq_region_start == $start && $_->seq_region_end == $end} @$data;
    $data = \@new_data;
  }

  my ($table_rows, $column_flags) = $self->table_data($data, $pop_freq);
  my $table      = $self->new_table([], [], { data_table => 1, sorting => [ 'disease asc' ] });
     
  if (scalar keys(%$table_rows) != 0) {
    $self->add_table_columns($table, $column_flags);
    $table->add_rows(@$_) for values %$table_rows;
    $html .= sprintf qq{<h3>Significant association(s)</h3>};
    $html .= $table->render;
  }
  
  return $html;
};

# Description : Simple function to just add the columns in the table (can be overwritten in mobile plugins)
# Arg1        : $table hash
# Returns     : $table(hash)
sub add_table_columns {
  my ($self, $table, $column_flags) = @_;
  
  my $is_somatic = $self->object->Obj->is_somatic;
  my $study      = ($is_somatic && $self->object->Obj->source =~ /COSMIC/i) ? 'Tumour site' : 'Study';
  
  $table->add_columns(
    { key => 'disease', title => 'Phenotype/Disease/Trait', align => 'left', sort => 'html' },
    { key => 'source',  title => 'Source(s)',               align => 'left', sort => 'html' },
  );
  if ($column_flags->{'s_evidence'}) {
    $table->add_columns({ key => 's_evidence', title => 'Supporting evidence(s)', align => 'left', sort => 'html' });
  }
  
  $table->add_columns({ key => 'study', title => $study, align => 'left', sort => 'html' });

  if ($column_flags->{'clin_sign'}) {
    $table->add_columns({ key => 'clin_sign', title => 'Clinical significance', align => 'left', sort => 'html' });
  }
    
  $table->add_columns({ key => 'genes',   title => 'Reported gene(s)',  align => 'left', sort => 'html' });
  
  if (!$is_somatic) {
    $table->add_columns(
      { key => 'allele',  title => 'Associated allele', align => 'left', sort => 'string', help => 'Most associated risk allele' },
    );
  }

  if ($column_flags->{'stats'}) {
    $table->add_columns({ key => 'stats',  title => 'Statistics', align => 'left', sort => 'none' });
  }

  $table->add_columns({ key => 'locations', align => 'left', title => 'Genomic Locations' });
  
  return $table;
}

sub table_data { 
  my ($self, $external_data, $pop_freq) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $is_somatic = $object->Obj->is_somatic;
  my %rows;
  my %column_flags;
   
  my $mart_somatic_url = $self->hub->species_defs->ENSEMBL_MART_ENABLED ? '/biomart/martview?VIRTUALSCHEMANAME=default'.
                         '&ATTRIBUTES=hsapiens_snp_som.default.snp.refsnp_id|hsapiens_snp_som.default.snp.chr_name|'.
                         'hsapiens_snp_som.default.snp.chrom_start|hsapiens_snp_som.default.snp.associated_gene'.
                         '&FILTERS=hsapiens_snp_som.default.filters.phenotype_description.&quot;###PHE###&quot;'.
                         '&VISIBLEPANEL=resultspanel' : '';
                 
  my %clin_review_status = (
                            'not classified by submitter'       => 0,
                            'classified by single submitter'    => 1,
                            'classified by multiple submitters' => 2,
                            'reviewed by expert panel'          => 3,
                            'reviewed by professional society'  => 4
                           );

  my $inner_table_open  = qq{<table style="border-spacing:0px"><tr><td style="padding:1px 2px"><b>};
  my $inner_table_row   = qq{</td></tr>\n<tr><td style="padding:1px 2px"><span class="hidden export">;</span><b>};
  my $inner_table_close = qq{</td></tr>\n</table>};

  my $review_status   = 'review_status';
  my $variation_names = 'variation_names';
  my @stats_col = ('p_value','odds_ratio','beta_coef');

  foreach my $pf (@$external_data) { 
    
    my $phenotype = $pf->phenotype->description;
    my $disorder  = $phenotype;
    
    if ($is_somatic) {
      $disorder =~ s/\:/ /;
      $disorder =~ s/\:/\: /;
      $disorder =~ s/\_/ /g;
    }
    
    my @data_row;

    if (exists $rows{lc $disorder}) { 
      @data_row = @{$rows{lc $disorder}};
    }
    
    my $id                 = $pf->{'_phenotype_id'};
    my $source_name        = $pf->source_name;
    my $study_name         = $pf->study ? $pf->study->name : '';
    my $disease_url        = $hub->url({ type => 'Phenotype', action => 'Locations', ph => $id, name => $disorder }); 
    my $external_id        = ($pf->external_id) ? $pf->external_id : $study_name;
    my $source             = $self->source_link($source_name, $external_id, $pf->external_reference, 1);
    my $external_reference = $self->external_reference_link($pf->external_reference) || $pf->external_reference; # use raw value if can't be made into a link
    my $associated_studies = $pf->associated_studies; # List of Study objects
    my $attributes         = $pf->get_all_attributes();

    my $clin_sign_list = $pf->clinical_significance;
    my $clin_sign;
    if ($clin_sign_list) {
      # Clinical significance icons
      $clin_sign .= qq{<span class="hidden export">$clin_sign_list</span>};
      foreach my $clin_sign_term (split(',',$clin_sign_list)) {
        my $clin_sign_icon = $clin_sign_term;
        $clin_sign_icon =~ s/ /-/g;
        if ($attributes->{$review_status}) {;
           $clin_sign .= qq{<img class="clin_sign" src="/i/val/clinsig_$clin_sign_icon.png" />};
        }
        else {
          $clin_sign .= qq{<img class="_ht clin_sign" src="/i/val/clinsig_$clin_sign_icon.png" title="$clin_sign_term" />};
        }
      }

      # ClinVar review stars
      if ($attributes->{$review_status}) {
        my $clin_status = $attributes->{$review_status};
        my $count_stars = $clin_review_status{$clin_status};
        my $stars = "";
        for (my $i=1; $i<5; $i++) {
          my $star_color = ($i <= $count_stars) ? 'gold' : 'grey';
           $stars .= qq{<img class="review_status" src="/i/val/$star_color\_star.png" alt="$star_color"/>};
        }
        $clin_sign_list =~ s/,/, /g;
        $clin_sign  = qq{<div class="_ht nowrap clin_sign">$clin_sign$stars};
        $clin_sign .= $self->helptip(qq{<b>$clin_sign_list</b><br />Review status: "$clin_status"});
        $clin_sign .= qq{</div>};
      }
      $column_flags{'clin_sign'} = 1;
    }
    
    # Add the supporting evidence source(s)
    my $a_study_source;
    if (defined($associated_studies)) {
      $a_study_source = $self->supporting_evidence_link($associated_studies, $pf->external_reference);
    }

    if ($is_somatic && $disorder =~ /COSMIC/) {
      my @tumour_info      = split /\:/, $disorder;
      my $tissue           = $tumour_info[1];
      $tissue              =~ s/^\s+//;
      my $tissue_formatted = $tissue;
      my $source_study     = uc($source_name) . '_STUDY'; 
      $tissue_formatted    =~ s/\s+/\_/g; 
      $external_reference  = $hub->get_ExtURL_link($tissue, $source_study, $tissue_formatted);
    }
   
    my $gene         = $self->gene_links($pf->associated_gene);
    my $allele       = $self->allele_link($pf->external_reference, $pf->risk_allele) || $pf->risk_allele;
    my $disease      = qq{<b>$disorder</b>};

    # Associated variants
    my $var_names    = $attributes->{$variation_names};
    my $variant_link;
    if ($var_names) {
      $column_flags{'variant'} = 1;
      $variant_link = $self->variation_link($var_names);
    }
    
    # BioMart link
    my $bm_flag = 0;
    my $locations;
    if ($disease =~ /COSMIC/ && $mart_somatic_url) { 
      if ($pf->adaptor->count_all_by_phenotype_id($id) > 250) {
        $disease_url = $mart_somatic_url;
        $disease_url =~ s/###PHE###/$phenotype/;
        $locations = qq{<a href="$disease_url">View list in BioMart</a>};
        $bm_flag = 1;
      }
    }
    # Karyotype link
    if ($bm_flag == 0) {
      $locations = qq{<a href="$disease_url" class="karyotype_link">View on Karyotype</a>} unless ($disease =~ /HGMD/);
    }

    # Stats column
    my $stats_values;
    my @stats;
    foreach my $attr (@stats_col) {
      if ($attributes->{$attr}) {
        my $attr_label = ($attr eq 'beta_coef') ? 'beta_coefficient' : (($attr eq 'p_value') ? 'p-value' : $attr);
        push @stats, "$attr_label:".$attributes->{$attr};
        $column_flags{'stats'} = 1;
      }
    }
    if (@stats) {
      $stats_values  = $inner_table_open;
      $stats_values .= join($inner_table_row, map { s/:/:<\/b><\/td><td style="padding:1px 2px">/g; s/_/ /g ;$_ } @stats);
      $stats_values .= $inner_table_close;
    }
    else {
      $stats_values = '-';
    }

    if ($allele) {
      my $has_freq = 0;
      my $allele_title = '';
      foreach my $pop_name (sort { ($a !~ /ALL/ cmp $b !~ /ALL/) || $a cmp $b } keys %$pop_freq) {
        if ($pop_freq->{$pop_name}{'freq'}{$allele}) {
          my $freq = $pop_freq->{$pop_name}{'freq'}{$allele};
          my $group = $pop_freq->{$pop_name}{'group'};
          $allele_title .= ($allele_title eq '') ? "$group population frequencies for the allele <b>$allele</b>:<ul>" : '';
          $allele_title .= '<li>'.$pop_freq->{$pop_name}{'desc'};
          $allele_title .= ' ('.$pop_freq->{$pop_name}{'label'}.')' if ($pop_freq->{$pop_name}{'desc'} ne $pop_freq->{$pop_name}{'label'});
          $allele_title .= ' = ';
          $allele_title .= ($freq > 0.01) ? $freq : qq{<span style="color:#D00">$freq</span>};
          $allele_title .= '</li>';
        }
      }
      if ($allele_title ne '') {
        $allele_title .= '</ul>';
        $allele = qq{<span class="ht _ht">}.$self->helptip($allele_title).qq{$allele</span>};
      }
    }


    my $row = {
      disease   => $disease,
      source    => $source,
      study     => ($external_reference) ? $external_reference : '-',
      clin_sign => ($clin_sign) ? $clin_sign : '-',
      genes     => ($gene) ? $gene : '-',
      allele    => ($allele) ? $allele : '-',
      variant   => ($variant_link) ? $variant_link : '-',
      stats     => $stats_values,
      locations => $locations
    };
  
    if ($a_study_source){
      $row->{s_evidence} = $a_study_source;
      $column_flags{s_evidence} = 1;
    }
    else {
     $row->{s_evidence} = '-';
    }

    push @data_row, $row;
    $rows{lc $pf->phenotype->description} = \@data_row;
  } 

  return \%rows,\%column_flags;
}


sub gene_links {
  my ($self, $data) = @_;
  
  return unless $data;
  
  my $hub   = $self->hub;
  my @genes = split(',', $data);
  my @links;
  
  my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core');
  my $tr_adaptor   = $hub->get_adaptor('get_TranscriptAdaptor', 'core');
  my $arch_adaptor = $hub->get_adaptor('get_ArchiveStableIdAdaptor', 'core');
  
  foreach my $g (@genes) {
    
    $g =~ s/\s//g;
    my $gname = $g; 
    my $trname;
    
    if ($g =~ /^(\S+)_(\S+)/) {
      $gname = $1;
      $trname = $2;
    }
    
    
    # try to fetch gene & transcript
    my $linkable = 0;
    my $tr_linkable = 0;
    
    # external name
    $linkable = 1 if scalar @{$gene_adaptor->fetch_all_by_external_name($gname)};
    # stable_id
    unless($linkable) {
      $linkable = 1 if $gene_adaptor->fetch_by_stable_id($gname);
    }
    # archive stable_id
    unless($linkable) {
      $linkable = 1 if $arch_adaptor->fetch_by_stable_id($gname);
    }
    
    if ($trname) {
      $tr_linkable = 1 if $tr_adaptor->fetch_by_stable_id($trname);
    }
    
    if ($linkable) {
      my %params = ( type => 'Gene', action => 'Summary', g => $gname );
      $params{t} = $trname if ($tr_linkable);
      my $url = $hub->url(\%params);
      push @links, qq{<a href="$url">$g</a>};
    } else { 
      push @links, $g;
    }
  }
  
  my $gene_links = join ', ', @links; 
  
  return $gene_links;
}


sub source_link {
  my ($self, $source, $ext_id, $ext_ref_id, $code) = @_;
  
  my $source_uc = uc $source;
     $source_uc =~ s/\s/_/g;
  my $url       = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  my $label     = $source;
  my $name;
  if ($url =~ /ega/) {
    my @ega_data = split('\.',$ext_id);
    $name = (scalar(@ega_data) > 1) ? $ega_data[0].'*' : $ega_data[0];
    $label = $ext_id;
  } 
  elsif ($url =~/ebi\.ac\.uk\/gwas/) {
    $name = $self->object->name;
  } 
  elsif ($url =~ /clinvar/) {
    $ext_id =~ /^(.+)\.\d+$/;
    $name = ($1) ? $1 : $ext_id;
  } 
  elsif ($url =~ /omim/) {
    if ($code) {
      $name = "search?search=".$self->object->name;
    }
    else {
      $ext_ref_id =~ s/MIM\://; 
      $name = $ext_ref_id;
    }     
  } else {
    $name = $self->object->Obj->name;
  }
  
  $url =~ s/###ID###/$name/;
  
  return $source if $url eq "";
  
  return qq{<a rel="external" href="$url">$label</a>};
}


sub external_reference_link {
  my ($self, $study, $allele) = @_;
  my $link;
  if($study =~ /pubmed/) {
    my $study_id = $study;
       $study_id =~ s/pubmed\///;
    $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
    $link =~ s/###ID###/$study_id/;
    $study =~ s/\//:/g;
    $study =~ s/pubmed/PMID/;
    return qq{<a rel="external" href="$link">$study</a>};
  }
  
  elsif($study =~ /^MIM\:/) {
    foreach my $mim (split /\,\s*/, $study) {
      my $id = (split /\:/, $mim)[-1];
      my $sub_link;
      # Associated allele
      if (defined($allele)) {
        $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', '');
        my @parts = split /\"/, $sub_link;
        $parts[1] .= 'entry/'.$id.'#'.$allele;
        $parts[-1] =~ s/\>[^\<]+\</\>$allele\</;
        $sub_link = join('"', @parts);
      }
      # Study
      else {
        $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
      }
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
  my ($self, $associated, $ext_id) = @_;
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
      $as_html .= $self->source_link($st->source,$st->name,$ext_id);
    }
    # Temporary link to fix the problem of the non stable IDs for the EGA studies coming from dbGAP
    elsif ($a_url =~ /ega/ && $self->hub->species eq 'Homo_sapiens') {
      my $source = $st->source.'_SEARCH';
      $as_html .= $self->source_link($source,$st->name,$ext_id);
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
  my $self = shift;
  my $vars = shift;
     $vars =~ s/ //g;
  my $html;

  foreach my $v (split(',', $vars)) {
    my $url = $self->hub->url({ type => 'Variation', action => 'Explore', v => $v });
    $html .= ', ' if ($html);
    $html .= qq{<a href="$url">$v</a>};
  }
  return $html;
}


sub format_frequencies {
  my ($self, $freq_data) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  my $main_priority_level;

  # Get the main priority group level
  foreach my $pop_id (keys %$freq_data) {
    my $priority_level = $freq_data->{$pop_id}{'pop_info'}{'GroupPriority'};
    next if (!defined($priority_level));

    $main_priority_level = $priority_level if (!defined($main_priority_level) || $main_priority_level > $priority_level);
  }
  return undef if (!defined($main_priority_level));

  foreach my $pop_id (keys %$freq_data) {
    ## is it a priority project ?
    my $priority_level = $freq_data->{$pop_id}{'pop_info'}{'GroupPriority'};
    next if (!defined($priority_level) || $priority_level!=$main_priority_level);

    next if (scalar(keys(%{$freq_data->{$pop_id}{'pop_info'}{'Sub-Population'}})) == 0);

    my $pop_name = $freq_data->{$pop_id}{'pop_info'}{'Name'};

    my @composed_name = split(':', $pop_name);
    $pop_freq->{$pop_name}{'label'} = $composed_name[$#composed_name];
    $pop_freq->{$pop_name}{'desc'}  = length($freq_data->{$pop_id}{'pop_info'}{'Description'}) > 40 ? $pop_name : $freq_data->{$pop_id}{'pop_info'}{'Description'};
    $pop_freq->{$pop_name}{'group'} = $freq_data->{$pop_id}{'pop_info'}{'PopGroup'};

    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      next if $freq_data->{$pop_id}{$ssid}{'failed_desc'};

      my @allele_freq = @{$freq_data->{$pop_id}{'ssid'}{$ssid}{'AlleleFrequency'}};

      foreach my $gt (@{$freq_data->{$pop_id}{'ssid'}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;

        my $freq = $self->format_number(shift @allele_freq);

        $pop_freq->{$pop_name}{'freq'}{$gt} = $freq if $freq ne 'unknown';
      }
    }
  }

  return $pop_freq;
}

sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  if (defined $number) {
    $number = ($number < 0.01) ? sprintf '%.3f', $number : sprintf '%.2f', $number;
  }
  else {
    $number = 'unknown';
  }
  return $number;
}

sub helptip {
  ## Returns a dotted underlined element with given text and hover helptip
  ## @param Tip html
  my ($self, $tip_html) = @_;
  return $tip_html ? sprintf('<span class="_ht_tip hidden">%s</span>', encode_entities($tip_html)) : '';
}

1;
