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

package EnsEMBL::Web::Component::Summary;

### Content that needs to appear on both Gene and Transcript pages

use strict;

use HTML::Entities  qw(encode_entities);
use List::Util      qw(first);
use List::MoreUtils qw(first_index);

use EnsEMBL::Web::Utils::FormatText qw(coltab helptip get_glossary_entry);

use parent qw(EnsEMBL::Web::Component);

sub summary {
  my ($self, $page_type) = @_;

  my $hub         = $self->hub;
  my $object      = $self->object;  
  my $species     = $hub->species;

  ## Build two-column layout of main content
  my $two_col     = $self->new_twocol;
  my $gene        = $page_type eq 'gene' ? $object->Obj : $object->gene;

  my $description = $self->get_description;
  $two_col->add_row('Description', $description) if $description;
  
  my $synonyms = $self->get_synonym_html($gene);
  $two_col->add_row('Gene Synonyms', $synonyms) if $synonyms;

  my $location_html = $self->get_location_html($page_type);
  $two_col->add_row('Location', $location_html);

  ## Extra content (if relevant)
  my @extra_rows = $self->get_extra_rows($page_type);
  $two_col->add_rows(@extra_rows) if scalar @extra_rows;

  ## Finally add general information
  my $about_count = $gene ? $self->about_feature : 0; 
  $two_col->add_row( $page_type eq 'gene' ? 'About this gene' : 'About this transcript', $about_count) if $about_count;

  ## Add button to toggle table (below)
  my $show        = $hub->get_cookie_value('toggle_transcripts_table') eq 'open';
  my $button_html = $self->get_button_html($gene, $page_type, $show);
  $two_col->add_row($page_type eq 'gene' ? 'Transcripts' : 'Gene', $button_html) if $button_html;

  ## Now create togglable transcript table
  my $table = $self->transcript_table($page_type, $gene, $show);
  
  ## Return final HTML
  return sprintf '<div class="summary_panel">%s%s</div>', $two_col->render, $table ? $table->render : '';
}

sub get_description {
  my $self = shift;
  my $object = $self->object;

  my $description = $object->gene_description;
     $description = '' if $description eq 'No description';
  if ($description) {
    my ($url, $xref) = $self->get_gene_display_link($object->gene, $description);

    if ($xref) {
      $description =~ s|$xref|<a href="$url" class="constant">$xref</a>|;
    }
  }

  return $description;
} 

sub get_synonym_html {
  my ($self, $gene) = @_;
  my $object = $self->object;

  my (@syn_matches, $syns_html, $about_count, @proj_attrib);
  push @syn_matches,@{$self->object->get_database_matches()};

  my %unique_synonyms;
  my $c=0;
  foreach (@{$object->get_similarity_hash(0, $gene)}) {
    next unless $_->{'type'} eq 'PRIMARY_DB_SYNONYM';
    my $id   = $_->display_id;
    my %syns = %{$self->get_synonyms($id, @syn_matches) || {}};
    foreach (keys %syns) {
      $unique_synonyms{$_}++;
    }
  }
  if (%unique_synonyms) {
    my $syns = join ', ', sort keys %unique_synonyms;
    $syns_html = "<p>$syns</p>";
  }
  return $syns_html;
}

sub get_location_html {
  my ($self, $page_type) = @_;
  my $object  = $self->object;
  my $hub     = $self->hub;

  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;

  my $location    = sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;

  my $location_html = sprintf(
    '<a href="%s" class="constant dynamic-link">%s: %s-%s</a> %s.',
    $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $location, 
    }),
    $self->neat_sr_name($object->seq_region_type, $seq_region_name),
    $self->thousandify($seq_region_start),
    $self->thousandify($seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
 
  $location_html = "<p>$location_html</p>";

  my $insdc_accession = $object->insdc_accession if $object->can('insdc_accession');
  if ($insdc_accession) {
    $location_html .= "<p>$insdc_accession</p>";
  }

  if ($page_type eq 'gene') {
    # Haplotype/PAR locations
    my $alt_locs = $object->get_alternative_locations;

    if (@$alt_locs) {
      $location_html .= '
        <p> This gene is mapped to the following HAP/PARs:</p>
        <ul>';
      
      foreach my $loc (@$alt_locs) {
        my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
        
        $location_html .= sprintf('
          <li><a href="/%s/Location/View?l=%s:%s-%s" class="constant">%s : %s-%s</a></li>', 
          $self->species, $altchr, $altstart, $altend, $altchr,
          $self->thousandify($altstart),
          $self->thousandify($altend)
        );
      }
      
      $location_html .= '
        </ul>';
    }
    ## Link to other haplotype genes
    my $alt_link = $object->get_alt_allele_link;
    if ($alt_link) {
      $location_html .= "<p>$alt_link</p>";
    }   
  }

  return $location_html;
}

sub get_extra_rows {
  my ($self, $page_type) = @_;
  my $object  = $self->object;
  my $hub     = $self->hub;
  my @rows;

  ## Standard "extra content" is strain info
  my $gene        = $page_type eq 'gene' ? $object->Obj : $object->gene;
  my @proj_attrib = @{ $gene->get_all_Attributes('proj_parent_g') };

  if (@proj_attrib && $hub->is_strain) {
    (my $ref_gene = $proj_attrib[0]->value) =~ s/\.\d+$//;
    my $strain_type = $hub->species_defs->STRAIN_TYPE;
    
    if($ref_gene) {
      #copied from apache/handler, just need this one line to get the matching species for the stable_id (use ensembl_stable_id database)
      my ($species, $object_type, $db_type, $retired) = Bio::EnsEMBL::Registry->get_species_and_object_type($ref_gene, undef, undef, undef, undef, 1);
      if ($species) { #needed because some attributes are not valid e! stable IDs
        my $ga = Bio::EnsEMBL::Registry->get_adaptor($species,$db_type,'gene');
        my $gene = $ga->fetch_by_stable_id($ref_gene);
        my $ref_gene_name = $gene->display_xref->display_id;

        my $ref_url  = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          g       => $ref_gene
        });
        push @rows, ["Reference $strain_type equivalent", qq{<a href="$ref_url">$ref_gene_name</a>}];
      }
      else {
        push @rows, ["Reference $strain_type equivalent","None"];
      }  
    } else {
      push @rows, ["Reference $strain_type equivalent","None"];
    }
  }

  return @rows;
}

sub get_button_html {
  my ($self, $gene, $page_type, $show) = @_;
  return unless $gene;

  my $button_html;
  my $button      = sprintf('<a rel="transcripts_table" class="button toggle no_img _slide_toggle set_cookie %s" href="#" title="Click to toggle the transcript table">
    <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
    </a>',
    $show ? 'open' : 'closed'
  );

  if ($page_type eq 'transcript') {
    my $gene_id  = $gene->stable_id;
    my $gene_version = $gene->version ? $gene_id.'.'.$gene->version : $gene_id;
    my $gene_url = $self->hub->url({
      type   => 'Gene',
      action => 'Summary',
      g      => $gene_id
    });
    $button_html = sprintf('<p>This transcript is a product of gene <a href="%s">%s</a> %s',
      $gene_url,
      $gene_version,
      $button
    );
  }
  else {        
    $button_html = $button;
  } 

  return $button_html;
}

sub transcript_table {
  my ($self, $page_type, $gene, $show) = @_;
  return unless $gene;

  my $object    = $self->object;
  my $hub       = $self->hub;
  my $species   = $hub->species;
  my $sub_type  = $hub->species_defs->ENSEMBL_SUBTYPE;

  my $table = $self->new_table([], [], {
      data_table        => 1,
      data_table_config => { bPaginate => 'false', asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width' . ($show ? '' : ' hide'),
      id                => 'transcripts_table',
      exportable        => 1
  });

  my $has_ccds = $hub->species eq 'Homo_sapiens' || $hub->species =~ /^Mus_musculus/;
  my @columns = $self->set_columns($has_ccds);

  my @rows;

  my $gencode_desc    = qq(The GENCODE set is the gene set for human and mouse. <a href="/Help/Glossary?id=500" class="popup">GENCODE Basic</a> is a subset of representative transcripts (splice variants).);

  my $version     = $object->version ? ".".$object->version : "";
  my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
  my $transcripts = $gene->get_all_Transcripts;
  my $count       = @$transcripts;
  my $action      = $hub->action;
  my %biotype_rows;

  #keys are attrib_type codes, values are glossary entries 
  my %MANE_attrib_codes = (
    MANE_Select => 'MANE Select',
    MANE_Plus_Clinical   => 'MANE Plus Clinical');

  my $trans_attribs = {};
  my @attrib_types = ('is_canonical','gencode_basic','appris','TSL','CDS_start_NF','CDS_end_NF');
  push(@attrib_types, keys %MANE_attrib_codes);

  foreach my $trans (@$transcripts) {
    foreach my $attrib_type (@attrib_types) {
      (my $attrib) = @{$trans->get_all_Attributes($attrib_type)};
      next unless $attrib && $attrib->value;
      if ($attrib_type eq 'appris') {
        ## Assume there is only one APPRIS attribute per transcript
        my $short_code = $attrib->value;
        ## Manually shorten the full attrib values to save space
        $short_code =~ s/ernative//;
        $short_code =~ s/rincipal//;
        $trans_attribs->{$trans->stable_id}{'appris'} = [$short_code, $attrib->value]; 
      }
      elsif ($MANE_attrib_codes{$attrib_type}) {
        $trans_attribs->{$trans->stable_id}{$attrib_type} = [$attrib->name, $attrib->value];
      }
      else {
        $trans_attribs->{$trans->stable_id}{$attrib_type} = $attrib->value;
      }
    }
  }

  my %url_params = (
      type   => 'Transcript',
      action => $page_type eq 'gene' ? 'Summary' : $action,
  );
   
  my %extra_links = %{$self->get_extra_links}; 
  my %any_extras;
  foreach (@$transcripts) {
    my $transcript_length = $_->length;
    my $version           = $_->version ? ".".$_->version : "";
    my $tsi               = $_->stable_id;
    my $protein           = '';
    my $translation_id    = '';
    my $translation_ver   = '';
    my $protein_url       = '';
    my $protein_length    = '-';
    my $ccds              = '-';
    my %extras;
    my $cds_tag           = '-';
    my $gencode_set       = '-';
    my (@flags, @evidence);
     
    ## Override link destination if this transcript has no protein
    if (!$_->translation && ($action eq 'ProteinSummary' || $action eq 'Domains' || $action eq 'ProtVariations')) {
      $url_params{'action'} = 'Summary';
    }
    my $url = $hub->url({ %url_params, t => $tsi });

    if (my $translation = $_->translation) {
      $protein_url    = $hub->url({ type => 'Transcript', action => 'ProteinSummary', t => $tsi });
      $translation_id = $translation->stable_id;
      $translation_ver = $translation->version ? $translation_id.'.'.$translation->version:$translation_id;
      $protein_length = $translation->length;
    }

    my $ccds;
    if (my @CCDS = @{ $_->get_all_DBLinks('CCDS') }) { 
      my %T = map { $_->primary_id => 1 } @CCDS;
      @CCDS = sort keys %T;
      $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
    }

    foreach my $k (keys %extra_links) {

      my @links;
      if ($extra_links{$k}->{'match'}) { 
        ## Non-vertebrates - use API to filter db links, as faster
        @links = grep {$_->status ne 'PRED' } @{ $_->get_all_DBLinks($extra_links{$k}->{'match'}) }
      }
      else {
        my $dblinks = $_->get_all_DBLinks; 
        @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'first_match'}/i } @$dblinks;
        ## Try second match
        if(!@links && $extra_links{$k}->{'second_match'}){
          @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'second_match'}/i } @$dblinks;
        }
      }

      if(@links) {
        my %T = map { $_->primary_id => $_->dbname } @links;
        my $cell = '';
        my $i = 0;
        foreach my $u (map $hub->get_ExtURL_link($_,$T{$_},$_), sort keys %T) {
          $cell .= "$u ";
          if($i++==2 || $k ne 'uniprot') { $cell .= "<br/>"; $i = 0; }
        }
        $any_extras{$k} = 1;
        $extras{$k} = $cell;
      }
    }

    # Flag order: is_canonical, MANE_select, MANE_plus_clinical, gencode_basic, appris, TSL, CDS_start_NF, CDS_end_NF
    my $refseq_url;
    if ($trans_attribs->{$tsi}) {
      if ($trans_attribs->{$tsi}{'is_canonical'}) {
        push @flags, helptip("Ensembl Canonical", get_glossary_entry($hub, "Ensembl canonical"));
      }

      foreach my $MANE_attrib_code (keys %MANE_attrib_codes) {
        if (my $mane_attrib = $trans_attribs->{$tsi}{$MANE_attrib_code}) {
          my ($mane_name, $refseq_id) = @{$mane_attrib};
          $refseq_url  = $hub->get_ExtURL_link($refseq_id, 'REFSEQ_MRNA', $refseq_id);
          my $flagtip = helptip($mane_name, get_glossary_entry($hub, $MANE_attrib_codes{$MANE_attrib_code}));
          $MANE_attrib_code eq  'MANE_Select'? unshift @flags, $flagtip : push @flags, $flagtip;
        }
      }

      if ($trans_attribs->{$tsi}{'gencode_basic'}) {
        push @flags, helptip('GENCODE basic', $gencode_desc);
      }

      if ($trans_attribs->{$tsi}{'appris'}) {
        my ($code, $key) = @{$trans_attribs->{$tsi}{'appris'}};
        my $short_code = $code ? ' '.uc($code) : '';
        push @flags, helptip("APPRIS $short_code","<p>APPRIS $short_code: ".get_glossary_entry($hub, "APPRIS$short_code")."</p><p>".get_glossary_entry($hub, 'APPRIS')."</p>");
      }

      if ($trans_attribs->{$tsi}{'TSL'}) {
        my $tsl = uc($trans_attribs->{$tsi}{'TSL'} =~ s/^tsl([^\s]+).*$/$1/gr);
        push @flags, helptip("TSL:$tsl", "<p>TSL $tsl: ".get_glossary_entry($hub, "TSL $tsl")."</p><p>".get_glossary_entry($hub, 'Transcript support level')."</p>");
      }

      if (my $incomplete = $self->get_CDS_text($trans_attribs->{$tsi})) {
        push @flags, $incomplete;
      }
    }

    (my $biotype_text = $_->biotype) =~ s/_/ /g;
    if ($biotype_text =~ /rna/i) {
      $biotype_text =~ s/rna/RNA/;
    }
    else {
      $biotype_text = ucfirst($biotype_text);
    } 

    $extras{$_} ||= '-' for(keys %extra_links);
    my $row = {
      name        => { value => $_->display_xref ? $_->display_xref->display_id : '-' },
      transcript  => sprintf('<a href="%s">%s%s</a>', $url, $tsi, $version),
      bp_length   => $transcript_length,
      protein     => $protein_url ? sprintf '<a href="%s" title="View protein">%saa</a>', $protein_url, $protein_length : 'No protein',
      translation => $protein_url ? sprintf '<a href="%s" title="View protein">%s</a>', $protein_url, $translation_ver : '-',
      biotype     => $self->colour_biotype($biotype_text, $_),
      is_canonical  => $trans_attribs->{$tsi}{'is_canonical'} || $trans_attribs->{$tsi}{'MANE_Select'}? 1 : 0,
      ccds        => $ccds,
      %extras,
      has_ccds    => $ccds eq '-' ? 0 : 1,
      cds_tag     => $cds_tag,
      gencode_set => $gencode_set,
      refseq_match  => $refseq_url ? $refseq_url : '-',
      options     => { class => $count == 1 || $tsi eq $transcript ? 'active' : '' },
      flags       => @flags ? join('',map { $_ =~ /<img/ ? $_ : "<span class='ts_flag'>$_<span class='hidden export'>, </span></span>" } @flags) : '-',
      evidence    => join('', @evidence),
    };

    $biotype_text = '.' if $biotype_text eq 'Protein coding';
    $biotype_rows{$biotype_text} = [] unless exists $biotype_rows{$biotype_text};
    push @{$biotype_rows{$biotype_text}}, $row;
  }

  foreach my $k (sort { $extra_links{$a}->{'order'} cmp
                        $extra_links{$b}->{'order'} } keys %any_extras) {
    my $x = $extra_links{$k};
    push @columns, { key => $k, sort => 'html', title => $x->{'title'}, label => $x->{'name'}, class => '_ht'};
  }

  if ($species eq 'Homo_sapiens' && $sub_type eq 'GRCh37') {
    push @columns, { key => 'refseq_match', sort => 'html', label => 'RefSeq Match', title => get_glossary_entry($self->hub, 'RefSeq Match'), class => '_ht' };
  }

  my $title = encode_entities('<a href="/info/genome/genebuild/transcript_quality_tags.html" target="_blank">Tags</a>');
  push @columns, { key => 'flags', sort => 'html', label => 'Flags', title => $title, class => '_ht'};

  ## Transcript order: biotype => canonical => CCDS => length
  while (my ($k,$v) = each (%biotype_rows)) {
    my @subsorted = sort {$b->{'is_canonical'} cmp $a->{'is_canonical'}
                          || $b->{'has_ccds'} cmp $a->{'has_ccds'}
                          || $b->{'bp_length'} <=> $a->{'bp_length'}} @$v;
    $biotype_rows{$k} = \@subsorted;
  }

  # Add rows to transcript table
  push @rows, @{$biotype_rows{$_}} for sort keys %biotype_rows; 
    
  ## Add everything to the table
  $table->add_columns(@columns);
  $table->add_rows(@rows);
  return $table;
}

sub set_columns {
  my ($self, $has_ccds) = @_;

  my @columns = (
       { key => 'transcript', sort => 'html',    label => 'Transcript ID', title => 'Stable ID', class => '_ht'},
       { key => 'name',       sort => 'string',  label => 'Name', title => 'Transcript name', class => '_ht'},
       { key => 'bp_length',  sort => 'numeric', label => 'bp', title => 'Transcript length in base pairs', class => '_ht'},
       { key => 'protein',sort => 'html_numeric',label => 'Protein', title => 'Protein length in amino acids', class => '_ht'},
       { key => 'translation',sort => 'html',    label => 'Translation ID', title => 'Protein information', 'hidden' => 1, class => '_ht'},
       { key => 'biotype',    sort => 'html',    label => 'Biotype', title => encode_entities('<a href="/info/genome/genebuild/biotypes.html" target="_blank">Transcript biotype</a>'), align => 'left', class => '_ht'},
  );
  push @columns, { key => 'ccds', sort => 'html', label => 'CCDS', class => '_ht' } if $has_ccds;

  return @columns;
}

sub colour_biotype {
  my ($self, $text, $transcript, $title) = @_;

  $title ||= get_glossary_entry($self->hub, $text);

  my $colours = $self->hub->species_defs->colour('gene');
  my $key     = $transcript->biotype;
     $key     = 'merged' if $transcript->analysis->logic_name =~ /ensembl_havana/;
  my $colour  = ($colours->{lc($key)} || {})->{'default'};
  my $hex     = $self->hub->colourmap->hex_by_name($colour);

  return coltab($text, $hex, $title);
}

sub get_extra_links {
  my ($self, $sub_type) = @_; 
  my $hub  = $self->hub;

  my $extra_links = {
    uniprot => { 
      first_match => "Uniprot_isoform", 
      second_match => "^UniProt/[SWISSPROT|SPTREMBL]", 
      name => "UniProt Match", 
      order => 0,
      title => get_glossary_entry($hub, 'UniProt Match')
    },
  };

  if ($hub->species eq 'Homo_sapiens' && $sub_type eq 'GRCh37' ) {
    $extra_links->{refseq} = { first_match => "^RefSeq", name => "RefSeq", order => 1, title => "RefSeq transcripts with sequence similarity and genomic overlap"};
  }

  return $extra_links;
}

sub get_CDS_text {
  my $self = shift;
  my $attribs = shift;
  my $trans_5_3_desc  = "5' and 3' truncations in transcript evidence prevent annotation of the start and the end of the CDS.";
  my $trans_5_desc    = "5' truncation in transcript evidence prevents annotation of the start of the CDS.";
  my $trans_3_desc    = "3' truncation in transcript evidence prevents annotation of the end of the CDS.";
  if ($attribs->{'CDS_start_NF'}) {
    if ($attribs->{'CDS_end_NF'}) {
      return helptip("CDS 5' and 3' incomplete", $trans_5_3_desc);
    }
    else {
      return helptip("CDS 5' incomplete", $trans_5_desc);
    }
  }
  elsif ($attribs->{'CDS_end_NF'}) {
    return helptip("CDS 3' incomplete", $trans_3_desc);
  }
  else {
    return undef;
  }
}

# since counts form left nav is gone, we are adding it in the description  (called in transcript_table function)
sub about_feature {
  my ($self) = @_;  
  
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $avail       = $object->availability;
  my $gene        = $object->gene;
  
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  
  my (@str_array, $counts_summary);
  
  if ($page_type eq 'gene') {
    my $ortholog_url = $hub->url({
      type   => 'Gene',
      action => 'Compara_Ortholog',
      g      => $gene->stable_id
    });
    
    my $paralog_url = $hub->url({
      type   => 'Gene',
      action => 'Compara_Paralog',
      g      => $gene->stable_id
    });
    
    my $protein_url = $hub->url({
      type   => 'Gene',
      action => $SiteDefs::GENE_FAMILY_ACTION,
      g      => $gene->stable_id
    });

    my $phenotype_url = $hub->url({
      type   => 'Gene',
      action => 'Phenotype',
      g      => $gene->stable_id
    });    

    my $splice_url = $hub->url({
      type   => 'Gene',
      action => 'Splice',
      g      => $gene->stable_id
    });        
    
    push @str_array, sprintf('%s %s', 
                        $avail->{has_transcripts}, 
                        $avail->{has_transcripts} eq "1" ? "transcript (<a href='$splice_url' class='dynamic-link'>splice variant</a>)" : "transcripts (<a class='dynamic-link' href='$splice_url'>splice variants)</a>"
                    ) if($avail->{has_transcripts});
    push @str_array, sprintf('%s gene %s', 
                        $avail->{has_alt_alleles}, 
                        $avail->{has_alt_alleles} eq "1" ? "allele" : "alleles"
                    ) if($avail->{has_alt_alleles});
    push @str_array, sprintf('<a class="dynamic-link" href="%s">%s %s</a>', 
                        $ortholog_url, 
                        $avail->{has_orthologs}, 
                        $avail->{has_orthologs} eq "1" ? "orthologue" : "orthologues"
                    ) if($avail->{has_orthologs});
    push @str_array, sprintf('<a class="dynamic-link" href="%s">%s %s</a>',
                        $paralog_url, 
                        $avail->{has_paralogs}, 
                        $avail->{has_paralogs} eq "1" ? "paralogue" : "paralogues"
                    ) if($avail->{has_paralogs});    
    push @str_array, sprintf('is a member of <a class="dynamic-link" href="%s">%s Ensembl protein %s</a>', $protein_url, 
                        $avail->{family_count}, 
                        $avail->{family_count} eq "1" ? "family" : "families"
                    ) if($avail->{family_count});
    push @str_array, sprintf('is associated with <a class="dynamic-link" href="%s">%s %s</a>', 
                        $phenotype_url, 
                        $avail->{has_phenotypes}, 
                        $avail->{has_phenotypes} eq "1" ? "phenotype" : "phenotypes"
                    ) if($avail->{has_phenotypes});
   
    $counts_summary  = sprintf('This gene has %s.',$self->join_with_and(@str_array));  
  }
  
  if ($page_type eq 'transcript') {
    my $exon_url = $hub->url({
      type   => 'Transcript',
      action => 'Exons',
      g      => $gene->stable_id
    }); 
    
    my $similarity_url = $hub->url({
      type   => 'Transcript',
      action => 'Similarity',
      g      => $gene->stable_id
    }); 
    
    my $oligo_url = $hub->url({
      type   => 'Transcript',
      action => 'Oligos',
      g      => $gene->stable_id
    });     

    my $domain_url = $hub->url({
      type   => 'Transcript',
      action => 'Domains',
      g      => $gene->stable_id
    });
    
    my $variation_url = $hub->url({
      type   => 'Transcript',
      action => 'Variation_Transcript/Table',
      g      => $gene->stable_id
    });     
   
    push @str_array, sprintf('<a class="dynamic-link" href="%s">%s %s</a>', 
                        $exon_url, $avail->{has_exons}, 
                        $avail->{has_exons} eq "1" ? "exon" : "exons"
                      ) if($avail->{has_exons});
                      
    push @str_array, sprintf('is annotated with <a class="dynamic-link" href="%s">%s %s</a>', 
                        $domain_url, $avail->{has_domains}, 
                        $avail->{has_domains} eq "1" ? "domain and feature" : "domains and features"
                      ) if($avail->{has_domains});

    push @str_array, sprintf('is associated with <a class="dynamic-link"href="%s">%s variant %s</a>',
                        $variation_url, 
                        $avail->{has_variations}, 
                        $avail->{has_variations} eq "1" ? "allele" : "alleles",
                      ) if($avail->{has_variations});    
    
    push @str_array, sprintf('maps to <a class="dynamic-link" href="%s">%s oligo %s</a>',    
                        $oligo_url,
                        $avail->{has_oligos}, 
                        $avail->{has_oligos} eq "1" ? "probe" : "probes"
                      ) if($avail->{has_oligos});
                
    $counts_summary  = sprintf('<p>This transcript has %s.</p>', $self->join_with_and(@str_array));
  }
  
  return $counts_summary;
}

sub get_gene_display_link {
  ## @param Gene object
  ## @param Gene xref object or description string
  my ($self, $gene, $xref) = @_;

  my $hub = $self->hub;

  if ($xref && !ref $xref) { # description string
    my $details = { map { split ':', $_, 2 } split ';', $xref =~ s/^.+\[|\]$//gr };
    $xref = first { $_->primary_id eq $details->{'Acc'} && $_->db_display_name eq $details->{'Source'} } @{$gene->get_all_DBLinks};
  }

  return unless $xref && $xref->info_type ne 'PROJECTION';

  my $url = $hub->get_ExtURL($xref->dbname, $xref->primary_id);

  return $url ? ($url, $xref->primary_id) : ();
}

sub get_synonyms {
  my ($self, $match_id, @matches) = @_;
  my $ids;
  foreach my $m (@matches) {
    my $dbname = $m->db_display_name;
    my $disp_id = $m->display_id;
    if ( $disp_id eq $match_id) {
      my $synonyms = $m->get_all_synonyms;
      foreach my $syn (@$synonyms) {
        if (ref $syn eq 'ARRAY') {
          $ids->{@$syn}++;
        }
        else {
          $ids->{$syn}++;
        }
      }
    }
  }
  return $ids;
}
  
1;
