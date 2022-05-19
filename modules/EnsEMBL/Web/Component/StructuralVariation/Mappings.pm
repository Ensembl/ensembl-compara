=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::StructuralVariation::Mappings;

use strict;

use EnsEMBL::Web::Utils::Variation qw(render_consequence_type render_var_coverage);

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  my $hub      = $self->hub;
  my %mappings = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $v;

  if (keys %mappings == 1) {
    ($v) = values %mappings;
  } elsif (!$hub->param('svf')){
    return $self->_info(
      'A unique location can not be determined for this variation',
      $object->not_unique_location);
  } else { 
    $v = $mappings{$hub->param('svf')};
  }
  
  if (!$v) { 
    return $self->_info(
      'Location problem',
      "<p>Unable to draw structural variant neighbourhood as we cannot uniquely determine the structural variant's location</p>"
    );
  }
  
  my $svf_id = $hub->param('svf');

  my $max_display_length = $object->max_display_length;
  my $feature_length = $v->{end} - $v->{start} + 1;
  if ($feature_length > $max_display_length) {
    my $max_display_end = $v->{start} + $max_display_length - 1;
    my $region_overview_url = $hub->url({
       type   => 'Location',
       action => 'Overview',
       db     => 'core',
       r      => $v->{Chr}.':'.$v->{start}.'-'.$v->{end},
       sv     => $hub->param('sv'),
       svf    => $svf_id,
       cytoview => 'variation_feature_structural_smaller=compact,variation_feature_structural_larger=gene_nolabel'
    });
    my $region_detail_url = $hub->url({
       type   => 'Location',
       action => 'View',
       db     => 'core',
       r      => $v->{Chr}.':'.$v->{start}.'-'.$max_display_end,
       sv     => $hub->param('sv'),
       svf    => $svf_id,
       contigviewbottom => 'variation_feature_structural_smaller=gene_nolabel,variation_feature_structural_larger=gene_nolabel'
    });
    my $warning_header = sprintf('The structural variant is too long for this display (more than %sbp)',$self->thousandify($max_display_length));
    my $warning_content = qq{Please, view the list of overlapping genes, transcripts and structural variants in the <a href="$region_overview_url">Region overview</a> page};
    my $warning_content_end = sprintf('.<br />The context of the first %sbp of the structural variant is available in the <a href="%s">Region in detail</a> page.',
                                      $self->thousandify($max_display_length),$region_detail_url
                                     );
    if ($hub->species_defs->ENSEMBL_MART_ENABLED) {
      my @species = split('_',lc($hub->species));
      my $mart_dataset = substr($species[0],0,1).$species[1].'_gene_ensembl';
      my $mart_url = sprintf( '/biomart/martview?VIRTUALSCHEMANAME=default'.
                       '&ATTRIBUTES=%s.default.feature_page.ensembl_gene_id|%s.default.feature_page.ensembl_transcript_id|'.
                       '%s.default.feature_page.strand|%s.default.feature_page.ensembl_peptide_id'.
                       '&FILTERS=%s.default.filters.chromosomal_region.%s:%i:%i:1&VISIBLEPANEL=resultspanel',
                       $mart_dataset,$mart_dataset,$mart_dataset,$mart_dataset,$mart_dataset,$v->{Chr}, $v->{start}, $v->{end}
                     );

      $warning_content .= qq{ or in <a href="$mart_url">BioMart</a>};
    } 
    return $self->_warning( $warning_header, $warning_content.$warning_content_end );
  }

  # Get the corresponding StructuralVariationFeature object instance
  my ($svf_obj)  = grep {$_->dbID eq $svf_id} @{$self->object->get_structural_variation_features};

  return
    '<h2>Gene and Transcript consequences</h2>'.$self->gene_transcript_table($svf_obj).
    '<h2>Regulatory consequences</h2>'.$self->regfeat_table($svf_obj);
}

sub gene_transcript_table {
  my $self = shift;
  my $svf  = shift;
  
  my $hub = $self->hub;
  
  my $columns = [
    { key => 'gene',      sort => 'string',   title => 'Gene',                   width => '1u' },
    { key => 'trans',     sort => 'string',   title => 'Transcript (strand)',    width => '1u' },
    { key => 'allele',    sort => 'string',   title => 'Allele type',            width => '1u' },
    { key => 'type',      sort => 'string',   title => 'Consequence types',      width => '2u' },
    { key => 'trans_pos', sort => 'position', title => 'Position in transcript', width => '1u' },
    { key => 'cds_pos',   sort => 'position', title => 'Position in CDS',        width => '1u' },
    { key => 'prot_pos',  sort => 'position', title => 'Position in protein',    width => '1u' },
    { key => 'exons',     sort => 'string',   title => 'Exons',                  width => '1u' },
    { key => 'coverage',  sort => 'none',     title => 'Transcript coverage',    width => '1u' },
  ];
  
  my $rows = [];
  my $ga = $hub->get_adaptor('get_GeneAdaptor');

  foreach my $tsv (@{$svf->get_all_TranscriptStructuralVariations}) {  
    my $t = $tsv->transcript;
    my $g = $ga->fetch_by_transcript_stable_id($t->stable_id);
      
    my $gene_name  = $g ? $g->stable_id : '';
    my $trans_name = $t->stable_id;
    my $trans_type = '<b>biotype: </b>' . $t->biotype;
    my @entries    = grep $_->database eq 'HGNC', @{$g->get_all_DBEntries};
    my $gene_hgnc  = scalar @entries ? '<b>HGNC: </b>' . $entries[0]->display_id : '';
    my $strand     = $t->strand;
    my $exon       = $tsv->exon_number;
    $exon         =~ s/\// of /;
    my $allele    = sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
      $self->object->get_class_colour($svf->class_SO_term),
      $svf->var_class
    );
      
    my ($gene_url, $transcript_url);
      
    # Create links to non-LRG genes and transcripts
    if ($trans_name !~ m/^LRG/) {
      $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        db     => 'core',
        r      => undef,
        g      => $gene_name,
      });
      
      $transcript_url = $hub->url({
        type   => 'Transcript',
        action => 'Summary',
        db     => 'core',
        r      => undef,
        t      => $trans_name,
      });
    } else {
      $gene_url = $hub->url({
        type     => 'LRG',
        action   => 'Summary',
        function => 'Table',
        db       => 'core',
        r        => undef,
        lrg      => $gene_name,
        __clear  => 1
      });
    
      $transcript_url = $hub->url({
        type     => 'LRG',
        action   => 'Summary',
        function => 'Table',
        db       => 'core',
        r        => undef,
        lrg      => $gene_name,
        lrgt     => $trans_name,
        __clear  => 1
      });
    }
      
    $trans_name .= ".".$t->version if($t->version); #transcript version
    foreach my $tsva(@{$tsv->get_all_StructuralVariationOverlapAlleles}) {
      my $type = render_consequence_type($hub, $tsva);
      
      my %row = (
        gene      => qq{<a href="$gene_url">$gene_name</a><br/><span class="small" style="white-space:nowrap;">$gene_hgnc</span>},
        trans     => qq{<nobr><a href="$transcript_url">$trans_name</a> ($strand)</nobr><br/><span class="small" style="white-space:nowrap;">$trans_type</span>},
        allele    => $allele,
        type      => $type,
        trans_pos => $self->_sort_start_end($tsv->cdna_start,        $tsv->cdna_end),
        cds_pos   => $self->_sort_start_end($tsv->cds_start,         $tsv->cds_end),
        prot_pos  => $self->_sort_start_end($tsv->translation_start, $tsv->translation_end),
        exons     => $exon || '-',
        coverage  => $self->_coverage_glyph($t, $svf),
      );
        
      push @$rows, \%row;
    }
  }

  return @$rows ? $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'gene asc' ], data_table_config => {iDisplayLength => 25} })->render : '<p>No Gene or Transcript consequences</p>';
}

sub regfeat_table {
  my $self = shift;
  my $svf  = shift;
  
  my $hub = $self->hub;
  
  my $columns = [
    { key => 'rf',       title => 'Feature',           sort => 'html'          },
    { key => 'ftype',    title => 'Feature type',      sort => 'string'        },
    { key => 'allele',   title => 'Allele type',       sort => 'string'        },
    { key => 'type',     title => 'Consequence types', sort => 'position_html' },
    { key => 'coverage', title => 'Feature coverage',  sort => 'string',       },
  ];
  
  my $rows = [];
  
  foreach my $rsv(@{$svf->get_all_RegulatoryFeatureStructuralVariations}) {
    
    my $rf     = $rsv->feature->stable_id;
    my $ftype  = 'Regulatory feature';
    my $allele = sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
                         $self->object->get_class_colour($svf->class_SO_term),
                         $svf->var_class);
      
    # create a URL
    my $url = $hub->url({
      type   => 'Regulation',
      action => 'Summary',
      rf     => $rsv->feature->stable_id,
      fdb    => 'funcgen',
    });
     
    foreach my $rsva(@{$rsv->get_all_StructuralVariationOverlapAlleles}) {
      my $type = render_consequence_type($hub, $rsva);
      my %row = (
        rf       => sprintf('<a href="%s">%s</a>', $url, $rf),
        ftype    => $ftype,
        allele   => $allele,
        type     => $type,
        coverage => $self->_coverage_glyph($rsv->feature, $svf),
      );
        
      push @$rows, \%row;
    }
  }

  return @$rows ? $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'rf asc' ], data_table_config => {iDisplayLength => 25} })->render : '<p>No overlap with Ensembl Regulatory features</p>';
}

sub _coverage_glyph {
  my $self = shift;
  my $f    = shift;
  my $v    = shift;
  
  my $html  = '';
  my $width = 100;
  my ($f_s, $f_e, $v_s, $v_e) = (
    $f->seq_region_start,
    $f->seq_region_end,
    $v->seq_region_start,
    $v->seq_region_end,
  );
  
  # flip if on reverse strand
  if($f->strand == -1) {
    $f_e -= $f_s;
    $_ = $f_e - ($_ - $f_s) for ($v_s, $v_e);
    ($v_s, $v_e) = ($v_e, $v_s);
    $f_s = 0;
  }
  
  return '-' unless $v_s <= $f_e && $v_e >= $f_s;
  
  my $scale = 100 / ($f_e - $f_s + 1);
  my ($bp, $pc);
  
  if ($v_s <= $f_e && $v_e >= $f_s) {
    my $s = (sort {$a <=> $b} ($v_s, $f_s))[-1];
    my $e = (sort {$a <=> $b} ($v_e, $f_e))[0];
    
    $bp = ($e - $s) + 1;
    $pc = sprintf("%.2f", 100 * ($bp / ($f->feature_Slice->length)));
  }
  
  my $glyph = render_var_coverage($f_s, $f_e, $v_s, $v_e, $self->object->get_class_colour($v->class_SO_term));
  $html .= $glyph if ($glyph);
  
  return
   '<div style="width:'.($width + 12).'px">'.
     '<div style="float:left;margin-bottom:2px">'.$html.'</div>'.
     sprintf("<span class='small' style='float:right'>%ibp, %s\%</span>", $bp, $pc).
   '</div>';
}

sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) { 
    if ($start == $end) {
      return $start;
    } else {
      $start ||= '?';
      $end   ||= '?';
      return "$start-$end";
    }
  } else {
    return '-';
  };
}
1;
