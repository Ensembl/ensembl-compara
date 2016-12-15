
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Variation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self               = shift;
  my $hub                = $self->hub;
  my $object             = $self->object;
  my $variation          = $object->Obj;
  my $vf                 = $hub->param('vf');
  my $var_id             = $hub->param('v');
  my $variation_features = $variation->get_all_VariationFeatures;
  my ($feature_slice)    = map { $_->dbID == $vf ? $_->feature_Slice : () } @$variation_features; # get slice for variation feature
  my $avail              = $object->availability;  

  my ($info_box);
  if ($variation->failed_description || (scalar keys %{$object->variation_feature_mapping} > 1)) { 
    ## warn if variation has been failed
    $info_box = $self->multiple_locations($feature_slice, $variation->failed_description); 
  }
  
  my @str_array = $self->feature_summary($avail);
  
  my $summary_table = $self->new_twocol(    
    $self->most_severe_consequence($variation_features),
    $self->alleles($feature_slice),
    $self->location,
    $feature_slice ? $self->co_located($feature_slice) : (),
    $self->evidence_status,
    $self->clinical_significance,
    $self->hgvs,
    $self->object->vari_class eq 'SNP' ? () : $self->three_prime_co_located(),
    $self->synonyms,
    $self->sets,
    $self->variation_source,
    @str_array ? ['About this variant', sprintf('This variant %s.', $self->join_with_and(@str_array))] : (),
    ($hub->species eq 'Homo_sapiens' && $hub->snpedia_status) ? $var_id && $self->snpedia($var_id) : ()
  );

  return sprintf qq{<div class="summary_panel">$info_box%s</div>}, $summary_table->render;
}

# Description : about this variant paragraph on summary panel
# Arg1        : availability count
# Returns     : Array
sub feature_summary {
  my ($self, $avail) = @_;
  
  my $hub             = $self->hub;
  my $vf              = $hub->param('vf');
  my $transcript_url  = $hub->url({ action => "Variation", action => "Mappings",  vf => $vf });
  my $genotype_url    = $hub->url({ action => "Variation", action => "Sample",    vf => $vf });
  my $phenotype_url   = $hub->url({ action => "Variation", action => "Phenotype", vf => $vf });
  my $citation_url    = $hub->url({ action => "Variation", action => "Citations", vf => $vf });
 
  my @str_array;
  
  push @str_array, sprintf('overlaps <a class="dynamic-link" href="%s">%s %s</a>', 
                      $transcript_url, 
                      $avail->{has_uniq_transcripts}, 
                      $avail->{has_uniq_transcripts} eq "1" ? "transcript" : "transcripts"
                  ) if($avail->{has_uniq_transcripts});
  push @str_array, sprintf('%s<a class="dynamic-link" href="%s">%s %s</a>',
                      $avail->{has_uniq_transcripts} ? '' : 'overlaps ',
                      $transcript_url,
                      $avail->{has_regfeats},
                      $avail->{has_regfeats} eq "1" ? "regulatory feature" : "regulatory features"
                  ) if($avail->{has_regfeats});
  push @str_array, sprintf('has <a class="dynamic-link" href="%s">%s sample %s</a>', 
                      $genotype_url, 
                      $avail->{has_samples}, 
                      $avail->{has_samples} eq "1" ? "genotype" : "genotypes" 
                  )if($avail->{has_samples});
  push @str_array, sprintf('is associated with <a class="dynamic-link" href="%s">%s %s</a>', 
                      $phenotype_url, 
                      $avail->{has_ega}, 
                      $avail->{has_ega} eq "1" ? "phenotype" : "phenotypes"
                  ) if($avail->{has_ega});  
  push @str_array, sprintf('is mentioned in <a class="dynamic-link" href="%s">%s %s</a>', 
                      $citation_url, 
                      $avail->{has_citation}, 
                      $avail->{has_citation} eq "1" ? "citation" : "citations" 
                  ) if($avail->{has_citation});  
                  
  return @str_array;
}

sub multiple_locations {
  my ($self, $feature_slice, $failed) = @_;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my %mappings = %{$self->object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  my $html;
  my $header = $failed ? 'This variant has been flagged'
                          : "This variant maps to $count locations";
  
  if ($feature_slice) {
    for (0..$#descs) {
      my $seq    = $feature_slice->seq || '-';
         $seq    =~ s/(.{60})/$1\n/g;
      $descs[$_] =~ s/reference allele/reference allele ($seq)/ if $descs[$_] =~ /match.+reference allele/ && $feature_slice;
    }
  }
 
  ## Do a bit of user-friendly munging
  foreach (@descs) {
    if ($_ eq 'Variant maps to more than one genomic location') {
      $_ = "Variant maps to $count genomic locations"; 
    }
  }
 
  if (scalar @descs > 1) {
    $html  = '<ul>';
    $html .= "<li>$_</li>" foreach @descs;
    $html .= '</ul>';
  } else {
    $html = "<p>$descs[0]</p>";
  }

  my $hub       = $self->hub;
  my $vf        = $hub->param('vf');
  my $id        = $self->object->name;
  my $params    = $hub->core_params;
  my @locations = ({ value => 'null', name => 'None selected' });
    
  # add locations for each mapping
  foreach (sort { $mappings{$a}{'Chr'} cmp $mappings{$b}{'Chr'} || $mappings{$a}{'start'} <=> $mappings{$b}{'start'}} keys %mappings) {
    my $region = $mappings{$_}{'Chr'}; 
    my $start  = $mappings{$_}{'start'};
    my $end    = $mappings{$_}{'end'};
    my $str    = $mappings{$_}{'strand'};
      
    push @locations, {
      value    => $_,
      name     => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse')),
      selected => $vf == $_ ? ' selected' : ''
    };
  }
    
  # ignore vf and region as we want them to be overwritten
  my $core_params = join '', map $params->{$_} && $_ ne 'vf' && $_ ne 'r' ? qq(<input name="$_" value="$params->{$_}" type="hidden" />) : (), keys %$params;

  ## Don't show dropdown if we only have one location
  ## (Array has to be greater than 2 since we have a 'none selected' "location" as well)
  if (scalar(@locations) > 2) {

    my $options     = join '', map qq(<option value="$_->{'value'}"$_->{'selected'}>$_->{'name'}</option>), @locations;

    my $label = $vf ? 'Selected location' : 'Select a location';

    $html .= sprintf('<form action="%s" method="get"><b>%s</b>: %s<select name="vf" class="fselect">%s</select> <input value="Go" class="fbutton" type="submit"></form>',
                  $hub->url({ vf => undef, v => $id, source => $self->object->source }),
                  $label,
                  $core_params,
                  $options,
                );
  }

  return $self->_info($header, $html, '50%');
}


sub variation_source {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $name    = $object->name;
  my $source  = $object->source;
  my $version = $object->source_version;
  my $url     = $object->source_url;
  my ($source_link, $sname);
  
  # Date version
  if ($version =~ /^(20\d{2})(\d{2})/) {
    $version = "$2/$1";
  }
  
  ## parse description for links
  (my $description = $object->source_description) =~ s/(\w+) \[(http:\/\/[\w\.\/]+)\]/<a href="$2" class="constant">$1<\/a>/; 
  my $source_prefix = 'View in';

  # Source link
  if ($source =~ /dbSNP/) {
    $sname       = 'DBSNP';
    $source_link = $hub->get_ExtURL_link("$source_prefix dbSNP", $sname, $name);
  } elsif ($source =~ /ClinVar/i) {
    $sname = ($name =~ /^rs/) ?  'CLINVAR_DBSNP' : 'CLINVAR';
    $source_link = $hub->get_ExtURL_link("About $source", $sname, $name);
  } elsif ($source =~ /SGRP/) {
    $source_link = $hub->get_ExtURL_link("About $source", 'SGRP_PROJECT');
  } elsif ($source =~ /COSMIC/) {
    my $cname = ($name =~ /^COSM(\d+)/) ? $1 : $name;
    $source_link = $hub->get_ExtURL_link("$source_prefix $source", $source, $cname);
  } elsif ($source =~ /HGMD/) {
    $version =~ /(\d{4})(\d+)/;
    $version = "$1.$2";
    my $pf          = ($hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation')->fetch_all_by_Variation($object->Obj))->[0];
    my $asso_gene   = $pf->associated_gene;
       $source_link = $hub->get_ExtURL_link("$source_prefix $source", 'HGMD', { ID => $asso_gene, ACC => $name });
  } elsif ($source =~ /ESP/) {
    if ($name =~ /^TMP_ESP_(\d+)_(\d+)/) {
      $source_link = $hub->get_ExtURL_link("$source_prefix $source", $source, { CHR => $1 , START => $2, END => $2});
    }
    else {
      $source_link = $hub->get_ExtURL_link("$source_prefix $source", "${source}_HOME");
    }
  } elsif ($source =~ /LSDB/) {
    $version = ($version) ? " ($version)" : '';
    $source_link = $hub->get_ExtURL_link("$source_prefix $source", $source, $name);
  }  elsif ($source =~ /PhenCode/) {
     $sname       = 'PHENCODE';
     $source_link = $hub->get_ExtURL_link("$source_prefix PhenCode", $sname, $name);
} else {
    $source_link = $url ? qq{<a href="$url" class="constant">$source_prefix $source</a>} : "$source $version";
  }
  
  $version = ($version) ? " (release $version)" : '';
  
  return ['Original source', sprintf('<p>%s%s%s%s</p>', $description, $version, $self->text_separator, $source_link)];
}


sub co_located {
  my ($self, $feature_slice) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');

  my $slice;
  if ($feature_slice->start > $feature_slice->end) { # Insertion
    my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor', 'core');
    $slice = $slice_adaptor->fetch_by_region( $feature_slice->coord_system_name, $feature_slice->seq_region_name,
                                              $feature_slice->end, $feature_slice->start, $feature_slice->strand );
  }
  else {
    $slice = $feature_slice;
  }

  my @variations = (@{$adaptor->fetch_all_by_Slice($slice)}, @{$adaptor->fetch_all_somatic_by_Slice($slice)});

  if (@variations) {
    my $name  = $self->object->name;
    my $start = $slice->start;
    my $end   = $slice->end;
    my $count = 0;
    my %by_source;
    
    foreach (@variations) {
      my $v_name = $_->variation_name; 
      
      next if $v_name eq $name;
      
      my $v_start = $_->start + $start - 1;
      my $v_end   = $_->end   + $start - 1;

      next unless $v_start == $feature_slice->start && $v_end == $feature_slice->end;

      my $link      = $hub->url({ action => 'Explore', v => $v_name, vf => $_->dbID });
      my $alleles   = ' ('.$_->allele_string.')' if $_->allele_string =~ /\//;
      my $variation = qq{<a href="$link">$v_name</a>$alleles};
      $count ++;

      push @{$by_source{$_->source_name}}, $variation;
    }
    
    if (scalar keys %by_source) {
      my $html;
      foreach (keys %by_source) {
        $html .= ($html) ? ' ; ': ' ';
        $html .= "<b>$_</b> ";
        $html .= join ', ', @{$by_source{$_}};
      }

      my $s = ($count > 1) ? 's' : '';

      return ["Co-located variant$s", $html];
    }
  }
  
  return ();
}

sub synonyms {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $synonyms = $object->dblinks;
  my ($count, $count_sources, @synonyms_list);
 
  foreach my $db (sort { lc $a cmp lc $b } keys %$synonyms) {
    my @ids = @{$synonyms->{$db}};
    my @urls;

    next if ($db =~ /(Affy|Illumina|HGVbase|TSC|dbSNP\sHGVS)/i);

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map $hub->get_ExtURL_link($_, 'DBSNP', $_), @ids;
    }
    elsif ($db =~ /dbsnp hgvs/i) {
      @urls = sort { $a !~ /NM_/ cmp $b !~ /NM_/ || $a cmp $b } @ids;
    }    
    elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        push @urls, $hub->get_ExtURL_link($_, 'DBSNP', $_);
      }
      next unless @urls;
    }
    elsif ($db =~ /clinvar/i) {
      @urls = map $hub->get_ExtURL_link($_, 'CLINVAR', $_), @ids;
    }
    elsif ($db =~ /Uniprot/) {
      push @urls, $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
    }
    elsif ($db =~ /PhenCode/) {
      push @urls, $hub->get_ExtURL_link($_, 'PHENCODE', $_) for @ids;
    }
    ## these are LSDBs who submit to dbSNP, so we use the submitter name as a synonym & link to the original site
    elsif ($db =~ /OIVD|LMDD|KAT6BDB|HbVar|PAHdb|Infevers|LSDB/) {
      my $db_uc = uc($db);
      push @urls, $hub->get_ExtURL_link($_, $db_uc, $_) for @ids;
    }
    else {
      @urls = @ids;
    }

    $count += scalar @urls;
    
    push @synonyms_list, "<strong>$db</strong> " . (join ', ', @urls);
  }
  
  $count_sources = scalar @synonyms_list;

  return () if ($count_sources == 0);  
 
  # Large text display
  if ($count_sources > 1) { # Collapsed div display 
    my $show = $self->hub->get_cookie_value('toggle_variation_synonyms') eq 'open';

    return [
      sprintf('Synonyms'),
      sprintf('<p>This variant has <strong>%s</strong> synonyms - <a title="Click to show synonyms" rel="variation_synonyms" href="#" class="toggle_link toggle %s _slide_toggle set_cookie ">%s</a></p><div class="variation_synonyms twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,        
        $show ? 'open' : 'closed',        
        $show ? 'Hide' : 'Show',
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @synonyms_list)
      )
    ];

  } else {
    return ['Synonyms', $synonyms_list[0] ];
  }
}

sub alleles {
  my ($self, $feature_slice) = @_;
  my $object      = $self->object;
  my $variation   = $object->Obj;
  my $alleles     = $object->alleles;
  my @l_alleles   = split '/', $alleles;
  my $c_alleles   = scalar @l_alleles;
  my $alt_string  = $c_alleles > 2 ? 's' : '';
  my $ancestor    = $object->ancestor;
     $ancestor    = "Ancestral: <strong>$ancestor</strong>" if $ancestor;
  my $ambiguity   = $variation->ambig_code;
     $ambiguity   = 'not available' if $object->source =~ /HGMD/;
     $ambiguity   = "Ambiguity code: <strong>$ambiguity</strong>" if $ambiguity;
  my $freq        = sprintf '%.2f', $variation->minor_allele_frequency;
     $freq        = '&lt; 0.01' if $freq eq '0.00'; # Frequency lower than 1%
  my $maf_helptip = $self->helptip('MAF', '<b>Minor Allele Frequency</b><br />It corresponds to the frequency of the second most frequent allele.');
  my $maf         = $variation->minor_allele;
     $maf         = sprintf(qq{<span class="_ht ht">%s</span>: <strong>%s</strong> (%s)},$maf_helptip,$freq,$maf) if $maf;
  my $html;
  my $alleles_strand = ($feature_slice) ? ($feature_slice->strand == 1 ? q{ (Forward strand)} : q{ (Reverse strand)}) : '';

  my $extra_allele_info = '';
  if ($ancestor || $ambiguity || $maf) {
    if ($ancestor) {
      $extra_allele_info .= $self->text_separator;
      $extra_allele_info .= qq{<span>$ancestor</span>};
    }
    if ($ambiguity) {
      $extra_allele_info .= $self->text_separator;
      $extra_allele_info .= qq{<span>$ambiguity</span>};
    }
    if ($maf) {
      $extra_allele_info .= $self->text_separator.$maf;
    }
  }

  # Check allele string size (for display issues)
  my $large_allele = 0;
  my $display_alleles;
  if (length($alleles) > 50) {
    foreach my $string_allele (@l_alleles) {
      $display_alleles .= '/' if ($display_alleles);
      $display_alleles .= substr($string_allele,0,50);
      if (length($string_allele) > 50) {
        $large_allele += 1;
        $display_alleles .= '...';
      }
    }
    if ($large_allele != 1) {
      $display_alleles = substr($alleles,0,50).'...';
      $large_allele = 1;
    }
    
    $alleles = join("/<br />", @l_alleles);
    my $show = $self->hub->get_cookie_value('toggle_Alleles') eq 'open';

    $html = sprintf(
     '<a class="toggle _ht %s _slide_toggle set_cookie" href="#" rel="Alleles" style="font-weight:bold;font-size:1.2em" title="Click to toggle Reference/Alternative%s alleles%s">%s</a>
      <small>Click the plus to show all of the alleles</small>%s
      <div class="Alleles"><div class="toggleable" style="font-weight:normal;%s">%s</div></div>',
      $show ? 'open' : 'closed',
      $alt_string,
      $alleles_strand,
      $display_alleles, $extra_allele_info,
      $show ? '' : 'display:none',
      "<pre>$alleles</pre>");
  }
  else {
    my $allele_title = ($alleles =~ /\//) ? qq{Reference/Alternative$alt_string alleles $alleles_strand} : qq{$alleles$alleles_strand};
    $alleles =~ s/\//<span style="color:black">\/<\/span>/g;
    $html = qq{<span class="_ht ht" style="font-weight:bold;font-size:1.2em" title="$allele_title">$alleles</span>$extra_allele_info};
  }

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $sequence = $feature_slice->seq;
    my $allele   = $l_alleles[0];
    
    if ($allele =~ /^[ACGTN]+$/) {
      my $seq   = length $sequence == 1 ? 'base': 'sequence';
      $sequence =~ s/(.{60})/$1<br \/>/g;
      
      if ($sequence ne $allele) {
        $html .= '<br />' if ($large_allele == 0);
        if (length $sequence < 50) {
          $html .= "<em>Note</em>: The reference $seq for this variant ($allele) does not match the Ensembl reference $seq ($sequence) at this location.";
        }
        else {
          $allele = substr($allele,0,50).'...' if (length $allele > 50);
          my $show2 = $self->hub->get_cookie_value('toggle_Sequence') eq 'open';
          $html  .= sprintf('<em>Note</em>: The reference %s for this variant (%s) does not match the Ensembl reference %s at this location.
                             <a class="toggle %s _slide_toggle set_cookie" href="#" rel="Sequence" title="Click to toggle Sequence"></a><small>Click the plus to show all of the sequence</small></a>
                             <div class="Sequence"><div class="toggleable" style="font-weight:normal;%s">%s</div></div>',
                            $seq,
                            $allele,
                            $seq,
                            $show2 ? 'open' : 'closed',
                            $show2 ? '' : 'display:none',
                            "<pre>$sequence</pre>"
                           );
        }
      }
    }
  }
  
  return [ 'Alleles', qq(<div class="twocol-cell">$html</div>) ];
}

sub location {
  my $self     = shift;
  my $object   = $self->object;
  my %mappings = %{$object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  
  return ['Location', 'This variant has not been mapped'] unless $count;
  
  my $hub = $self->hub;
  my $vf  = $hub->param('vf');
  my $id  = $object->name;
  my (@rows, $location, $location_link);
  
  if ($vf) {
    my $variation = $object->Obj;
    my $type     = $mappings{$vf}{'Type'};
    my $region   = $mappings{$vf}{'Chr'}; 
    my $start    = $mappings{$vf}{'start'};
    my $end      = $mappings{$vf}{'end'};


    my $coord = "$region:$start-$end";
    if ($start == $end) {
      $coord = "$region:$start";
    } elsif ( $start > $end ) {
      $coord = "$region</b>: between <b>$end</b> and <b>$start";
    } 
    
    $location = ucfirst(lc $type).' <b>'.$coord . '</b> (' . ($mappings{$vf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      '%s<a href="%s" class="constant">View in location tab</a>',
      $self->text_separator,
      $hub->url({
        type             => 'Location',
        action           => 'View',
        r                => $region . ':' . ($start - 50) . '-' . ($end + 50),
        v                => $id,
        vf               => $vf,
        source           => $object->source,
        contigviewbottom => ($variation->is_somatic ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal') . ($variation->failed_description ? ',variation_set_fail_all=normal' : '') . ',seq=normal'
      })
    );
  }
  else {
    $location = "This variant maps to $count genomic locations; <b>None selected</b>";
  }
  
  return [ 'Location', "$location$location_link" ];
}

sub evidence_status {
  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->evidence_status;
  
  return unless (scalar @$status);

  my $html;
  foreach my $evidence (sort {$b =~ /1000|hap/i <=> $a =~ /1000|hap/i || $a cmp $b} @$status){
    my $evidence_label = $evidence;
       $evidence_label =~ s/_/ /g;
    my $img_evidence =  sprintf(
                          '<img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" src="%s/val/evidence_%s.png" title="%s"/>',
                           $self->img_url, $evidence, $evidence_label
                        );
    my $url;

    if($evidence =~ /exac/i) {
      $url = $hub->get_ExtURL('EXAC', $object->name) 
    }
    else {

      my $url_type = 'Population';
         $url_type = 'Citations' if ($evidence =~ /cited/i);
         $url_type = 'Phenotype' if ($evidence =~ /phenotype/i);

      $url = $hub->url({
         type   => 'Variation',
         action => $url_type,
         v      => $object->name,
         vf     => $hub->param('vf')
       });
    }

    $html .= qq{<a href="$url">$img_evidence</a>};
  }

  my $src = $self->img_url.'/16/info12.png';
  my $img = qq{<img src="$src" class="_ht" style="vertical-align:bottom;margin-bottom:2px;" title="Click to see all the evidence status descriptions"/>}; 
  my $info_link = qq{<a href="/info/genome/variation/data_description.html#evidence_status" target="_blank">$img</a>};

  return [ "Evidence status $info_link" , $html ];
}


sub clinical_significance {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub; 
  my $clin_sign = $object->clinical_significance;

  return unless (scalar(@$clin_sign));
  
  my $src = $self->img_url.'/16/info12.png';
  my $img = qq{<img src="$src" class="_ht" style="vertical-align:bottom;margin-bottom:2px;" title="Click to see all the clinical significances"/>};
  my $info_link = qq{<a href="/info/genome/variation/data_description.html#clin_significance" target="_blank">$img</a>};

  my %clin_sign_icon;
  foreach my $cs (@{$clin_sign}) {
    my $icon_name = $cs;
    $icon_name =~ s/ /-/g;
    $clin_sign_icon{$cs} = $icon_name;
  }

  my $url = $hub->url({
    type   => 'Variation',
    action => 'Phenotype',
    v      => $object->name,
    vf     => $hub->param('vf')
  });

  my $cs_content = join("",
    map {
      sprintf(
        '<a href="%s"><img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" title="%s" src="%s/val/clinsig_%s.png" /></a>',
        $url, $_, $self->img_url, $clin_sign_icon{$_}
      )
    } sort { ($a !~ /pathogenic/ cmp $b !~ /pathogenic/) || $a cmp $b } @$clin_sign
  );

  return [ "Clinical significance $info_link" , $cs_content ];
}

sub hgvs {
  my $self      = shift;
  my $object    = $self->object;
  my $hgvs_urls = $object->get_hgvs_names_url(1);
  my $count     = 0;
  my $total     = scalar keys %$hgvs_urls;
  my $html;

  my $syn_source = 'dbSNP HGVS';

  my $refseq_hgvs = $object->Obj->get_all_synonyms($syn_source);
  my $has_list = 0;

  # Loop over and format the URLs
  foreach my $allele (keys %$hgvs_urls) {
    if ($total > 1) {
      $html .= qq{<p style="font-weight:bold">Variant allele $allele</p>};
    }

    if (scalar @{$hgvs_urls->{$allele}} > 1 | scalar @{$refseq_hgvs} > 1) {
      $html .= "<ul><li>";
      $html .= join('</li><li>', @{$hgvs_urls->{$allele}});
      $html .= "</li></ul>";
      $has_list = 1;
    }
    else {
      $html  .= join(', ', @{$hgvs_urls->{$allele}});
    }
    $count += scalar @{$hgvs_urls->{$allele}};
  }

  $count += scalar @{$refseq_hgvs};

  if (scalar(@$refseq_hgvs)) {
    if ($has_list) {
      # Create div + floated lists to html
      $html = sprintf(qq{
          <div>
            <div style="float:left;margin-right:15px"><h4>%s:</h4>%s</div>
            <div style="float:left"><h4>%s:</h4><ul><li>%s</li></ul></div>
            <div style="clear:both"></div>
          </div>
        },
        'Ensembl HGVS',
        $html,
        $syn_source,
        join('</li><li>', sort { $a !~ /NM_/ cmp $b !~ /NM_/ || $a cmp $b } @$refseq_hgvs)
      );
    }
    else {
      # Display refseq HGVS
      $html .= ', ' if ($html);
      $html .= join(', ', sort { $a !~ /NM_/ cmp $b !~ /NM_/ || $a cmp $b } @$refseq_hgvs);
    }
  }

  if (!$has_list and $html) {
    $html = "<p>$html</p>";
  }


  # Wrap the html
  if ($count > 1) {
    my $show = $self->hub->get_cookie_value('toggle_HGVS_names') eq 'open';

    return [
      sprintf('HGVS names'),
      sprintf(qq(<div class="twocol-cell">
        <p>This variant has <strong>%s</strong> HGVS names - <a title="Click to show HGVS names" rel="HGVS_names" href="#" class="toggle_link toggle %s _slide_toggle set_cookie ">%s</a></p>
        <div class="HGVS_names"><div class="toggleable"%s>$html</div></div>
      </div>), $count, $show ? 'open' : 'closed', $show ? 'Hide' : 'Show', $show ? '' : ' style="display:none"')
    ];
  } elsif ($count == 1) {
    return ['HGVS name', $html];
  } else {
    return ();
  }
  return ['HGVS name', 'None'];
}

sub sets{

  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;

  my $variation_sets = $object->get_variation_sub_sets('Genotyping chip variants');

  return unless defined $variation_sets ;

  my @genotyping_sets_list;

  foreach my $vs (@{$variation_sets}){
      push @genotyping_sets_list,  $vs->name();    
  }
  my $count = scalar @genotyping_sets_list;  
  
  if ($count > 3) {
    my $show = $self->hub->get_cookie_value('toggle_variation_sets') eq 'open';
  
    return [
      'Genotyping chips',
      sprintf('<p>This variant has assays on <strong>%s</strong> chips - <a title="Click to show chips" rel="variation_sets" href="#" class="toggle_link toggle %s _slide_toggle set_cookie ">%s</a></p><div class="variation_sets twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
        $show ? 'open' : 'closed',        
        $show ? 'Hide' : 'Show',
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @genotyping_sets_list)
      )
    ];
  }
  else {
    return scalar @genotyping_sets_list
      ? ['Genotyping chips', sprintf('This variant has assays on: %s', join(', ', @genotyping_sets_list))]
      : ()
    ;
  }
}

sub most_severe_consequence {
  my ($self, $variation_features) = @_;

  my $hub = $self->hub;
  my $vf  = $hub->param('vf');

  return () if (!$vf);

  foreach my $vf_object (@$variation_features) {
    if ($vf_object->dbID == $vf) {

      my $url = $hub->url({
         type   => 'Variation',
         action => 'Mappings',
         v      => $self->object->name,
      });

      my $html_consequence = $self->render_consequence_type($vf_object,1);

      # Check if the variant overlaps at least one transcript or regulatory feature.
      my $consequence_link = '';

      my $overlapping_features = $vf_object->get_all_TranscriptVariations;
         $overlapping_features = $vf_object->get_all_RegulatoryFeatureVariations if (scalar(@$overlapping_features) == 0);

      if (scalar(@$overlapping_features) != 0) {
        $consequence_link = sprintf(qq{
          <div class="text-float-left">%s<a href="%s" title="'Genes and regulation' page">See all predicted consequences</a></div>
        }, $self->text_separator(1), $url);
      }

      # Line display
      my $html = sprintf(qq{
         <div>
           <div class="text-float-left bold">%s</div>%s
           <div class="clear"></div>
         </div>},
         $html_consequence, $consequence_link
      );

      return [ 'Most severe consequence' , $html];
    }
  }
  return ();
}

## if an insertion/ deletion is described at its most 3' location 
## possible, is it co-located with other variants?
sub three_prime_co_located{
  my $self  = shift;

 my $shifted_co_located = $self->object->get_three_prime_co_located();

  return undef unless defined $shifted_co_located;

  my $count;
  my @scl;

  foreach my $scl (@{$shifted_co_located}){
    next if ($scl eq '');
    my $link      = $self->hub->url({ action => 'Explore', v => $scl });
    my $variation = qq{<a href="$link">$scl</a>};
    $count++;
    push @scl, $variation;
  }

  if ($count > 3) {
    my $show = $self->hub->get_cookie_value('toggle_shifted_co_located') eq 'open';
  
    return [
      'Variants with equivalent alleles',
      sprintf('<p>This variant has <strong>%s</strong> variants with equivalent alleles - <a title="Click to show variants" rel="shifted_co_located" href="#" class="toggle_link toggle %s _slide_toggle set_cookie ">%s</a></p><div class="shifted_co_located twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
        $show ? 'open' : 'closed',        
        $show ? 'Hide' : 'Show',
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @scl)
      )
    ];
  }
  else {

    my $html = join ', ', @scl;
    my $s = ($count > 1) ? 's' : '';
    return ($count && $count > 0)  ? ["Variant$s with equivalent alleles", $html] : ();
  }
}

sub text_separator {
  my $self            = shift;
  my $no_left_padding = shift;

  my $tclass = ($no_left_padding) ? 'text-right_separator' : 'text_separator';

  return qq{<span class="$tclass">|</span>};
}

# Fetch SNPedia information from snpedia.com
sub snpedia {
  my ($self, $var_id) = @_;
  my $hub = $self->hub;
  my $cache = $hub->cache;
  my $desc;
  my $key = $var_id . "_SNPEDIA_DESC";

  if($cache) {
    # Get from memcached
    $desc = $cache->get($key);
  }

  if ($desc) {
    if ($desc ne 'no_entry') {
      return [
        'Description from SNPedia',
        $desc
      ];
    }
    else {
      return ();
    }
  }
  else {
    # Fetch from snpedia
    my $object = $self->object;
    my $snpedia_wiki_results = $object->get_snpedia_data($var_id);
    if (!$snpedia_wiki_results->{'pageid'}) {
      $cache && $cache->set($key, 'no_entry', 60*60*24*7);
      return ();
    }
    
    my $snpedia_search_link = $hub->get_ExtURL_link('[More information from SNPedia]', 'SNPEDIA_SEARCH', { 'ID' => $var_id });
    if ($#{$snpedia_wiki_results->{desc}} < 0) {
      $snpedia_wiki_results->{desc}[0] = 'Description not available ' . $snpedia_search_link;
    }

    my $count = scalar @{$snpedia_wiki_results->{desc}}; 
    if ($count > 1) {
      my $show = 0;

      $desc =  sprintf( '%s...
                    <a title="Click to show synonyms" rel="snpedia_more_desc" href="#" class="toggle_link toggle %s _slide_toggle">%s</a>
                    <div class="toggleable snpedia_more_desc" style="%s">
                      %s
                      %s
                    </div>
                  ',
        shift $snpedia_wiki_results->{desc},
        $show ? 'open' : 'closed',        
        $show ? 'Hide' : 'Show',
        $show ? '' : 'display:none',
        join('', map "<p>$_</p>", @{$snpedia_wiki_results->{desc}}),
        $snpedia_search_link
      );

      $cache && $cache->set($key, $desc || 'no_entry', 60*60*24*7);

      return [
        'Description from SNPedia',
        $desc
      ];
    }
    else {
      $desc = $snpedia_wiki_results->{'desc'}[0];
      $cache && $cache->set($key, $desc || 'no_entry', 60*60*24*7);
      return $count ? 
        [ 'Description from SNPedia',  $desc]
        : ();
    }
  }
}

1;
