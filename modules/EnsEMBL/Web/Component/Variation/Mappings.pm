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

package EnsEMBL::Web::Component::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);
use Bio::EnsEMBL::Variation::Utils::VariationEffect qw(overlap);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  #$self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;

  # first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  return $self->detail_panel if $hub->param('allele');
  
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};

  return [] unless keys %mappings;

  my $source      = $object->source;
  my $name        = $object->name;
  my $show_scores = $hub->param('show_scores');
  my $vf          = $hub->param('vf');
  my $html        = qq{<a id="$self->{'id'}_top"></a>};
  
  if ($object->Obj->failed_description =~ /match.+reference\ allele/) {
    my ($feature_slice) = map $_->dbID == $vf ? $_->feature_Slice : (), @{$object->Obj->get_all_VariationFeatures};
      
    $html .= $self->_warning(
      'Warning',
      '<p>Consequences for this variation have been calculated using the Ensembl reference allele' . (defined $feature_slice ? ' (' . $feature_slice->seq .')</p>' : '</p>'),
      '50%'
    );
  }
  
  # HGMD (SNPs only)
  if($source eq 'HGMD-PUBLIC' and $name =~ /^CM/) {
    
    if($hub->param('recalculate')) {
      
      my $url = $hub->url({
        type   => 'Variation',
        action => 'Mappings',
        recalculate => undef,
      });
      
      my $link = "<a href='$url'>Revert to original display</a>";
      
      $html .= $self->_info(
        'Information',
        "<p>This display shows consequence predictions in the 'Type' column for all possible alleles (A/C/G/T) at this position. Ensembl has permission to display only the public HGMD dataset which does not include alleles.<br/><br/>$link</p>",
        '50%',
      ); 
    }
    
    else {
      my $url = $hub->url({
        type   => 'Variation',
        action => 'Mappings',
        recalculate => 1,
      });
      
      $html .= $self->_info(
        'Information',
        "Ensembl has permission to display only the public HGMD dataset which does not include alleles.<br /><a href='$url'>Show consequence predictions</a> (e.g. amino acid changes) for all possible alleles based only on the variant location.",
        '50%',
      );      
    }
  }
  
  my @columns = (
    { key => 'gene',      title => 'Gene',                             sort => 'html'                        },
    { key => 'trans',     title => 'Transcript (strand)',              sort => 'html'                        },
    { key => 'allele',    title => 'Allele (transcript allele)',       sort => 'string',   width => '7%'     },
    { key => 'type',      title => 'Consequence Type',                 sort => 'position_html'               },
    { key => 'trans_pos', title => 'Position in transcript',           sort => 'position', align => 'center' },
    { key => 'cds_pos',   title => 'Position in CDS',                  sort => 'position', align => 'center' },
    { key => 'prot_pos',  title => 'Position in protein',              sort => 'position', align => 'center' },
    { key => 'aa',        title => 'Amino acid',                       sort => 'string'                      },
    { key => 'codon',     title => 'Codons',                           sort => 'string'                      },
  );
  

  push @columns, ({ key => 'sift',      title => 'SIFT',     sort => 'position_html', align => 'center' },) 
      if defined $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'SIFT'} ;

  push @columns, ({ key => 'polyphen',  title => 'PolyPhen', sort => 'position_html', align => 'center' },) 
      if $hub->species eq 'Homo_sapiens';
  
  push @columns, { key => 'detail', title => 'Detail', sort => 'string' };
  
  my $table         = $self->new_table(\@columns, [], { data_table => 1, sorting => [ 'type asc', 'trans asc', 'allele asc'], class => 'cellwrap_inside' });
  my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
  my $trans_adaptor = $hub->get_adaptor('get_TranscriptAdaptor');
  my $max_length    = 20;
  my $flag;
  
  # create a regfeat table as well
  my @reg_columns = (
    { key => 'rf',       title => 'Regulatory feature',     sort => 'html'                             },
    { key => 'cell_type',title => 'Cell type',              sort => 'string'                           },
    { key => 'ftype',    title => 'Feature type',           sort => 'string'                           },
    { key => 'allele',   title => 'Allele',                 sort => 'string'                           },
    { key => 'type',     title => 'Consequence type',       sort => 'position_html'                    },
  );
  my $reg_table = $self->new_table(\@reg_columns, [], { data_table => 1, sorting => ['type asc'], class => 'cellwrap_inside', data_table_config => {iDisplayLength => 10} } );
  my @motif_columns = (
    { key => 'rf',       title => 'Feature',                   sort => 'html'                             },
    { key => 'ftype',    title => 'Feature type',              sort => 'string'                           },
    { key => 'allele',   title => 'Allele',                    sort => 'string'                           },
    { key => 'type',     title => 'Consequence type',          sort => 'position_html'                    },
    { key => 'matrix',   title => 'Motif name',                sort => 'string'                           },
    { key => 'pos',      title => 'Motif position',            sort => 'numeric'                          },
    { key => 'high_inf', title => 'High information position', sort => 'string'                           },
    { key => 'score',    title => 'Motif score change',        sort => 'position_html', align => 'center' },
  );
  my $motif_table = $self->new_table(\@motif_columns, [], { data_table => 1, sorting => ['type asc'], class => 'cellwrap_inside' } );

  
  foreach my $varif_id (grep $_ eq $hub->param('vf'), keys %mappings) {
    foreach my $transcript_data (@{$mappings{$varif_id}{'transcript_vari'}}) {
      my $gene       = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{'transcriptname'}); 
      my $gene_name  = $gene ? $gene->stable_id : '';
      my $trans_name = $transcript_data->{'transcriptname'};
      my $trans      = $trans_adaptor->fetch_by_stable_id($trans_name);
      my $tva        = $transcript_data->{'tva'};
      my $trans_type = '<b>biotype: </b>' . $tva->transcript->biotype;
      my @entries    = grep $_->database eq 'HGNC', @{$gene->get_all_DBEntries};
      my $gene_hgnc  = scalar @entries ? '<b>HGNC: </b>' . $entries[0]->display_id : '';
      my ($gene_url, $transcript_url);
      
      # Create links to non-LRG genes and transcripts
      if ($trans_name !~ m/^LRG/) {
        $gene_url = $hub->url({
          type   => 'Gene',
          action => 'Variation_Gene/Table',
          db     => 'core',
          r      => undef,
          g      => $gene_name,
          v      => $name,
          source => $source
        });
      
        $transcript_url = $hub->url({
          type   => 'Transcript',
          action => 'Variation_Transcript/Table',
          db     => 'core',
          r      => undef,
          t      => $trans_name,
          v      => $name,
          source => $source
        });
      } else {
        $gene_url = $hub->url({
          type     => 'LRG',
          action   => 'Variation_LRG',
          function => 'Table',
          db       => 'core',
          r        => undef,
          lrg      => $gene_name,
          v        => $name,
          source   => $source,
          __clear  => 1
        });
      
        $transcript_url = $hub->url({
          type     => 'LRG',
          action   => 'Variation_LRG',
          function => 'Table',
          db       => 'core',
          r        => undef,
          lrg      => $gene_name,
          lrgt     => $trans_name,
          v        => $name,
          source   => $source,
          __clear  => 1
        });
      }
      
      # HGVS
      my $hgvs;
      
      unless ($object->is_somatic_with_different_ref_base) {
        $hgvs  = $tva->hgvs_transcript          if defined $tva->hgvs_transcript;
        $hgvs .= '<br />' .  $tva->hgvs_protein if defined $tva->hgvs_protein;
      }

      # Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      
      my $codon = $transcript_data->{'codon'} || '-';
      
      if ($codon ne '-') {
        $codon =~ s/([ACGT])/<b>$1<\/b>/g;
        $codon =~ tr/acgt/ACGT/;
      }
      
      my $strand = $trans->strand < 1 ? '-' : '+';
      
      # consequence type
      my $type = $self->render_consequence_type($tva);
      
      my $a = $transcript_data->{'vf_allele'};
      
      # sift
      my $sift = $self->render_sift_polyphen($tva->sift_prediction, $tva->sift_score);
      my $poly = $self->render_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score);
      
      # Allele
      my $allele = (length($a) > $max_length) ? substr($a,0,$max_length).'...' : $a;
      
      my $html_full_tr_allele;
      
      unless ($transcript_data->{'vf_allele'} =~ /HGMD|LARGE|DEL|INS/) {
        my $tr_allele = sprintf "(%s)",$transcript_data->{'tr_allele'};
        $allele .= " <small>".$self->trim_large_string($tr_allele,'tr_'.$transcript_data->{transcriptname},sub {
          # trim to 20 but include the brackets
          local $_ = shift;
          return $_ if(length $_ < 20);
          s/^.//; s/.$//;
          return "(".substr($_,0,20)."...)";
        })."</small>";
      }
      
      my $row = {
        allele    => $allele,
        gene      => qq{<a href="$gene_url">$gene_name</a><br/><span class="small" style="white-space:nowrap;">$gene_hgnc</span>},
        trans     => qq{<a href="$transcript_url">$trans_name</a> ($strand)<br/><span class="small" style="white-space:nowrap;">$trans_type</span>},
        type      => $type,
        trans_pos => $self->_sort_start_end($transcript_data->{'cdna_start'},        $transcript_data->{'cdna_end'}),
        cds_pos   => $self->_sort_start_end($transcript_data->{'cds_start'},         $transcript_data->{'cds_end'}),
        prot_pos  => $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'}),
        aa        => $transcript_data->{'pepallele'} || '-',
        codon     => $codon,
        sift      => $sift,
        polyphen  => $poly,
        detail    => $self->ajax_add($self->ajax_url(undef, { t => $trans_name, vf => $varif_id, allele => $a, update_panel => 1 }).";single_transcript=variation_feature_variation=normal", "${trans_name}_${varif_id}_${a}"),
      };
      
      $table->add_row($row);
      $flag = 1;
    }
    
    
    # reg feats
    # get variation feature object
    my ($vf_obj) = grep {$_->dbID eq $varif_id} @{$self->object->get_variation_features};
    
    # reset allele string if recalculating for HGMD
    $vf_obj->allele_string('A/C/G/T') if $hub->param('recalculate');
    
    my $rfa = $hub->get_adaptor('get_RegulatoryFeatureAdaptor', 'funcgen');
    
    for my $rfv (@{ $vf_obj->get_all_RegulatoryFeatureVariations }) {
      my $rf_stable_id = $rfv->regulatory_feature->stable_id;
      my $rfs = $rfa->fetch_all_by_stable_ID($rf_stable_id);
       
      # create a URL
      my $url = $hub->url({
        type   => 'Regulation',
        action => 'Summary',
        rf     => $rfv->regulatory_feature->stable_id,
        fdb    => 'funcgen',
      });
      
      $url .= ';regulation_view=variation_feature_variation=normal';
        for my $rf (@$rfs) { 
          for my $rfva (@{ $rfv->get_all_alternate_RegulatoryFeatureVariationAlleles }) {
            my $type = $self->render_consequence_type($rfva);
            
            my $r_allele = $self->trim_large_string($rfva->variation_feature_seq,'rfva_'.$rfv->regulatory_feature->stable_id,25);
            
            my $row = {
              rf       => sprintf('<a href="%s">%s</a>', $url, $rfv->regulatory_feature->stable_id),
              cell_type => $rf->cell_type->name,
              ftype    => $rf->feature_type->so_name,
              allele   => $r_allele,
              type     => $type || '-',
            };
            
            $reg_table->add_row($row);
            $flag = 1;
          } # end rfva loop
      } # end rf loop
    } # end rfv loop
    
    for my $mfv (@{ $vf_obj->get_all_MotifFeatureVariations }) {
      my $mf = $mfv->motif_feature;
     
      # check that the motif has a binding matrix, if not there's not 
      # much we can do so don't return anything
      next unless defined $mf->binding_matrix;
      my $matrix = $mf->display_label;
      
      my $matrix_url = $mf->binding_matrix->description =~ /Jaspar/ ? $hub->get_ExtURL_link($matrix, 'JASPAR', (split ':', $matrix)[-1]) : $matrix;
      
      # get the corresponding regfeat
      my $rf = $rfa->fetch_all_by_attribute_feature($mf)->[0];

      next unless $rf;

      # create a URL
      my $url = $hub->url({
        type   => 'Regulation',
        action => 'Summary',
        rf     => $rf->stable_id,
        fdb    => 'funcgen',
      });
      
      $url .= ';regulation_view=variation_feature_variation=normal';
      
      for my $mfva (@{ $mfv->get_all_alternate_MotifFeatureVariationAlleles }) {
        my $type = $self->render_consequence_type($mfva);
        
        my $m_allele = $self->trim_large_string($mfva->variation_feature_seq,'mfva_'.$rf->stable_id,25);
        
        my $row = {
          rf       => sprintf('%s<br/><span class="small" style="white-space:nowrap;"><a href="%s">%s</a></span>', $mf->binding_matrix->name, $url, $rf->stable_id),
          ftype    => $mfva->feature->feature_type->so_name,#'Motif feature',
          allele   => $m_allele,
          type     => $type,
          matrix   => $matrix_url,
          pos      => $mfva->motif_start,
          high_inf => $mfva->in_informative_position ? 'Yes' : 'No',
          score    => defined($mfva->motif_score_delta) ? $self->render_motif_score($mfva->motif_score_delta) : '-',
        };
        
        $motif_table->add_row($row);
        $flag = 1;
      }
    }
  }

  if ($flag) {
    $html .=
      ($table->has_rows ? '<h2>Gene and Transcript consequences</h2>'.$table->render : '<h3>No Gene or Transcript consequences</h3>').
      ($reg_table->has_rows ? '<h2>Regulatory feature consequences</h2>'.$reg_table->render : '<h3>No overlap with Ensembl Regulatory features</h3>').
      ($motif_table->has_rows ? '<h2>Motif feature consequences</h2>'.$motif_table->render : '<h3>No overlap with Ensembl Motif features</h3>');
    
    return $html;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped to any Ensembl genes, transcripts or regulatory features</p>');
  }
}

# Mapping_table
# Arg1        : start and end coordinate
# Example     : $coord = _sort_star_end($start, $end)_
# Description : Returns $start-$end if they are defined, else 'n/a'
# Returns  string
sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) { 
    if ($start == $end) {
      return $start;
    } else {
      return "$start-$end";
    }
  } else {
    return '-';
  };
}

sub render_motif_score {
  my $self  = shift;
  my $score = shift;
  
  my $sort_score = sprintf("%.0f", (($score + 20) * 10000));
  
  my ($class, $message);
  
  if($score == 0) {
    $class = 'no_arrow';
    $message = 'No change';
  }
  elsif($score > 0) {
    $class = 'up_arrow';
    $message = 'More like consensus sequence';
  }
  elsif($score < 0) {
    $class = 'down_arrow';
    $message = 'Less like consensus sequence';
  }
  
  my $score_text = '';
  
  if($self->hub->param('motif_score') eq 'yes') {
    $score_text = sprintf('<span class="small">(%.3f)</span>', $score);
  }
  
  return qq{<div align="center"><span class="hidden">$sort_score</span><span class="hidden export">$message</span><div class="$class" title="$message"></div>$score_text</div>};
}

sub detail_panel {
  my $self     = shift;
  my $object   = $self->object;
  my $hub      = $self->hub;
  my $allele   = $hub->param('allele');
  my $tr_id    = $hub->param('t');
  my $vf_id    = $hub->param('vf');
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};
  my $html;
  
  foreach my $t_data(@{$mappings{$vf_id}{'transcript_vari'}}) {
    next unless $t_data->{'transcriptname'} eq $tr_id;
    next unless $t_data->{'tva'}->variation_feature_seq eq $allele;
    
    my $tv       = $t_data->{'tv'};
    my $tva      = $t_data->{'tva'};
    my $vf       = $t_data->{'vf'};
    my $t_allele = $tva->feature_seq;
    my $tr       = $tv->transcript;
    my $ocs      = $tva->get_all_OverlapConsequences;
    my $gene_id  = $hub->get_adaptor('get_GeneAdaptor')->fetch_by_transcript_stable_id($tr_id)->stable_id;
    
    my $tr_url = $hub->url({
      type   => 'Transcript',
      action => $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
      db     => 'core',
      r      => undef,
      t      => $tr_id,
      vf     => $vf_id,
    });
    
    my $gene_url = $hub->url({
      type     => 'Gene',
      action   => 'Variation_Gene',
      function => 'Table',
      db       => 'core',
      r        => undef,
      g        => $gene_id,
      v        => $object->name,
    });
    
    my $prot_url = $hub->url({
      type   => 'Transcript',
      action => 'ProtVariations',
      db     => 'core',
      r      => undef,
      t      => $tr_id,
      vf     => $vf_id,
    });
    
    my $prot_id = $tr->translation ? $tr->translation->stable_id : undef; 
    
    my $display_allele = $self->trim_large_string($allele,'allele_'.$t_data->{transcriptname},50);
    $t_allele = $self->trim_large_string($t_allele,'t_allele_'.$t_data->{transcriptname},50);
        
    # HGVS
    my $hgvs_c = $self->trim_large_string($tva->hgvs_transcript,'hgvs_c_'.$t_data->{transcriptname},60);
    my $hgvs_p = $self->trim_large_string($tva->hgvs_protein,'hgvs_p_'.$t_data->{transcriptname},60);

    
    my %ens_term = map { $_->display_term => 1 } @$ocs;
    
    my %data = (
      allele     => $display_allele,
      t_allele   => $t_allele,
      name       => $object->name,
      gene       => qq{<a href="$gene_url">$gene_id</a>},
      transcript => qq{<a href="$tr_url">$tr_id</a>},
      protein    => $prot_id ? qq{<a href="$prot_url">$prot_id</a>} : '-',
      ens_term   => join(', ', keys(%ens_term)),
      so_term    => join(', ', map { sprintf '%s - <i>%s</i> (%s)', $_->label, $_->description, $hub->get_ExtURL_link($_->SO_accession, 'SEQUENCE_ONTOLOGY', $_->SO_accession) } @$ocs),
      hgvs       => join('<br />', grep $_, $hgvs_c, $hgvs_p) || '-',
    );
    
    if($tv->affects_cds) {
      #$data{context} = $self->render_context($tv, $tva);
      
      my $context_url = $hub->url({
        type   => 'Transcript',
        action => 'Sequence_cDNA',
        db     => 'core',
        r      => undef,
        t      => $tr_id,
        vf     => $vf_id,
        v      => $object->name,
      });
      
      $data{'context'} = qq{<a href="$context_url">Show in transcript</a>};
      
      # work out which exon it is in
      my @exons       = @{$tr->get_all_Exons};      
      my $exon_number = 0;
      my $exon;
      
      while ($exon_number < scalar @exons) {
        $exon = $exons[$exon_number++];
        last if $tv->cdna_end >= $exon->cdna_start($tr) && $tv->cdna_start <= $exon->cdna_end($tr);
      }
      
      my $exon_url = $hub->url({
        type       => 'Transcript',
        action     => 'Exons',
        transcript => $tr_id,
        vf         => $vf_id,
      });
      
      $data{'exon'} = sprintf(
        '<a href="%s">%s</a> (%i of %i, length %i)',
        $exon_url,
        $exon->stable_id,
        $exon_number,
        scalar @exons,
        $exon->length
      );
      
      $data{'exon_coord'} =
        ($tv->cdna_start - $exon->cdna_start($tr) + 1) .
        ($tv->cdna_end == $tv->cdna_start ? '' : '-' . ($tv->cdna_end - $exon->cdna_start($tr) + 1));
        
      # protein domains
      my @strings;

      for my $feat (@{$tv->get_overlapping_ProteinFeatures}) {
          my $label = $feat->analysis->display_label.': '.$feat->hseqname;
          push @strings, $label;
      }

      $data{domains} = join '<br/>', @strings if @strings;
      
      # find vars in same AA
      my @same_aa;
      
      foreach my $other_vf(@{$vf->feature_Slice->expand(3, 3)->get_all_VariationFeatures}) {
        next if $other_vf->dbID == $vf->dbID;
        
        foreach my $other_tv(@{$other_vf->get_all_TranscriptVariations([$tv->transcript])}) {
          next unless defined($tv->translation_start) && defined($tv->translation_end) && defined($other_tv->translation_start) && defined($other_tv->translation_end);
          next unless overlap($other_tv->translation_start, $other_tv->translation_end, $tv->translation_start, $tv->translation_end);
          my $vf_url = $hub->url({
            type       => 'Variation',
            action     => 'Explore',
            vf         => $other_vf->dbID,
            v          => $other_vf->variation_name
          });
          push @same_aa, sprintf('<a href="%s">%s</a>', $vf_url, $other_vf->variation_name);
        }
      }
      
      $data{same_aa} = (join ", ", @same_aa) || "-";
    }
    
    #$data{'context'} =
    #  $self->context_image($tva).
    #  $self->render_context($tv, $tva);
    
    my @rows = (
      { name       => 'Variation name'             },      
      { gene       => 'Gene'                       },
      { transcript => 'Transcript'                 },
      { protein    => 'Protein'                    },
      { allele     => 'Allele (variation)'         },
      { t_allele   => 'Allele (transcript)'        },
      { so_term    => 'Consequence (SO term)'      },
      { ens_term   => 'Consequence (Old Ensembl term)' },
      { hgvs       => 'HGVS names'                 },
      { exon       => 'Exon'                       },
      { exon_coord => 'Position in exon'           },
      { domains    => 'Overlapping protein domains'},
      { same_aa    => 'Variants in same codon'     },
      { context    => 'Context'                    },
    );
    
    my $table = $self->new_table([{ key => 'name' }, { key => 'value'}], [], { header => 'no', class => 'cellwrap_inside' });
    
    foreach my $row (@rows) {
      my ($key, $name) = %$row;
      $table->add_row({ name => "<b>$name</b>", value => $data{$key} || '-' });
    }
    
    my $a_label = (length($allele) > 50) ? substr($allele,0,50).'...' : $allele;
    $html .= $self->toggleable_table("Consequence detail for $data{name} ($a_label) in $tr_id", join('_', $tr_id, $vf_id, $hub->param('allele')), $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>});
  }
  
  return $html;
}

## THIS METHOD IS WIP AND NOT IN USE RIGHT NOW
## WILL BE USED TO RENDER THE CONTEXT OF THE VARIANT WITH
## PREDICTED PEPTIDE SEQUENCE IF FRAMESHIFT ETC
sub render_context {
  my $self         = shift;
  my $tv           = shift;
  my $tva          = shift;
  my $transcript   = $tv->transcript;
  my $cdna_seq     = $transcript->seq->seq;
  my $cdna_start   = $tv->cdna_start;
  my $cdna_end     = $tv->cdna_end;
  my $tv_phase     = ($cdna_start - $transcript->cdna_coding_start + 1) % 3;
  my $context_size = 32;
  my $ref_a        = substr $cdna_seq, $cdna_start - 1, $cdna_end - $cdna_start + 1;
  my $var_a        = $tva->feature_seq;
  my $length_diff  = length($var_a) - length($ref_a);
  my $context;
  
  if ($length_diff != 0) {
    $ref_a .= '-' x ($length_diff > 0 ? $length_diff     : 0);
    $var_a .= '-' x ($length_diff < 0 ? 0 - $length_diff : 0);
  }
  
  my ($tmp_r, $tmp_v) = ($ref_a, $var_a);
  
  $_ =~ s/\-//g for $tmp_r, $tmp_v;
  
  my $var_length_diff = length($tmp_v) - length($tmp_r);
  my $is_insertion    = $var_length_diff > 0 ? 1 : 0;
  my $up_seq          = substr $cdna_seq, $cdna_start - 1 - $context_size, $context_size;
  my $down_seq        = substr $cdna_seq, $cdna_end, $context_size;
  
  my ($ref_down_seq, $var_down_seq) = ($down_seq, $down_seq);
  
  if (defined $tv->cds_start) {
    # render up seq codons backwards (easier!)
    my ($s, $e);
    my $cur_pos     = $tv->cds_start;
    my $tmp_phase   = ($tv_phase + 2) % 3;
    my $chop_length = $tmp_phase;
    
    while (length $up_seq > 0) {
      my $sub_start = length($up_seq) - $chop_length;
         $sub_start = 0 if $sub_start < 0;
      my $sub_seq   = substr $up_seq, $sub_start, $chop_length;
      
      $cur_pos -= $chop_length;
      
      # start codon?
      if ($sub_seq eq 'ATG' && $cur_pos == 1) {
        $up_seq = length($up_seq) > 3 ? substr $up_seq, 0, $sub_start : '';
        $s      = sprintf '<span style="background-color:#ffdf33">%s</span><span style="background-color:%s">%s</span>%s', $up_seq, $e ? '#fff9af' : 'white', $sub_seq, $s;
        last;
      }
      
      $s = sprintf '<span style="background-color:%s">%s</span>%s', $e ? '#fff9af' : 'white', $sub_seq, $s;
      
      last if length $up_seq <= 3;
      
      $up_seq      = substr $up_seq, 0, $sub_start;
      $chop_length = 3;
      $e           = 1 - $e;
    }
    
    $up_seq      = $s;
    $tmp_phase   = 3 - (($tv_phase + length($tmp_r) - 1) % 3);
    $chop_length = $tmp_phase;
    $e           = 0; 
    $s           = '';
    
    while (length $down_seq > 0) {
      my $sub_seq = substr $down_seq, 0, $chop_length;
      
      # stop codon?
      if ($sub_seq eq 'TAA' || $sub_seq eq 'TAG' || $sub_seq eq 'TGA') {
        $down_seq = length $down_seq >= 3 ? substr $down_seq, $chop_length : '';
        $s       .= sprintf '<span style="background-color:%s">%s</span><span style="background-color:#ffdf33">%s</span>', $e ? '#fff9af' : 'white', $sub_seq, $down_seq;
        last;
      }
      
      $s .= sprintf '<span style="background-color:%s">%s</span>', $e ? '#fff9af' : 'white', $sub_seq;
      
      last if length $down_seq < 3;
      
      $down_seq    = substr $down_seq, $chop_length;
      $chop_length = 3;
      $e           = 1 - $e;
    }
    
    $down_seq = $s;
    
    ($ref_down_seq, $var_down_seq) = ($down_seq, $down_seq);
    
    # recalc down_seq if var changes length
    if ($var_length_diff != 0) {
      $tmp_phase   = 3 - (($tv_phase + length($tmp_v) - 1) % 3);
      $chop_length = $tmp_phase;
      $e           = 0; 
      $s           = '';
      $down_seq    = substr $cdna_seq, $cdna_end, $context_size;
      
      while (length $down_seq > 0) {
        my $sub_seq = substr $down_seq, 0, $chop_length;
        
        # stop codon?
        if ($sub_seq eq 'TAA' || $sub_seq eq 'TAG' || $sub_seq eq 'TGA') {
          $down_seq = length $down_seq >= 3 ? substr $down_seq, $chop_length : '';
          $s       .= sprintf '<span style="background-color:%s">%s</span><span style="background-color:#ffdf33">%s</span>', $e ? '#fff9af' : 'white', $sub_seq, $down_seq;
          last;
        }
        
        $s .= sprintf '<span style="background-color:%s">%s</span>', $e ? '#fff9af' : 'white', $sub_seq;
        
        last if length $down_seq < 3;
        
        $down_seq    = substr $down_seq, $chop_length;
        $chop_length = 3;
        $e           = 1 - $e;
      }
      
      $var_down_seq = $s;
    }
  }
  
  my $ref_seq = qq{$up_seq<span style="background-color:green;color:white;font-weight:bold">$ref_a</span>$ref_down_seq};
  my $var_seq = qq{$up_seq<span style="background-color:red;color:white;font-weight:bold">$var_a</span>$var_down_seq};
  
  my ($is_new_pep_trimmed, $new_pep_has_stop);
  
  # peptide seq
  if ($transcript->translation) {
    my $translated_seq    = $transcript->translation->seq;
    my ($t_start, $t_end) = ($tv->translation_start, $tv->translation_end);
    my $ref_pep           = substr $translated_seq, $t_start - 1, $t_end - $t_start + 1;
    my $var_pep           = $tva->peptide;
       $var_pep           =~ s/\-//g;
    my $pep_context_size  = int(($context_size - 1) / 3);
    my $p_start           = $t_start - 1 - $pep_context_size;
    my $p_up_length       = $pep_context_size;
       $p_up_length      += $p_start if $p_start < 0;
       $p_start           = 0 if $p_start < 0;
    my $up_pep            = substr $translated_seq, $p_start , $p_up_length;
    my $down_pep          = substr $translated_seq, $t_end, $pep_context_size;
    
    # render up_pep
    my $s = '';
      $s .= " $_ " for (split //, $up_pep);        
      $s  = (' ' x (($context_size - (($tv_phase + 2) % 3)) - length $s)) . $s;
    
    $up_pep = $s;
    
    # prepare down pep seq
    
    # we need to re-translate if frame shift        
    my ($ref_down_pep, $var_down_pep) = ($down_pep, $down_pep);
    my $is_tran_different;
    
    if ($var_length_diff != 0 && abs($var_length_diff) % 3 != 0) {
      # we need position of last complete codon
      my $low_pos             = ($cdna_start < $cdna_end ? $cdna_start : $cdna_end);
      my $high_pos            = ($cdna_start < $cdna_end ? $cdna_end : $cdna_start);
      my $last_complete_codon = $transcript->cdna_coding_start + (($tv->translation_start - 1) * 3) - 1;
      my $before_var_seq      = substr $cdna_seq, $last_complete_codon, $low_pos - $last_complete_codon - ($is_insertion ? 0 : 1);
      my $after_var_seq       = substr $cdna_seq, $high_pos - ($is_insertion ? 1 : 0);
      my $to_translate        = "$before_var_seq$var_a$after_var_seq";
         $to_translate        =~ s/\-//g;
      
      my $codon_seq = Bio::Seq->new(
        -seq      => $to_translate,
        -moltype  => 'dna',
        -alphabet => 'dna'
      );
      
      # get codon table
      my ($attrib)    = @{$transcript->slice->get_all_Attributes('codon_table')}; #for mithocondrial dna it is necessary to change the table
      my $codon_table = $attrib ? $attrib->value || 1 : 1;
      my $new_phase   = ($tv_phase + 1) % 3;
      my $new_pep     = $codon_seq->translate(undef,undef,undef,$codon_table)->seq();
         $new_pep     =~ s/\*.+/\*/;
         
      $new_pep_has_stop = $new_pep =~ /\*/;
      $var_down_pep     = $new_pep;
      
      if (length $var_down_pep > $pep_context_size) {
        $is_new_pep_trimmed = length($var_down_pep) - $pep_context_size + 1;
        $var_down_pep       = substr $var_down_pep, 0, $pep_context_size + 1;
      }
      
      $is_tran_different = 1;
    }
    
    $s = '';
    
    my $tmp_phase    = ($tv_phase + 1) % 3;
       $ref_down_pep = join '', map " $_ ", split //, $down_pep;
       $var_down_pep = join '', map " $_ ", split //, $var_down_pep;
       $ref_pep      = ' ' . (join '  ', split '', $ref_pep) . ' ' unless $ref_pep eq '';
       $var_pep      = ' ' . (join '  ', split '', $var_pep) . ' ' unless $var_pep eq '';
    
    # insertion
    if ($var_length_diff > 0) {
      my ($up_space, $down_space);
      $up_space   = int($var_length_diff / 2);
      $down_space = $var_length_diff - $up_space;
      $ref_pep    = (' ' x $up_space) . $ref_pep . (' ' x $down_space);
    } elsif ($var_length_diff < 0) { # deletion
      my ($up_space, $down_space);
      $up_space   = int(abs($var_length_diff) / 2);
      $down_space = abs($var_length_diff) - $up_space;
      $var_pep    = (' ' x $up_space) . $var_pep . (' ' x $down_space);
    }
    
    $var_down_pep = qq{<span style="background-color:red;color:white;font-weight:bold">$var_down_pep</span>} if $is_tran_different;
    $ref_seq      = qq{$up_pep<span style="background-color:green;color:white;font-weight:bold">$ref_pep</span>$ref_down_pep<br />$ref_seq};
    $var_seq      = qq{$var_seq<br />$up_pep<span style="background-color:red;color:white;font-weight:bold">$var_pep</span>$var_down_pep};
  }
  
  $context .= "<pre>$ref_seq<br />$var_seq</pre>";
  $context .= "<p>Predicted variant peptide extends for $is_new_pep_trimmed residues beyond displayed sequence</p>" if $is_new_pep_trimmed;
  $context .= '<p>Predicted variant peptide has no STOP codon</p>' unless $new_pep_has_stop;
  
  return $context;
}


# renders the context as an image with transcripts
sub context_image {
  my $self = shift;
  my $tva  = shift;
  
  my $transcript = $tva->transcript;
  
  # get slice
  my $slice        = $transcript->feature_Slice;
     $slice        = $slice->invert if $slice->strand < 1;
  
  my $transcriptObj = $self->new_object(
    'Transcript', $transcript, $self->object->__data
  );
  
  my $image_config = $transcriptObj->get_imageconfig('single_transcript');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => 800,
    slice_number    => '1|1',
  });
  
  # turn on the transcript
  my $key  = $image_config->get_track_key('transcript', $transcriptObj);
  
  my $node = $image_config->get_node($key) || $image_config->get_node(lc $key);
  if (!$node) {
    warn ">>> NO NODE FOR KEY $key";
    return "<p>Cannot display image for this transcript</p>";
  }
  
  $node->set('display', 'transcript_label') if $node->get('display') eq 'off';
  $node->set('show_labels', 'off');
  
  ## Show the ruler only on the same strand as the transcript
  $image_config->modify_configs(
    [ 'ruler' ],
    { 'strand', $transcript->strand > 0 ? 'f' : 'r' }
  );
  
  $image_config->set_parameter('single_Transcript' => $transcript->stable_id);
  $image_config->set_parameter('single_Gene'       => $transcriptObj->gene->stable_id) if $transcriptObj->gene;
  
  my $image = $self->new_image($slice, $image_config, []);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'transcript';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}


1;
