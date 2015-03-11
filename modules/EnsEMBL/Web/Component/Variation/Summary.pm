
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
  my $variation_features = $variation->get_all_VariationFeatures;
  my ($feature_slice)    = map { $_->dbID == $vf ? $_->feature_Slice : () } @$variation_features; # get slice for variation feature
  my $avail              = $object->availability;  

  my ($info_box);
  if ($variation->failed_description || (scalar keys %{$object->variation_feature_mapping} > 1)) { 
    ## warn if variation has been failed
    $info_box = $self->multiple_locations($feature_slice, $variation->failed_description); 
  }
  
  my $transcript_url  = $hub->url({ action => "Variation", action => "Mappings",    vf => $vf });
  my $genotype_url    = $hub->url({ action => "Variation", action => "Individual",  vf => $vf });
  my $phenotype_url   = $hub->url({ action => "Variation", action => "Phenotype",   vf => $vf });
  my $citation_url    = $hub->url({ action => "Variation", action => "Citations",   vf => $vf });
 
  my @str_array;
  push @str_array, sprintf('overlaps <a href="%s">%s %s</a>', 
                      $transcript_url, 
                      $avail->{has_transcripts}, 
                      $avail->{has_transcripts} eq "1" ? "transcript" : "transcripts"
                  ) if($avail->{has_transcripts});
  push @str_array, sprintf('has <a href="%s">%s individual %s</a>', 
                      $genotype_url, 
                      $avail->{has_individuals}, 
                      $avail->{has_individuals} eq "1" ? "genotype" : "genotypes" 
                  )if($avail->{has_individuals});
  push @str_array, sprintf('is associated with <a href="%s">%s %s</a>', 
                      $phenotype_url, 
                      $avail->{has_ega}, 
                      $avail->{has_ega} eq "1" ? "phenotype" : "phenotypes"
                  ) if($avail->{has_ega});  
  push @str_array, sprintf('is mentioned in <a href="%s">%s %s</a>', 
                      $citation_url, 
                      $avail->{has_citation}, 
                      $avail->{has_citation} eq "1" ? "citation" : "citations" 
                  ) if($avail->{has_citation});

  my $summary_table = $self->new_twocol(    
    $self->variation_source,
    $self->alleles($feature_slice),
    $self->location,
    $feature_slice ? $self->co_located($feature_slice) : (),
    $self->most_severe_consequence($variation_features),
    #$self->validation_status,
    $self->evidence_status,
    $self->clinical_significance,
    $self->synonyms,
    $self->hgvs,
    $self->sets,
    @str_array ? ['About this variant', sprintf('This variant %s.', $self->join_with_and(@str_array))] : ()
  );

  return sprintf qq{<div class="summary_panel">$info_box%s</div>}, $summary_table->render;
}

sub multiple_locations {
  my ($self, $feature_slice, $failed) = @_;
  my @descs = @{$self->object->Obj->get_all_failed_descriptions};
  my %mappings = %{$self->object->variation_feature_mapping};
  my $count    = scalar keys %mappings;
  my $html;
  my $header = $failed ? 'This variation has been flagged'
                          : "This variation maps to $count locations";
  
  if ($feature_slice) {
    for (0..$#descs) {
      my $seq    = $feature_slice->seq || '-';
         $seq    =~ s/(.{60})/$1\n/g;
      $descs[$_] =~ s/reference allele/reference allele ($seq)/ if $descs[$_] =~ /match.+reference allele/ && $feature_slice;
    }
  }
 
  ## Do a bit of user-friendly munging
  foreach (@descs) {
    if ($_ eq 'Variation maps to more than one genomic location') {
      $_ = "Variation maps to $count genomic locations"; 
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
  
  # Source link
  if ($source =~ /dbSNP/) {
    $sname       = 'DBSNP';
    $source_link = $hub->get_ExtURL_link("[View in dbSNP]", $sname, $name);
  } elsif ($source =~ /SGRP/) {
    $source_link = $hub->get_ExtURL_link("[About $source]", 'SGRP_PROJECT');
  } elsif ($source =~ /COSMIC/) {
    $sname       = 'COSMIC';
    my $cname = ($name =~ /^COSM(\d+)/) ? $1 : $name;
    $source_link = $hub->get_ExtURL_link("[View in $source]", "${sname}_ID", $cname);
  } elsif ($source =~ /HGMD/) {
    $version =~ /(\d{4})(\d+)/;
    $version = "$1.$2";
    my $pf          = ($hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation')->fetch_all_by_Variation($object->Obj))->[0];
    my $asso_gene   = $pf->associated_gene;
       $source_link = $hub->get_ExtURL_link("[View in $source]", 'HGMD', { ID => $asso_gene, ACC => $name });
  } elsif ($source =~ /ESP/) {
    if ($name =~ /^TMP_ESP_(\d+)_(\d+)/) {
      $source_link = $hub->get_ExtURL_link("[View in $source]", $source, { CHR => $1 , START => $2, END => $2});
    }
    else {
      $source_link = $hub->get_ExtURL_link("[View in $source]", "${source}_HOME");
    }
  } elsif ($source =~ /LSDB/) {
    $version = ($version) ? " ($version)" : '';
    $source_link = $hub->get_ExtURL_link("[View in $source]", $source, $name);
  }  elsif ($source =~ /PhenCode/) {
     $sname       = 'PHENCODE';
     $source_link = $hub->get_ExtURL_link("[View in PhenCode]", $sname, $name);
} else {
    $source_link = $url ? qq{<a href="$url" class="constant">[View in $source]</a>} : "$source $version";
  }
  
  $version = ($version) ? " (release $version)" : '';
  
  return ['Original source', sprintf('<p>%s%s | %s</p>', $description, $version, $source_link)];
}


sub co_located {
  my ($self, $feature_slice) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');

  my $slice;
  if ($feature_slice->start > $feature_slice->end) { # Insertion
    my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor', 'core');
    $slice = $slice_adaptor->fetch_by_region( $feature_slice->coord_system_name, $feature_slice->chr_name,
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
    my %by_source;
    
    foreach (@variations) {
      my $v_name = $_->variation_name; 
      
      next if $v_name eq $name;
      
      my $v_start = $_->start + $start - 1;
      my $v_end   = $_->end   + $start - 1;

      next unless $v_start == $feature_slice->start && $v_end == $feature_slice->end;

      my $link      = $hub->url({ v => $v_name, vf => $_->dbID });
      my $alleles   = ' ('.$_->allele_string.')' if $_->allele_string =~ /\//;
      my $variation = qq{<a href="$link">$v_name</a>$alleles};
      
      push @{$by_source{$_->source_name}}, $variation;
    }
    
    if (scalar keys %by_source) {
      my $html;
      foreach (keys %by_source) {
        $html .= ($html) ? ' ; ': ' ';
        $html .= "<b>$_</b> ";
        $html .= join ', ', @{$by_source{$_}};
      }

      return ['Co-located', "with $html"];
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

    if ($db =~ /dbsnp rs/i) { # Glovar stuff
      @urls = map $hub->get_ExtURL_link($_, 'SNP', $_), @ids;
    } elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
        next if /^ss/; # don't display SSIDs - these are useless
        
        push @urls, $hub->get_ExtURL_link($_, 'SNP', $_);
      }
      
      next unless @urls;
    } elsif ($db =~ /HGVbase|TSC/) {
      next;
    } elsif ($db =~ /Affy|Illumina/){ ##moving genotyping chip data to sets
      next;
    } elsif ($db =~ /Uniprot/) { 
      push @urls, $hub->get_ExtURL_link($_, 'UNIPROT_VARIATION', $_) for @ids;
    } elsif ($db =~ /HGMD/) {
      # HACK - should get its link properly somehow
      my @pfs = grep $_->source_name =~ /HGMD/, @{$hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation')->fetch_all_by_Variation($object->Obj)};
      
      foreach my $id (@ids) {
        push @urls, $hub->get_ExtURL_link($id, 'HGMD', { ID => $_->associated_gene, ACC => $id }) for @pfs;
      }
    }
     elsif ($db =~ /PhenCode/) {
        push @urls, $hub->get_ExtURL_link($_, 'PHENCODE', $_) for @ids;
     }
     ## these are LSDBs who submit to dbSNP, so we use the submitter name as a synonym & link to the original site
     elsif ($db =~ /OIVD|LMDD|KAT6BDB/) {
        push @urls, $hub->get_ExtURL_link($_, $db, $_) for @ids;
     }
     elsif ($db =~ /HbVar/) {
        push @urls, $hub->get_ExtURL_link($_, 'HBVAR', $_) for @ids;
     }
     elsif ($db =~ /PAHdb/) {
        push @urls, $hub->get_ExtURL_link($_, 'PAHdb', $_) for @ids;
     }
     elsif ($db =~ /Infevers/) {
        push @urls, $hub->get_ExtURL_link($_, 'INFEVERS', $_) for @ids;
     }
     elsif ($db =~ /LSDB/) {
      push @urls , $hub->get_ExtURL_link($_, $db, $_) for @ids;
    } else {
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
      sprintf('<a class="toggle %s _slide_toggle set_cookie" href="#" rel="variation_synonyms" title="Click to toggle sets names">Synonyms</a>', $show ? 'open' : 'closed'),
      sprintf('<p>This variation has <strong>%s</strong> synonyms - click the plus to show</p><div class="variation_synonyms twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
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
  my $object     = $self->object;
  my $variation  = $object->Obj;
  my $alleles    = $object->alleles;
  my @l_alleles  = split '/', $alleles;
  my $c_alleles  = scalar @l_alleles;
  my $alt_string = $c_alleles > 2 ? 's' : '';
  my $ancestor   = $object->ancestor;
     $ancestor   = " | Ancestral: <strong>$ancestor</strong>" if $ancestor;
  my $ambiguity  = $variation->ambig_code;
     $ambiguity  = 'not available' if $object->source =~ /HGMD/;
     $ambiguity  = " | Ambiguity code: <strong>$ambiguity</strong>" if $ambiguity;
  my $freq       = sprintf '%.2f', $variation->minor_allele_frequency;
     $freq       = '&lt; 0.01' if $freq eq '0.00'; # Frequency lower than 1%
  my $maf        = $variation->minor_allele;
     $maf        = qq{ | <span class="_ht conhelp" title="Minor Allele Frequency">MAF</span>: <strong>$freq</strong> ($maf)} if $maf;
  my $html;   
  my $alleles_strand = ($feature_slice) ? ($feature_slice->strand == 1 ? q{ (Forward strand)} : q{ (Reverse strand)}) : ''; 
   
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
      $display_alleles, "$ancestor$ambiguity$maf",
      $show ? '' : 'display:none',
      "<pre>$alleles</pre>");
  }
  else {
    my $allele_title = ($alleles =~ /\//) ? qq{Reference/Alternative$alt_string alleles $alleles_strand} : qq{$alleles$alleles_strand};
    $html = qq{<span class="_ht conhelp" style="font-weight:bold;font-size:1.2em" title="$allele_title">$alleles</span>$ancestor$ambiguity$maf};
  }

  # Check somatic mutation base matches reference
  if ($feature_slice) {
    my $sequence = $feature_slice->seq;
    my ($allele) = split /\//, $object->alleles;
    
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
  
  return ['Location', 'This variation has not been mapped'] unless $count;
  
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
      ' | <a href="%s" class="constant">View in location tab</a>',
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
    $location = "This variation maps to $count genomic locations; <b>None selected</b>";
  }
  
  return [ 'Location', "$location$location_link" ];
}

## to be removed - replaced by evidence status
sub validation_status {
  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->status;
  my @variation_sets = sort @{$object->get_variation_set_string};
  my (@status_list, %main_status);
  
  if (scalar @$status) {
    my $snp_name = $object->name;
    
    foreach (@$status) {
      my $st;
      
      if ($_ eq 'hapmap') {
        $st = 'HapMap', $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
        $main_status{'HapMap'} = 1;
        next;
      } elsif ($_ =~ /1000Genome/i) {
        $st = '1000 Genomes';
        $main_status{'1000 Genomes'} = 1;
        next;
      } elsif ($_ ne 'failed') {
        $st = $_ eq 'freq' ? 'frequency' : $_;
      }
      
      push @status_list, $st;
    }
  }
  
  my $status_count = scalar @status_list;
  
  if ( !$main_status{'1000 Genomes'}) {
    foreach my $vs (@variation_sets) {
      if ($vs =~ /1000 Genomes/i && !$main_status{'1000 Genomes'}) {
        $main_status{'1000 Genomes'} = 1;
        $status_count ++;
      }
    }
  }
  
  return unless $status_count;
  
  my $html;
  
  if ($main_status{'HapMap'} || $main_status{'1000 Genomes'}) {
    my $show = $self->hub->get_cookie_value('toggle_status') eq 'open';
    my $showed_line;
    
    foreach my $st (sort keys %main_status) {
      $showed_line .= ', ' if $showed_line;
      $showed_line .= "<b>$st</b>";
      $status_count --;
    }
    
    $showed_line .= ' and also ' . join ', ', sort @status_list if $status_count > 0;
    $html        .= $showed_line;
  } else {
    $html .= join ', ', sort @status_list;
  }
  
  return ['Validation status', $html];
}

sub evidence_status {
  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->evidence_status;
  
  return unless (scalar @$status);

  my $html;
  foreach my $evidence (sort {$b =~ /1000|hap/i <=> $a =~ /1000|hap/i || $a cmp $b} @$status){
    my $img_evidence =  sprintf(
                          '<img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" src="/i/val/evidence_%s.png" title="%s"/>',
                          $evidence, $evidence
                        );
    my $url_type = ($evidence =~ /cited/i) ? 'Citations' : 'Population';

    my $url = $hub->url({
         type   => 'Variation',
         action => $url_type,
         v      => $object->name,
         vf     => $hub->param('vf')
       });
    $html .= qq{<a href="$url">$img_evidence</a>};
  }

  my $img = qq{<img src="/i/16/info.png" class="_ht" style="position:relative;top:2px;width:12px;height:12px;margin-left:2px" title="Click to see all the evidence status descriptions"/>}; 
  my $info_link = qq{<a href="/info/genome/variation/data_description.html#evidence_status" target="_blank">$img</a>};

  return [ "Evidence status $info_link" , $html ];
}


sub clinical_significance {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub; 
  my $clin_sign = $object->clinical_significance;

  return unless (scalar(@$clin_sign));

  my $img = qq{<img src="/i/16/info.png" class="_ht" style="position:relative;top:2px;width:12px;height:12px;margin-left:2px" title="Click to view the explanation (from the ClinVar website)"/>};
  my $info_link = $hub->get_ExtURL_link($img, "CLIN_SIG", '');

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
        '<a href="%s"><img class="_ht" style="margin-right:6px;margin-bottom:-2px;vertical-align:top" title="%s" src="/i/val/clinsig_%s.png" /></a>',
        $url, $_, $clin_sign_icon{$_}
      )
    } @$clin_sign
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
 
  # Loop over and format the URLs
  foreach my $allele (keys %$hgvs_urls) {
    $html  .= sprintf '<p>%s</p>', join('<br />', $total > 1 ? "<b>Variant allele $allele</b>" : (), @{$hgvs_urls->{$allele}});
    $count += scalar @{$hgvs_urls->{$allele}};
  }

  # Wrap the html
  if ($count > 1) {
    my $show = $self->hub->get_cookie_value('toggle_HGVS_names') eq 'open';

    return [
      sprintf('<a class="toggle %s _slide_toggle set_cookie" href="#" rel="HGVS_names" title="Click to toggle HGVS names">HGVS names</a>', $show ? 'open' : 'closed'),
      sprintf(qq(<div class="twocol-cell">
        <p>This variation has <strong>%s</strong> HGVS names - click the plus to show</p>
        <div class="HGVS_names"><div class="toggleable"%s>$html</div></div>
      </div>), $count, $show ? '' : ' style="display:none"')
    ];
  } elsif ($count == 1) {
    return ['HGVS name', $html];
  }

  return ['HGVS name', 'None'];
}

sub sets{

  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $status         = $object->status;


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
      sprintf('<a class="toggle %s _slide_toggle set_cookie" href="#" rel="variation_sets" title="Click to toggle sets names">Genotyping chips</a>', $show ? 'open' : 'closed'),
      sprintf('<p>This variation has assays on <strong>%s</strong> chips - click the plus to show</p><div class="variation_sets twocol-cell"><div class="toggleable" style="font-weight:normal;%s"><ul>%s</ul></div></div>',
        $count,
        $show ? '' : 'display:none',
        join('', map "<li>$_</li>", @genotyping_sets_list)
      )
    ];
  }
  else {
    return scalar @genotyping_sets_list
      ? ['Genotyping chips', sprintf('This variation has assays on: %s', join(', ', @genotyping_sets_list))]
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
 
      my $html = sprintf(
         '<div>%s | <a href="%s">See all predicted consequences <small>[Genes and regulation]</small></a></div>',
         $self->render_consequence_type($vf_object,1),
         $url
      );

      return [ 'Most severe consequence' , $html];
    }
  }
  return ();
}

1;
