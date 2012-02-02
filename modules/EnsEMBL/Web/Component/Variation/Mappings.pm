# $Id$

package EnsEMBL::Web::Component::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
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
  my $cons_format = $hub->param('consequence_format');
  my $show_scores = $hub->param('show_scores');
  my $vf          = $hub->param('vf');
  my $html        = qq{<a id="$self->{'id'}_top"></a>};
  
  if ($object->Obj->failed_description =~ /match.+reference\ allele/) {
    my ($feature_slice) = map $_->dbID == $vf ? $_->feature_Slice : (), @{$object->Obj->get_all_VariationFeatures};
      
    $html .= $self->_warning(
      'Warning',
      'Consequences for this variation have been calculated using the Ensembl reference allele' . (defined $feature_slice ? ' (' . $feature_slice->seq .')' : ''),
      '50%'
    );
  }
  
  # HGMD
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
        "This display shows consequence predictions for all possible alleles at this position.<br/><br/>$link",
        '50%',
      ); 
    }
    
    else {
      my $url = $hub->url({
        type   => 'Variation',
        action => 'Mappings',
        recalculate => 1,
      });
      
      my $link = "<a href='$url'>Show consequence predictions for all possible alleles</a>";
      
      $html .= $self->_info(
        'Information',
        "Ensembl has permission to display only the public HGMD dataset; this dataset does not include alleles. The consequence predictions shown below are based on the variant\'s position only.<br/><br/>$link",
        '50%',
      );      
    }
  }
  
  my @columns = (
    { key => 'gene',      title => 'Gene',                             sort => 'html'                        },
    { key => 'trans',     title => '<nobr>Transcript (strand)</nobr>', sort => 'html'                        },
    { key => 'allele',    title => 'Allele (transcript allele)',       sort => 'string',   width => '7%'     },
    { key => 'type',      title => 'Type'  ,                           sort => 'position_html'               },
    { key => 'trans_pos', title => 'Position in transcript',           sort => 'position', align => 'center' },
    { key => 'cds_pos',   title => 'Position in CDS',                  sort => 'position', align => 'center' },
    { key => 'prot_pos',  title => 'Position in protein',              sort => 'position', align => 'center' },
    { key => 'aa',        title => 'Amino acid',                       sort => 'string'                      },
    { key => 'codon',     title => 'Codons',                           sort => 'string'                      },
  );
  
  if ($hub->species eq 'Homo_sapiens') {
    push @columns, (
      { key => 'sift',      title => 'SIFT',     sort => 'position_html' },
      { key => 'polyphen',  title => 'PolyPhen', sort => 'position_html' },
    );
  }
  
  push @columns, { key => 'detail', title => 'Detail', sort => 'string' };
  
  my $table         = $self->new_table(\@columns, [], { data_table => 1, sorting => [ 'type asc', 'trans asc', 'allele asc'] });
  my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
  my $trans_adaptor = $hub->get_adaptor('get_TranscriptAdaptor');
  my $flag;
  
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
          action => $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
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
        $hgvs  = $tva->hgvs_coding             if defined $tva->hgvs_coding;
        $hgvs .= '<br />' . $tva->hgvs_protein if defined $tva->hgvs_protein;
      }

      # Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      
      my $codon = $transcript_data->{'codon'} || '-';
      
      if ($codon ne '-') {
        $codon =~ s/([ACGT])/<b>$1<\/b>/g;
        $codon =~ tr/acgt/ACGT/;
      }
      
      my $strand = $trans->strand < 1 ? '-' : '+';
      
      # consequence type
      my $type;
      
      if ($cons_format eq 'so') {
        $type = join ', ', map { $hub->get_ExtURL_link($_->SO_term, 'SEQUENCE_ONTOLOGY', $_->SO_accession) } @{$tva->get_all_OverlapConsequences};
      } elsif ($cons_format eq 'ncbi') {
        # not all terms have an ncbi equiv so default to SO
        $type = join ', ', map { $_->NCBI_term || sprintf '<span title="%s (no NCBI term available)">%s*</span>', $_->description, $_->label } @{$tva->get_all_OverlapConsequences};
      } else {
        $type = join ', ', map { '<span title="'.$_->description.'">'.$_->label.'</span>' } @{$tva->get_all_OverlapConsequences};
      }
      
      # consequence rank
      my ($rank) = sort map $_->rank, @{$tva->get_all_OverlapConsequences};
      
      $type = qq{<span class="hidden">$rank</span>$type};
      
      
      my $a = $transcript_data->{'vf_allele'};
      
      # sift
      my $sift = $self->render_sift_polyphen($tva->sift_prediction || '-',     $show_scores eq 'yes' ? $tva->sift_score     : undef);
      my $poly = $self->render_sift_polyphen($tva->polyphen_prediction || '-', $show_scores eq 'yes' ? $tva->polyphen_score : undef);
      
      my $allele  = $transcript_data->{'vf_allele'};
         $allele .= " ($transcript_data->{'tr_allele'})" unless $transcript_data->{'vf_allele'} =~ /HGMD|LARGE|DEL|INS/;
      
      my $row = {
        allele    => $allele,
        gene      => qq{<a href="$gene_url">$gene_name</a><br/><span class="small">$gene_hgnc</span>},
        trans     => qq{<nobr><a href="$transcript_url">$trans_name</a> ($strand)</nobr><br/><span class="small">$trans_type</span>},
        type      => $type,
        trans_pos => $self->_sort_start_end($transcript_data->{'cdna_start'},        $transcript_data->{'cdna_end'}),
        cds_pos   => $self->_sort_start_end($transcript_data->{'cds_start'},         $transcript_data->{'cds_end'}),
        prot_pos  => $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'}),
        aa        => $transcript_data->{'pepallele'} || '-',
        codon     => $codon,
        sift      => $sift,
        polyphen  => $poly,
        detail    => $self->ajax_add($self->ajax_url(undef, { transcript => $trans_name, vf => $varif_id, allele => $a, update_panel => 1 }), "${trans_name}_${varif_id}_${a}"),
      };
      
      $table->add_row($row);
      $flag = 1;
    }
  }

  if ($flag) {
    $html .= $table->render;
    
    return $html;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped to any Ensembl genes or transcripts</p>');
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

sub detail_panel {
  my $self     = shift;
  my $object   = $self->object;
  my $hub      = $self->hub;
  my $allele   = $hub->param('allele');
  my $tr_id    = $hub->param('transcript');
  my $vf_id    = $hub->param('vf');
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};
  my $html;
  
  foreach my $t_data(@{$mappings{$vf_id}{'transcript_vari'}}) {
    next unless $t_data->{'transcriptname'} eq $tr_id;
    next unless $t_data->{'tva'}->variation_feature_seq eq $allele;
    
    my $tv       = $t_data->{'tv'};
    my $tva      = $t_data->{'tva'};
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
    
    my %data = (
      allele     => $allele,
      t_allele   => $t_allele,
      name       => $object->name,
      gene       => qq{<a href="$gene_url">$gene_id</a>},
      transcript => qq{<a href="$tr_url">$tr_id</a>},
      protein    => $prot_id ? qq{<a href="$prot_url">$prot_id</a>} : '-',
      ens_term   => join(', ', map { sprintf '%s <i>(%s)</i>', $_->label, $_->description } @$ocs),
      so_term    => join(', ', map { sprintf '%s (%s)', $_->SO_term, $hub->get_ExtURL_link($_->SO_accession, 'SEQUENCE_ONTOLOGY', $_->SO_accession) } @$ocs),
      hgvs       => join('<br />', grep $_, $tva->hgvs_coding, $tva->hgvs_protein) || '-',
    );
    
    foreach my $oc (@$ocs) {
      push @{$data{'ncbi_term'}}, $oc->NCBI_term if defined $oc->NCBI_term;
    }
    
    $data{'ncbi_term'} = (join ', ', @{$data{'ncbi_term'} || []}) || '-';
    
    if($tv->affects_cds) {
      $data{context} = $self->render_context($tv, $tva);
      
      my $context_url = $hub->url({
        type   => 'Transcript',
        action => 'Sequence_cDNA',
        db     => 'core',
        r      => undef,
        t      => $tr_id,
        vf     => $vf_id,
        v      => $object->name,
      });
      
      #$data{'context'} = $self->render_context($tv, $tva);
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
    }
    
    my @rows = (
      { name       => 'Variation name'             },      
      { gene       => 'Gene'                       },
      { transcript => 'Transcript'                 },
      { protein    => 'Protein'                    },
      { allele     => 'Allele (variation)'         },
      { t_allele   => 'Allele (transcript)'        },
      { ens_term   => 'Consequence (Ensembl term)' },
      { so_term    => 'Consequence (SO term)'      },
      { ncbi_term  => 'Consequence (NCBI term)'    },
      { hgvs       => 'HGVS names'                 },
      { exon       => 'Exon'                       },
      { exon_coord => 'Position in exon'           },
      { context    => 'Context'                    },
    );
    
    my $table = $self->new_table([{ key => 'name' }, { key => 'value' }], [], { header => 'no' });
    
    foreach my $row (@rows) {
      my ($key, $name) = %$row;
      $table->add_row({ name => $name, value => $data{$key} || '-' });
    }
    
    $html .= $self->toggleable_table("Detail for $data{name} ($allele) in $tr_id", join('_', $tr_id, $vf_id, $allele), $table, 1, qq{<span style="float:right"><a href="#$self->{'id'}_top">[back to top]</a></span>});
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

1;
