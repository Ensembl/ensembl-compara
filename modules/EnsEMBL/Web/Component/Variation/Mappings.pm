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
  my $self = shift;
  my $object = $self->object;

  # first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;

  my %mappings = %{$object->variation_feature_mapping};

  return [] unless keys %mappings;

  my $hub    = $self->hub;
  my $source = $object->source;
  my $name   = $object->name;
  
  my $cons_format = $object->param('consequence_format');
  my $show_scores = $object->param('show_scores');
  
  my $html;
  
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
    { key => 'trans',     title => 'Transcript (strand)',    sort => 'html'                        },
    { key => 'allele',    title => 'Allele (transcript allele)', sort => 'string', width => '7%'          },
    { key => 'type',      title => 'Type'  ,                 sort => 'position_html'                      },
    { key => 'hgvs',      title => 'HGVS names'  ,           sort => 'string'                      },     
    { key => 'trans_pos', title => 'Position in transcript', sort => 'position', align => 'center' },
    { key => 'cds_pos',   title => 'Position in CDS',        sort => 'position', align => 'center' },
    { key => 'prot_pos',  title => 'Position in protein',    sort => 'position', align => 'center' },
    { key => 'aa',        title => 'Amino acid',             sort => 'string'                      },
    { key => 'codon',     title => 'Codons',                 sort => 'string'                      },
    #{ key => 'info',      title => 'Info',                       sort => 'string'                      },
  );
  
  $table->add_columns(
    { key => 'sift',      title => 'SIFT',                   sort => 'position_html'                      },
    { key => 'polyphen',  title => 'PolyPhen',               sort => 'position_html'                      },
  ) if $hub->species =~ /homo_sapiens/i;
  
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
      
      my $gene_url;
      my $transcript_url;
      
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
            source => $source
        });
      
        $transcript_url = $hub->url({
            type   => 'LRG',
            action => 'Variation_LRG/Table',
            db     => 'core',
            r      => undef,
            lrg    => $gene_name,
            lrgt   => $trans_name,
            v      => $name,
            source => $source
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
      
      # info panel
      #my $allele = $transcript_data->{'vf_allele'};
      #
      #my $url = $hub->url('Component', {
      #  action       => 'Web',
      #  function     => 'MappingPanel',
      #  transcript   => $trans_name,
      #  vf           => $varif_id,
      #  allele       => $transcript_data->{'vf_allele'},
      #  update_panel => 1
      #});
      #
      #my $info = qq{
      #  <a href="$url" class="ajax_add toggle closed" rel="$trans_name\_$varif_id\_$allele">
      #    <span class="closed">Show</span><span class="open">Hide</span>
      #    <input type="hidden" class="url" value="$url" />
      #  </a>
      #};
      
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
        gene      => qq{<a href="$gene_url">$gene_name</a>},
        trans     => qq{<nobr><a href="$transcript_url">$trans_name</a> ($strand)</nobr>},
        type      => $type,
        hgvs      => $hgvs || '-',
        trans_pos => $self->_sort_start_end($transcript_data->{'cdna_start'},        $transcript_data->{'cdna_end'}),
        cds_pos   => $self->_sort_start_end($transcript_data->{'cds_start'},        $transcript_data->{'cds_end'}),
        prot_pos  => $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'}),
        aa        => $transcript_data->{'pepallele'} || '-',
        codon     => $codon,
        sift      => $sift,
        polyphen  => $poly,
        #info      => $info,
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

1;
