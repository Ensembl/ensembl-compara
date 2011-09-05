package EnsEMBL::Web::Component::Variation::Mappings;

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

  # first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  if(defined $object->param('allele')) {
    return $self->detail_panel;
  }
  
  my %mappings = %{$object->variation_feature_mapping};

  return [] unless keys %mappings;

  my $hub    = $self->hub;
  my $source = $object->source;
  my $name   = $object->name;
  
  my $cons_format = $object->param('consequence_format');
  my $show_scores = $object->param('show_scores');
  
  my $html;
  $html .= qq{<a id="$self->{'id'}_top"></a>};
  
  if($object->Obj->failed_description =~ /match.+reference\ allele/) {
    my $variation_features = $object->Obj->get_all_VariationFeatures;
    
    # get slice for variation feature
    my $feature_slice;
  
    foreach my $vf (@$variation_features) {
      $feature_slice = $vf->feature_Slice if $vf->dbID == $hub->core_param('vf');
    }
      
    $html .= $self->_warning(
      'Warning',
      'Consequences for this variation have been calculated using the Ensembl reference allele'.
      (defined $feature_slice ? " (".$feature_slice->seq.")" : ""),
      '50%'
    );
  }
 
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'type asc', 'trans asc', 'allele asc'] });
  
  $table->add_columns(
    { key => 'gene',      title => 'Gene',                   sort => 'html'                        },
    { key => 'trans',     title => '<nobr>Transcript (strand)</nobr>',    sort => 'html'                        },
    { key => 'allele',    title => 'Allele (transcript allele)', sort => 'string', width => '7%'          },
    { key => 'type',      title => 'Type'  ,                 sort => 'position_html'                      },
    #{ key => 'hgvs',      title => 'HGVS names'  ,           sort => 'string'                      },     
    { key => 'trans_pos', title => 'Position in transcript', sort => 'position', align => 'center' },
    { key => 'cds_pos',   title => 'Position in CDS',        sort => 'position', align => 'center' },
    { key => 'prot_pos',  title => 'Position in protein',    sort => 'position', align => 'center' },
    { key => 'aa',        title => 'Amino acid',             sort => 'string'                      },
    { key => 'codon',     title => 'Codons',                 sort => 'string'                      },
  );
  
  $table->add_columns(
    { key => 'sift',      title => 'SIFT',                   sort => 'position_html'                      },
    { key => 'polyphen',  title => 'PolyPhen',               sort => 'position_html'                      },
  ) if $hub->species =~ /homo_sapiens/i;
  
  $table->add_columns(
    { key => 'detail',    title => 'Detail',                 sort => 'string'                      },
  );
  
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
      my $trans_type = '<b>biotype: </b>'.$tva->transcript->biotype;
      
      my $gene_url;
      my $transcript_url;
      
      my $gene_hgnc = "";
      my @entries = grep {$_->database eq 'HGNC'} @{$gene->get_all_DBEntries()};
      if(scalar @entries) {
          $gene_hgnc = '<b>HGNC: </b>'.$entries[0]->display_id;
      }
      
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
      } 
      #ÊLRGs need to be linked to differently
      else {
        $gene_url = $hub->url({
            type   => 'LRG',
            action => 'Variation_LRG/Table',
            db     => 'core',
            r      => undef,
            lrg    => $gene_name,
            v      => $name,
            source => $source,
            __clear => 1
        });
      
        $transcript_url = $hub->url({
            type   => 'LRG',
            action => 'Variation_LRG/Table',
            db     => 'core',
            r      => undef,
            lrg    => $gene_name,
            lrgt   => $trans_name,
            v      => $name,
            source => $source,
            __clear => 1
        });
      }
      
      # HGVS
      my $hgvs;
      
      unless ($object->is_somatic_with_different_ref_base){
        $hgvs = $tva->hgvs_coding if defined($tva->hgvs_coding);
        $hgvs .= '<br />'.$tva->hgvs_protein if defined($tva->hgvs_protein);
      }

      # Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      
      my $codon = $transcript_data->{'codon'} || '-';
      
      if ($codon ne '-') {
        $codon =~ s/[ACGT]/'<b>'.$&.'<\/b>'/eg;
        $codon =~ tr/acgt/ACGT/;
      }
      
      my $strand = ($trans->strand < 1 ? '-' : '+');
      
      # consequence type
      my $type;
      
      if($cons_format eq 'so') {
        $type = join ", ", map {$hub->get_ExtURL_link($_->SO_term, 'SEQUENCE_ONTOLOGY', $_->SO_accession)} @{$tva->get_all_OverlapConsequences};
      }
      
      elsif($cons_format eq 'ncbi') {
        # not all terms have an ncbi equiv so default to SO
        $type = join ", ", map {$_->NCBI_term || '<span title="'.$_->description.' (no NCBI term available)">'.$_->label.'*</span>'} @{$tva->get_all_OverlapConsequences};
      }
      
      else {
        $type = join ", ", map{'<span title="'.$_->description.'">'.$_->label.'</span>'} @{$tva->get_all_OverlapConsequences};
      }
      
      # consequence rank
      my $rank = (sort map {$_->rank} @{$tva->get_all_OverlapConsequences})[0];
      
      $type = qq{<span class="hidden">$rank</span>$type};
      
      # detail panel
      my $a = $transcript_data->{'vf_allele'};
      
      my $url = $hub->url('Component', {
        action       => 'Web',
        function     => 'Mappings',
        transcript   => $trans_name,
        vf           => $varif_id,
        allele       => $a,
        update_panel => 1
      });
      
      my $detail = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$trans_name\_$varif_id\_$a">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };
      
      # sift
      my $sift = $self->render_sift_polyphen(
        $tva->sift_prediction || '-',
        $show_scores eq 'yes' ? $tva->sift_score : undef
      );
      my $poly = $self->render_sift_polyphen(
        $tva->polyphen_prediction || '-',
        $show_scores eq 'yes' ? $tva->polyphen_score : undef
      );
      
      my $allele = $transcript_data->{'vf_allele'};
      $allele .= ' ('.$transcript_data->{'tr_allele'}.')' unless $transcript_data->{'vf_allele'} =~ /HGMD|LARGE|DEL|INS/;
      
      my $row = {
        allele    => $allele,
        gene      => qq{<a href="$gene_url">$gene_name</a><br/><span class="small">$gene_hgnc</span>},
        trans     => qq{<nobr><a href="$transcript_url">$trans_name</a> ($strand)</nobr><br/><span class="small">$trans_type</span>},
        type      => $type,
        #hgvs      => $hgvs || '-',
        trans_pos => $self->_sort_start_end($transcript_data->{'cdna_start'},        $transcript_data->{'cdna_end'}),
        cds_pos   => $self->_sort_start_end($transcript_data->{'cds_start'},        $transcript_data->{'cds_end'}),
        prot_pos  => $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'}),
        aa        => $transcript_data->{'pepallele'} || '-',
        codon     => $codon,
        sift      => $sift,
        polyphen  => $poly,
        detail    => $detail,
      };
      
      $table->add_row($row);
      $flag = 1;
    }
  }

  if ($flag) {
    $html .= $table->render;
    
    #$html .= $self->_info('Information','<p><span style="color:red;">*</span> SO terms are shown when no NCBI term is available</p>', '50%') if $cons_format eq 'ncbi';
    
    return $html;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped to any Ensembl genes or transcripts</p>');
  }
}

# Mapping_table
# Arg1     : start and end coordinate
# Example  : $coord = _sort_star_end($start, $end)_
# Description : Returns $start-$end if they are defined, else 'n/a'
# Returns  string
sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) { 
    if($start == $end) {
      return $start;
    }
    else {
      return "$start-$end";
    }
  }
  else {
    return '-';
  };
}


# detail panel
sub detail_panel {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;
  
  my $allele   = $object->param('allele');
  my $tr_id    = $object->param('transcript');
  my $vf_id    = $object->param('vf');
  my %mappings = %{$object->variation_feature_mapping};
  
  my $html;
  
  foreach my $t_data(@{$mappings{$vf_id}{'transcript_vari'}}) {
    next unless $t_data->{transcriptname} eq $tr_id;
    next unless $t_data->{tva}->variation_feature_seq eq $allele;
    
    # data for table
    my %data;
    
    my $tv       = $t_data->{tv};
    my $tva      = $t_data->{tva};
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
      type   => 'Gene',
      action => 'Variation_Gene/Table',
      db     => 'core',
      r      => undef,
      g      => $gene_id,
      v      => $object->name,
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
    
    $data{allele}     = $allele;
    $data{t_allele}   = $t_allele;
    $data{name}       = $object->name;
    $data{gene}       = qq{<a href="$gene_url">$gene_id</a>};
    $data{transcript} = qq{<a href="$tr_url">$tr_id</a>};
    $data{protein}    = $prot_id ? qq{<a href="$prot_url">$prot_id</a>} : '-';
    $data{ens_term}   = join ", ", map {$_->label.' <i>('.$_->description.')</i>'} @$ocs;
    $data{so_term}    = join ", ", map {$_->SO_term.' ('.$hub->get_ExtURL_link($_->SO_accession, 'SEQUENCE_ONTOLOGY', $_->SO_accession).')'} @$ocs;
    $data{hgvs}       = $tva->hgvs_coding.'<br/>'.$tva->hgvs_protein || '-';
    
    foreach my $oc(@$ocs) {
      push @{$data{ncbi_term}}, $oc->NCBI_term if defined $oc->NCBI_term;
    }
    $data{ncbi_term} = (join ", ", @{$data{ncbi_term} || []}) || '-';
    
    if($tv->affects_transcript) {
      #$data{context} = $self->render_context($tv, $tva);
      my $context_url = $hub->url({
        type      => 'Transcript',
        action    => 'Sequence_cDNA',
        db        => 'core',
        r         => undef,
        t         => $tr_id,
        vf        => $vf_id,
        v         => $object->name,
      });
      $data{context} = qq{<a href="$context_url">Show in transcript</a>};
      
      # work out which exon it is in
      my @exons = @{$tr->get_all_Exons};      
      my $exon_number = 0;
      my $exon;
      
      while($exon_number < scalar @exons) {
        $exon = $exons[$exon_number++];
        last if $tv->cdna_end >= $exon->cdna_start($tr) && $tv->cdna_start <= $exon->cdna_end($tr);
      }
      
      my $exon_url = $hub->url({
        type         => 'Transcript',
        action       => 'Exons',
        transcript   => $tr_id,
        vf           => $vf_id,
      });
      
      $data{exon} = sprintf(
        '<a href="%s">%s</a> (%i of %i, length %i)',
        $exon_url,
        $exon->stable_id,
        $exon_number,
        scalar @exons,
        $exon->length
      );
      
      $data{exon_coord} =
        ($tv->cdna_start - $exon->cdna_start($tr) + 1).
        ($tv->cdna_end == $tv->cdna_start ? "" : "-".($tv->cdna_end - $exon->cdna_start($tr) + 1));
    }
    
    $html .= qq{
      <br/>
      <h2 style="float:left"><a href="#" class="toggle open" rel="$tr_id\_$vf_id\_$allele">Detail for $data{name} ($allele) in $tr_id</a></h2>
      <span style="float:right;"><a href="#$self->{'id'}_top">[back to top]</a></span>
      <p class="invisible">.</p>
    };
    
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
    
    my $table_html = '';
    my $class = "bg2";
    
    foreach my $row(@rows) {
      my $key   = (keys %$row)[0];
      my $val   = $data{$key} || '-';
      my $title = $row->{$key};
      
      $table_html .= qq{
        <tr class="$class">
          <td style="width:20%"><b>$title</b></td>
          <td>$val</td>
        </tr>
      };
      
      $class = $class eq 'bg2' ? 'bg1' : 'bg2';
    }
    
    $html .= sprintf '<div class="toggleable">%s</div>', qq{
      <table class="ss">
        $table_html
      </table>
    };
  }
  
  return $html;
}

## THIS METHOD IS WIP AND NOT IN USE RIGHT NOW
## WILL BE USED TO RENDER THE CONTEXT OF THE VARIANT WITH
## PREDICTED PEPTIDE SEQUENCE IF FRAMESHIFT ETC
sub render_context {
  my $self = shift;
  my $tv = shift;
  my $tva = shift;
  
  my $context;
  
  my $transcript = $tv->transcript;
  
  my $cdna_seq = $transcript->seq->seq;
  my ($cdna_start, $cdna_end) = ($tv->cdna_start, $tv->cdna_end);
  my $tv_phase = (($cdna_start - $transcript->cdna_coding_start) + 1) % 3;
  my $context_size = 32;
  
  my $ref_a = substr($cdna_seq, $cdna_start - 1, ($cdna_end - $cdna_start) + 1);
  my $var_a = $tva->feature_seq;;
  
  my $length_diff = length($var_a) - length($ref_a);
  
  if($length_diff != 0) {
    $ref_a .= '-' x ($length_diff > 0 ? $length_diff : 0);
    $var_a .= '-' x ($length_diff < 0 ? 0 - $length_diff : 0);
  }
  
  my ($tmp_r, $tmp_v) = ($ref_a, $var_a);
  $tmp_r =~ s/\-//g;
  $tmp_v =~ s/\-//g;
  my $var_length_diff = length($tmp_v) - length($tmp_r);
  my $is_insertion = $var_length_diff > 0 ? 1 : 0;
  
  my $up_seq = substr($cdna_seq, ($cdna_start - 1) - $context_size, $context_size);
  my $down_seq = substr($cdna_seq, $cdna_end, $context_size);
  
  $context = '';
  #$context .= '<pre>'.$up_seq.'</pre><pre>'.$ref_a.'/'.$var_a.'</pre><pre>'.$down_seq.'</pre>';
  
  my ($ref_down_seq, $var_down_seq) = ($down_seq, $down_seq);
  
  #my $debug_seq = substr($cdna_seq, ($cdna_start - 1) - $context_size, ($context_size * 2) + length($ref_a));
  #$context .= '<pre>'.$debug_seq.'</pre>';
  
  if(defined($tv->cds_start)) {
    
    #warn "TV PHASE is $tv_phase";
    
    # render up seq codons backwards (easier!)
    my ($s, $e);
    my $cur_pos = $tv->cds_start;
    
    my $tmp_phase = ($tv_phase + 2) % 3;
    my $chop_length = $tmp_phase;
    
    while(length($up_seq) > 0) {
      my $sub_start = length($up_seq) - $chop_length;
      $sub_start = 0 if $sub_start < 0;
      
      my $sub_seq = substr($up_seq, $sub_start, $chop_length);
      
      $cur_pos -= $chop_length;
      
      # start codon?
      if($sub_seq eq 'ATG' && $cur_pos == 1) {
        $up_seq = length($up_seq) > 3 ? substr($up_seq, 0, $sub_start) : '';
        $s =
          '<span style="background-color:#ffdf33">'.$up_seq.'</span>'.
          '<span style="background-color:'.($e ? '#fff9af' : 'white').'">'.$sub_seq.'</span>'.
          $s;
        last;
      }
      
      $s =
        '<span style="background-color:'.
        ($e ? '#fff9af' : 'white').'">'.
        $sub_seq.
        '</span>'.$s;
      
      last if length($up_seq) <= 3;
      $up_seq = substr($up_seq, 0, $sub_start);
      $chop_length = 3;
      $e = 1 - $e;
    }
    
    $up_seq = $s;
    
    $tmp_phase = 3 - (($tv_phase + length($tmp_r) - 1) % 3);
    
    $e = 0; 
    
    #warn "TMP PHASE FOR REF DOWN CDNA $tmp_phase";
    
    $chop_length = $tmp_phase;
    $s = '';
    
    while(length($down_seq) > 0) {
      my $sub_seq = substr($down_seq, 0, $chop_length);
      
      # stop codon?
      if($sub_seq eq 'TAA' || $sub_seq eq 'TAG' || $sub_seq eq 'TGA') {
        $down_seq = length($down_seq) >= 3 ? substr($down_seq, $chop_length) : '';
        $s .=
            '<span style="background-color:'.
          ($e ? '#fff9af' : 'white').'">'.
          $sub_seq.
          '</span>'.
          '<span style="background-color:#ffdf33">'.$down_seq.'</span>';
        last;
      }
      
      $s .=
        '<span style="background-color:'.
        ($e ? '#fff9af' : 'white').'">'.
        $sub_seq.
        '</span>';
        
      last if length($down_seq) < 3;
      $down_seq = substr($down_seq, $chop_length);
      $chop_length = 3;
      $e = 1 - $e;
    }
    
    $down_seq = $s;
    
    ($ref_down_seq, $var_down_seq) = ($down_seq, $down_seq);
    
    # recalc down_seq if var changes length
    if($var_length_diff != 0) {
      
      $tmp_phase = 3 - (($tv_phase + length($tmp_v) - 1) % 3);
      #$tmp_phase = 3 if $tmp_phase == 0;
      
      $e = 0; 
      
      #warn "TMP PHASE FOR VAR DOWN CDNA $tmp_phase";
      
      $chop_length = $tmp_phase;
      $s = '';
      $down_seq = substr($cdna_seq, $cdna_end, $context_size);
      
      while(length($down_seq) > 0) {
        
        my $sub_seq = substr($down_seq, 0, $chop_length);
        
        # stop codon?
        if($sub_seq eq 'TAA' || $sub_seq eq 'TAG' || $sub_seq eq 'TGA') {
          $down_seq = length($down_seq) >= 3 ? substr($down_seq, $chop_length) : '';
          $s .=
              '<span style="background-color:'.
            ($e ? '#fff9af' : 'white').'">'.
            $sub_seq.
            '</span>'.
            '<span style="background-color:#ffdf33">'.$down_seq.'</span>';
          last;
        }
        
        $s .=
          '<span style="background-color:'.
          ($e ? '#fff9af' : 'white').'">'.
          $sub_seq.
          '</span>';
        last if length($down_seq) < 3;
        $down_seq = substr($down_seq, $chop_length);
        $chop_length = 3;
        $e = 1 - $e;
      }
      
      $var_down_seq = $s;
    }
  }
  
  my $ref_seq = $up_seq.'<span style="background-color:green;color:white;font-weight:bold">'.$ref_a.'</span>'.$ref_down_seq;
  my $var_seq = $up_seq.'<span style="background-color:red;color:white;font-weight:bold">'.$var_a.'</span>'.$var_down_seq;
  
  my ($is_new_pep_trimmed, $new_pep_has_stop);
  
  # peptide seq
  if(defined($transcript->translation)) {
    my $translated_seq = $transcript->translation->seq;
    
    my ($t_start, $t_end) = ($tv->translation_start, $tv->translation_end);
    
    my $ref_pep = substr($translated_seq, $t_start - 1, ($t_end - $t_start) + 1);
    my $var_pep = $tva->peptide;
    $var_pep =~ s/\-//g;
    
    
    #warn "REF PEP $ref_pep   VAR PEP $var_pep";
    
    my $pep_context_size = int(($context_size - 1)/3);
    my $p_start = ($t_start - 1) - $pep_context_size;
    my $p_up_length = $pep_context_size;
    $p_up_length += $p_start if $p_start < 0;
    $p_start = 0 if $p_start < 0;
    
    my $up_pep = substr($translated_seq, $p_start , $p_up_length);
    my $down_pep = substr($translated_seq, $t_end, $pep_context_size);
    
    # render up_pep
    my $s = '';
    $s .= " $_ " for (split //, $up_pep);        
    $s = (' ' x (($context_size - (($tv_phase + 2) % 3)) - length($s))).$s;
    $up_pep = $s;
    
    
    # prepare down pep seq
    
    # we need to re-translate if frame shift        
    my ($ref_down_pep, $var_down_pep) = ($down_pep, $down_pep);
    
    my $is_tran_different;
    
    if($var_length_diff != 0 && abs($var_length_diff) % 3 != 0) {
      
      # we need position of last complete codon
      my $low_pos = ($cdna_start < $cdna_end ? $cdna_start : $cdna_end);
      my $high_pos = ($cdna_start < $cdna_end ? $cdna_end : $cdna_start);
      my $last_complete_codon = $transcript->cdna_coding_start + (($tv->translation_start - 1) * 3) - 1;
      
      my $before_var_seq = substr($cdna_seq, $last_complete_codon, $low_pos - $last_complete_codon - ($is_insertion ? 0 : 1));
      my $after_var_seq = substr($cdna_seq, $high_pos - ($is_insertion ? 1 : 0));
      
      #warn "LOW $low_pos HIGH $high_pos";
      #warn "LCC $last_complete_codon";
      #warn "BEFORE $before_var_seq";
      #warn "AFTER ".substr($after_var_seq, 0, 10);
      #warn "VAR_LD $var_length_diff";
      
      my $to_translate = $before_var_seq.$var_a.$after_var_seq;
      $to_translate =~ s/\-//g;
      
      #warn "To translate ", substr($to_translate, 0, 10);
      
      my $codon_seq = Bio::Seq->new(
        -seq      => $to_translate,
        -moltype  => 'dna',
        -alphabet => 'dna'
      );
      
      # get codon table
      my ($attrib) = @{$transcript->slice()->get_all_Attributes('codon_table')}; #for mithocondrial dna it is necessary to change the table
      my $codon_table;
      $codon_table = $attrib->value() if($attrib);
      $codon_table ||= 1;
      
      my $new_phase = ($tv_phase + 1) % 3;

      my $new_pep = $codon_seq->translate(undef,undef,undef,$codon_table)->seq();
      $new_pep =~ s/\*.+/\*/;
      $new_pep_has_stop = $new_pep =~ /\*/;
      
      $var_down_pep = $new_pep;
      
      if(length($var_down_pep) > $pep_context_size) {
        $is_new_pep_trimmed = length($var_down_pep) - $pep_context_size + 1;
        $var_down_pep = substr($var_down_pep, 0, $pep_context_size + 1);
      }
      
      $is_tran_different = 1;
    }
    
    $s = '';
    my $tmp_phase = ($tv_phase + 1) % 3;
    $s .= " $_ " for (split //, $down_pep);
    $ref_down_pep = $s;
    #$ref_down_pep =~ s/( [A-Z] )( [A-Z] )/'<span style="background-color:lightgrey">'.$1.'<\/span>'.$2/eg;
    
    $s = '';
    $tmp_phase = ($tv_phase + 1) % 3;
    $s .= " $_ " for (split //, $var_down_pep);
    $var_down_pep = $s;
    
    $ref_pep = ' '.(join "  ", split "", $ref_pep).' ' unless $ref_pep eq '';
    $var_pep = ' '.(join "  ", split "", $var_pep).' ' unless $var_pep eq '';
    
    # insertion
    if($var_length_diff > 0) {
      my ($up_space, $down_space);
      $up_space = int($var_length_diff / 2);
      $down_space = $var_length_diff - $up_space;
      
      #warn "UP $up_space DOWN $down_space";
      $ref_pep = (' ' x $up_space).$ref_pep.(' ' x $down_space);
    }
    
    # deletion
    elsif($var_length_diff < 0) {
      my ($up_space, $down_space);
      $up_space = int(abs($var_length_diff) / 2);
      $down_space = abs($var_length_diff) - $up_space;
      
      #warn "UP $up_space DOWN $down_space";
      $var_pep = (' ' x $up_space).$var_pep.(' ' x $down_space);
    }
    
    $var_down_pep =
      '<span style="background-color:red;color:white;font-weight:bold">'.
      $var_down_pep.
      '</span>' if $is_tran_different;
    
    $ref_seq =
      $up_pep.
      '<span style="background-color:green;color:white;font-weight:bold">'.
      $ref_pep.
      '</span>'.
      $ref_down_pep.'<br/>'.$ref_seq;
    
    $var_seq =
      $var_seq.
      '<br/>'.
      $up_pep.
      '<span style="background-color:red;color:white;font-weight:bold">'.
      $var_pep.
      '</span>'.
      $var_down_pep;
      
    warn "VAR LENGTH DIFF $var_length_diff";
  }
  
  $context .= '<pre>'.$ref_seq.'<br/>'.$var_seq.'</pre>';
  
  if($is_new_pep_trimmed) {
    $context .= '<p>Predicted variant peptide extends for '.$is_new_pep_trimmed.' residues beyond displayed sequence</p>';
  }
  unless($new_pep_has_stop) {
    $context .= '<p>Predicted variant peptide has no STOP codon</p>';
  }
  
  return $context;
}

1;
