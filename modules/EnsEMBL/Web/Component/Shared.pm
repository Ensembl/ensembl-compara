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

package EnsEMBL::Web::Component::Shared;

### Parent module for page components that share methods across object types 
### e.g. a table of transcripts that needs to appear on both Gene and Transcript pages

use strict;

use HTML::Entities  qw(encode_entities);
use Text::Wrap      qw(wrap);
use List::Util      qw(first);
use List::MoreUtils qw(uniq first_index);

use EnsEMBL::Web::Utils::FormatText qw(helptip glossary_helptip get_glossary_entry pluralise);

use parent qw(EnsEMBL::Web::Component);

sub coltab {
  my ($self, $text, $colour, $title) = @_;

  return sprintf(qq(<div class="coltab"><span class="coltab-tab" style="background-color:%s;">&nbsp;</span><div class="coltab-text">%s</div></div>), $colour, helptip($text, $title));
}

sub colour_biotype {
  my ($self, $text, $transcript, $title) = @_;

  $title ||= get_glossary_entry($self->hub, $text);

  my $colours = $self->hub->species_defs->colour('gene');
  my $key     = $transcript->biotype;
     $key     = 'merged' if $transcript->analysis->logic_name =~ /ensembl_havana/;
  my $colour  = ($colours->{lc($key)} || {})->{'default'};
  my $hex     = $self->hub->colourmap->hex_by_name($colour);

  return $self->coltab($text, $hex, $title);
}

sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;  
  my $species     = $hub->species;
  my $sub_type    = $hub->species_defs->ENSEMBL_SUBTYPE;
  my $table       = $self->new_twocol;
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  my $description = $object->gene_description;
     $description = '' if $description eq 'No description';
  my $show        = $hub->get_cookie_value('toggle_transcripts_table') eq 'open';
  my $button      = sprintf('<a rel="transcripts_table" class="button toggle no_img _slide_toggle set_cookie %s" href="#" title="Click to toggle the transcript table">
    <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
    </a>',
    $show ? 'open' : 'closed'
  );

  if ($description) {

    my ($url, $xref) = $self->get_gene_display_link($object->gene, $description);

    if ($xref) {
      $xref        = $xref->primary_id;
      $description =~ s|$xref|<a href="$url" class="constant">$xref</a>|;
    }

    $table->add_row('Description', $description);
  }

  my $location    = sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;

  my (@syn_matches, $syns_html, $about_count, @proj_attrib);
  push @syn_matches,@{$object->get_database_matches()};

  my $gene = $page_type eq 'gene' ? $object->Obj : $object->gene;

  $self->add_phenotype_link($gene, $table); #function in mobile plugin

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
    $table->add_row('Gene Synonyms', $syns_html);
  }

  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;

  my $location_html = sprintf(
    '<a href="%s" class="constant mobile-nolink dynamic-link">%s: %s-%s</a> %s.',
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

  my $insdc_accession = $self->object->insdc_accession if $self->object->can('insdc_accession');
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
          <li><a href="/%s/Location/View?l=%s:%s-%s" class="constant mobile-nolink">%s : %s-%s</a></li>', 
          $species, $altchr, $altstart, $altend, $altchr,
          $self->thousandify($altstart),
          $self->thousandify($altend)
        );
      }
      
      $location_html .= '
        </ul>';
    }
  }

  my $gene = $object->gene;

  #text for tooltips
  my $gencode_desc    = qq(The GENCODE set is the gene set for human and mouse. <a href="/Help/Glossary?id=500" class="popup">GENCODE Basic</a> is a subset of representative transcripts (splice variants).);
  my $gene_html       = '';
  my $transc_table;

  if ($gene) {
    my $version     = $object->version ? ".".$object->version : "";
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural      = 'transcripts';
    my $splices     = 'splice variants';
    my $action      = $hub->action;
    @proj_attrib    = @{ $gene->get_all_Attributes('proj_parent_g') };
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
    
    if ($count == 1) { 
      $plural =~ s/s$//;
      $splices =~ s/s$//;
    }   
    
    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_version = $gene->version ? $gene_id.'.'.$gene->version : $gene_id;
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
      $gene_html .= sprintf('<p>This transcript is a product of gene <a href="%s">%s</a> %s',
        $gene_url,
        $gene_version,
        $button
      );
    }

    ## Link to other haplotype genes
    my $alt_link = $object->get_alt_allele_link;
    if ($alt_link) {
      if ($page_type eq 'gene') {
        $location_html .= "<p>$alt_link</p>";
      }
    }   

    my @columns = (
       { key => 'transcript', sort => 'html',    label => 'Transcript ID', title => 'Stable ID', class => '_ht'},
       { key => 'name',       sort => 'string',  label => 'Name', title => 'Transcript name', class => '_ht'},
       { key => 'bp_length',  sort => 'numeric', label => 'bp', title => 'Transcript length in base pairs', class => '_ht'},
       { key => 'protein',sort => 'html_numeric',label => 'Protein', title => 'Protein length in amino acids', class => '_ht'},
       { key => 'translation',sort => 'html',    label => 'Translation ID', title => 'Protein information', 'hidden' => 1, class => '_ht'},
       { key => 'biotype',    sort => 'html',    label => 'Biotype', title => encode_entities('<a href="/info/genome/genebuild/biotypes.html" target="_blank">Transcript biotype</a>'), align => 'left', class => '_ht'},
    );

    push @columns, { key => 'ccds', sort => 'html', label => 'CCDS', class => '_ht' } if $species =~ /^Homo_sapiens|Mus_musculus/;
    my @rows;

    my %extra_links = (
      uniprot => { 
        first_match => "Uniprot_isoform", 
        second_match => "^UniProt/[SWISSPROT|SPTREMBL]", 
        name => "UniProt Match", 
        order => 0,
        title => get_glossary_entry($hub, 'UniProt Match')
      },
    );

    if ($species eq 'Homo_sapiens' && $sub_type eq 'GRCh37' ) {
      $extra_links{refseq} = { first_match => "^RefSeq", name => "RefSeq", order => 1, title => "RefSeq transcripts with sequence similarity and genomic overlap"};
    }

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

      my $dblinks = $_->get_all_DBLinks;
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @$dblinks) { 
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }

      foreach my $k (keys %extra_links) {
        
        my @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'first_match'}/i } @$dblinks;

        if(!@links && $extra_links{$k}->{'second_match'}){
          @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'second_match'}/i } @$dblinks;
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
    if ($species eq 'Homo_sapiens' && $sub_type ne 'GRCh37') {
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
    
    @columns = $self->table_removecolumn(@columns); # implemented in mobile plugin
    
    $transc_table = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { bPaginate => 'false', asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width' . ($show ? '' : ' hide'),
      id                => 'transcripts_table',
      exportable        => 1
    });
  
    if($page_type eq 'gene') {        
      $gene_html      .= $button;
    } 
    
    $about_count = $self->about_feature; # getting about this gene or transcript feature counts
    
  }

  $table->add_row('Location', $location_html);

  if(@proj_attrib && $hub->is_strain) {
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
        $table->add_row("Reference $strain_type equivalent", qq{<a href="$ref_url">$ref_gene_name</a>});
      }
      else {
        $table->add_row("Reference $strain_type equivalent","None");
      }  
    } else {
      $table->add_row("Reference $strain_type equivalent","None");
    }

  }
  $table->add_row( $page_type eq 'gene' ? 'About this gene' : 'About this transcript',$about_count) if $about_count;
  $table->add_row($page_type eq 'gene' ? 'Transcripts' : 'Gene', $gene_html) if $gene_html;

  return sprintf '<div class="summary_panel">%s%s</div>', $table->render, $transc_table ? $transc_table->render : '';
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

# return the same columns; implemented in mobile plugin to remove some columns
sub table_removecolumn { 
  my ($self, @columns) = @_;
  
  return @columns;
}

#implemented in mobile plugin (having this as  a separate function so that we dont have to overwrite transcript_table function in the plugin)
sub add_phenotype_link {
  return "";
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

  return $url ? ($url, $xref) : ();
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
  
sub _add_gene_counts {
  my ($self,$genome_container,$sd,$cols,$options,$tail,$our_type) = @_;

  my @order           = qw(coding_cnt noncoding_cnt noncoding_cnt/s noncoding_cnt/l noncoding_cnt/m pseudogene_cnt transcript);
  my @suffixes        = (['','~'], ['r',' (incl ~ '.glossary_helptip($self->hub, 'readthrough', 'Readthrough').')']);
  my $glossary_lookup = {
    'coding_cnt'        => 'Protein coding',
    'noncoding_cnt/s'   => 'Small non coding gene',
    'noncoding_cnt/l'   => 'Long non coding gene',
    'pseudogene_cnt'    => 'Pseudogene',
    'transcript'        => 'Transcript',
  };

  my @data;
  foreach my $statistic (@{$genome_container->fetch_all_statistics()}) {
    my ($name,$inner,$type) = ($statistic->statistic,'','');
    if($name =~ s/^(.*?)_(r?)(a?)cnt(_(.*))?$/$1_cnt/) {
      ($inner,$type) = ($2,$3);
      $name .= "/$5" if $5;
    }

    # Check if current statistic is alt_transcript and our_type is a (alternative sequence).
    # If yes, make type to be a so that the loop won't go to next early.
    # Also, push alt_transcript to order so that the statistic will be included in the table.
    if ($name eq 'alt_transcript' && $our_type eq 'a') {
      $type = 'a';
      push @order, 'alt_transcript';
    }

    next unless $type eq $our_type;
    my $i = first_index { $name eq $_ } @order;
    next if $i == -1;
    ($data[$i]||={})->{$inner} = $self->thousandify($statistic->value);
    $data[$i]->{'_key'} = $name;
    $data[$i]->{'_name'} = $statistic->name if $inner eq '';
    $data[$i]->{'_sub'} = ($name =~ m!/!);
  }

  my $counts = $self->new_table($cols, [], $options);
  foreach my $d (@data) {
    my $value = '';
    foreach my $s (@suffixes) {
      next unless $d->{$s->[0]};
      $value .= $s->[1];
      $value =~ s/~/$d->{$s->[0]}/g;
    }
    next unless $value;
    my $class = '';
    $class = 'row-sub' if $d->{'_sub'};
    my $key = $d->{'_name'};
    $key = glossary_helptip($self->hub, "<b>$d->{'_name'}</b>", $glossary_lookup->{$d->{'_key'}});
    $counts->add_row({ name => $key, stat => $value, options => { class => $class }});
  } 
  return "<h3>Gene counts$tail</h3>".$counts->render;
}
  
sub species_stats {
  my $self = shift;
  my $sd = $self->hub->species_defs;
  my $html;
  my $db_adaptor = $self->hub->database('core');
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $genome_container = $db_adaptor->get_GenomeContainer();
  my $no_stats = $genome_container->is_empty;


  $html = '<h3>Summary</h3>';

  my $cols = [
    { key => 'name', title => '', width => '30%', align => 'left' },
    { key => 'stat', title => '', width => '70%', align => 'left' },
  ];
  my $options = {'header' => 'no', 'rows' => ['bg3', 'bg1']};

  ## SUMMARY STATS
  my $summary = $self->new_table($cols, [], $options);

  my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
  if ($a_id) {
    # look for long name and accession num
    if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
      $a_id .= " ($long)";
    }
    if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
      $acc = sprintf('INSDC Assembly <a href="//www.ebi.ac.uk/ena/data/view/%s" rel="external">%s</a>', $acc, $acc);
      $a_id .= ", $acc";
    }
  }
  $summary->add_row({
      'name' => '<b>Assembly</b>',
      'stat' => $a_id.', '.$sd->ASSEMBLY_DATE
  });
  $summary->add_row({
      'name' => '<b>Base Pairs</b>',
      'stat' => $self->thousandify($genome_container->get_ref_length()),
  }) unless $no_stats;
  my $header = glossary_helptip($self->hub, 'Golden Path Length', 'Golden path length');
  $summary->add_row({
      'name' => "<b>$header</b>",
      'stat' => $self->thousandify($genome_container->get_ref_length())
  }) unless $no_stats;

  my @sources = qw(assembly annotation);
  foreach my $source (@sources) {
    my $meta_key = uc($source).'_PROVIDER_NAME';
    my $prov_name = $sd->$meta_key;
    if ($prov_name) {
      my $i = 0;
      my @prov_names  = ref $prov_name eq 'ARRAY' ? @$prov_name : ($prov_name);
      my $url_key     = uc($source).'_PROVIDER_URL';
      my $prov_url    = $sd->$url_key;
      my @prov_urls   = ref $prov_url eq 'ARRAY' ? @$prov_url : ($prov_url);
      my @providers;
      foreach my $provider (@prov_names) {
        $provider =~ s/_/ /g;
        my $prov_url = $prov_urls[$i] || $prov_urls[0];
        if ($prov_url && $provider ne 'Ensembl') {
          $prov_url = 'http://'.$prov_url unless $prov_url =~ /^http/;
          $provider = sprintf('<a href="%s">%s</a>', $prov_url, $provider);
        }
        push @providers, $provider;
        $i++;
      }
      $summary->add_row({
        'name' => sprintf('<b>%s provider</b>', ucfirst($source)),
        'stat' => join(', ', @providers), 
      });
    }
  }

  my @A         = @{$meta_container->list_value_by_key('genebuild.method')};
  my $method  = ucfirst($A[0]) || '';
  $method     =~ s/_/ /g;
  $summary->add_row({
      'name' => '<b>Annotation method</b>',
      'stat' => $method
  });
  $summary->add_row({
      'name' => '<b>Genebuild started</b>',
      'stat' => $sd->GENEBUILD_START
  });
  $summary->add_row({
      'name' => '<b>Genebuild released</b>',
      'stat' => $sd->GENEBUILD_RELEASE
  });
  $summary->add_row({
      'name' => '<b>Genebuild last updated/patched</b>',
      'stat' => $sd->GENEBUILD_LATEST
  });
  $summary->add_row({
      'name' => '<b>Database version</b>',
      'stat' => $sd->ENSEMBL_VERSION.'.'.$sd->SPECIES_RELEASE_VERSION
  });
  my $gencode = $sd->GENCODE_VERSION;
  if ($gencode) {
    $summary->add_row({
      'name' => '<b>Gencode version</b>',
      'stat' => $gencode,
    });
  }

  $html .= $summary->render;

  ## GENE COUNTS
  unless ($no_stats) {
    my $has_alt = $genome_container->get_alt_coding_count();
    if($has_alt) {
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,' (Primary assembly)','');
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,' (Alternative sequence)','a');
    } else {
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,'','');
    }

    ## OTHER STATS
    my $rows = [];
    ## Prediction transcripts
    my $analysis_adaptor = $db_adaptor->get_AnalysisAdaptor();
    my $attribute_adaptor = $db_adaptor->get_AttributeAdaptor();
    my @analyses = @{ $analysis_adaptor->fetch_all_by_feature_class('PredictionTranscript') };
    foreach my $analysis (@analyses) {
      my $logic_name = $analysis->logic_name;
      my $stat = $genome_container->fetch_by_statistic(
                                      'PredictionTranscript',$logic_name); 
      push @$rows, {
        'name' => "<b>".$stat->name."</b>",
        'stat' => $self->thousandify($stat->value),
      } if $stat and $stat->name;
    }
    ## Variants
    if ($self->hub->database('variation')) {
      my @other_stats = qw(SNPCount StructuralVariation);
      foreach my $name (@other_stats) {
        my $stat = $genome_container->fetch_by_statistic($name);
        push @$rows, {
          'name' => '<b>'.$stat->name.'</b>',
          'stat' => $self->thousandify($stat->value)
        } if $stat and $stat->name;
      }
    }

    if (scalar(@$rows)) {
      $html .= '<h3>Other</h3>';
      my $other = $self->new_table($cols, $rows, $options);
      $html .= $other->render;
    }
  }

  return $html;
}

########### COMPARA #################################

sub content_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_text_pan_compara {
  my $self = shift;
  return $self->content_text('compara_pan_ensembl');
}

sub content_align_pan_compara {
  my $self = shift;
  return $self->content_align('compara_pan_ensembl');
}

sub content_alignment_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_ensembl_pan_compara {
  my $self = shift;
  return $self->content_ensembl('compara_pan_ensembl');
}

sub content_other_pan_compara {
  my $self = shift;
  return $self->content_other('compara_pan_ensembl');
}

sub check_for_align_problems {
  ## Compile possible error messages for a given alignment
  ## @return HTML
  my ($self, $args) = @_;
  my $object = $self->object || $self->hub->core_object(lc($self->hub->param('data_type')));

  my @messages = $object->check_for_align_in_database($args->{align}, $args->{species}, $args->{cdb});

  if (scalar @messages <= 0) {
    push @messages, $self->check_for_missing_species($args);
  }

  return $self->show_warnings(\@messages);
}

sub check_for_missing_species {
  ## Check what species are not present in the alignment
  my ($self, $args) = @_;

  my (@skipped, @missing, $title, $warnings, %aligned_species, $missing_hash);

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $species       = $args->{species};
  my $align         = $args->{align};
  my $db_key        = $args->{cdb} =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
  my $align_details = $species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};
  my $species_info  = $hub->get_species_info;
  my $url_lookup    = $species_defs->prodnames_to_urls_lookup;
  my $slice         = $args->{slice} || $self->object->slice;
  $slice = undef if $slice == 1; # weirdly, we get 1 if feature_Slice is missing

  if(defined $slice) {
    $args->{slice}   = $slice;
    my ($slices)     = $self->object->get_slices($args);
    %aligned_species = map { $_->{'name'} => 1 } @$slices;
  }

  foreach (keys %{$align_details->{'species'}}) {
    next if $_ eq $species;
    my $sp_url = $url_lookup->{$_};
    if ($align_details->{'class'} !~ /pairwise/
        && ($self->param(sprintf 'species_%d_%s', $align, lc) || 'off') eq 'off') {
      push @skipped, $sp_url unless ($args->{ignore} && $args->{ignore} eq 'ancestral_sequences');
    }
    elsif (defined $slice and !$aligned_species{$_} and $_ ne 'ancestral_sequences') {
      my $key = $hub->is_strain($sp_url) ? pluralise($species_info->{$sp_url}{strain_type}) : 'species';
      push @{$missing_hash->{$key}}, $species_info->{$sp_url}{common};
      push @missing, $sp_url;
    }
  }

  if (scalar @skipped) {
    $title = 'hidden';
    $warnings .= sprintf(
                             '<p>The following %d species in the alignment are not shown. Use "<strong>Select another alignment</strong>" button (above the image) to turn alignments on/off.<ul><li>%s</li></ul></p>',
                             scalar @skipped,
                             join "</li>\n<li>", sort map $species_defs->species_label($_), @skipped
                            );
  }

  if (scalar @skipped && scalar @missing) {
    $title .= ' and ';
  }

  my $not_missing = scalar(keys %{$align_details->{'species'}}) - scalar(@missing);
  my $ancestral = grep {$_ =~ /ancestral/} keys %{$align_details->{'species'}};
  my $multi_check = $ancestral ? 2 : 1;
  if (scalar @missing) {
    $title .= ' missing species';
    if ($align_details->{'class'} =~ /pairwise/) {
      $warnings .= sprintf '<p>%s has no alignment in this region</p>', $species_defs->species_label($missing[0]);
    } elsif ($not_missing == $multi_check) {
      $warnings .= sprintf('<p>None of the other species in this set align to %s in this region</p>', $species_defs->SPECIES_DISPLAY_NAME);
    } else {
      my $str = '';
      my $count = 0;

      if ($missing_hash->{strains}) {
        $count = scalar @{$missing_hash->{strains}};
        my $strain_type = $hub->species_defs->STRAIN_TYPE || 'strain';
        $strain_type = pluralise($strain_type) if $count > 1;
        $str .= "$count $strain_type";
      }

      $str .= ' and ' if ($missing_hash->{strains} && $missing_hash->{species});
      
      if ($missing_hash->{species}) {
        my $sp_count = @{$missing_hash->{species}};
        $str .= "$sp_count species";
        $count += $sp_count;
      }

      $str .= $count > 1 ? ' have' : ' has';

      $warnings .= sprintf('<p>The following %s no alignment in this region:<ul><li>%s</li></ul></p>',
                                 $str,
                                 join "</li>\n<li>", sort map $species_defs->species_label($_), @missing
                            );
    }
  }
  return $warnings ? ({'severity' => 'info', 'title' => $title, 'message' => $warnings}) : ();
}

sub show_warnings {
  my ($self, $messages) = @_;
  return '' unless defined $messages;

  my $html;
  my $is_error;
  foreach (@$messages) {
    $html .= $self->_info_panel($_->{severity}, ucfirst $_->{title}, $_->{message});
    $is_error = 1 if $_->{severity} eq 'error';
  }
  return ($html, $is_error);
}

sub _matches { ## TODO - tidy this
  my ($self, $key, $caption, @keys) = @_;
  my $output_as_twocol  = $keys[-1] eq 'RenderAsTwoCol';
  my $output_as_table   = $keys[-1] eq 'RenderAsTables';
  my $show_version      = $keys[-1] eq 'show_version' ? 'show_version' : '';

  pop @keys if ($output_as_twocol || $output_as_table || $show_version) ; # if output_as_table or show_version or output_as_twocol then the last value isn't meaningful

  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;
  my $label        = $species_defs->translate($caption);
  my $obj          = $object->Obj;

  # Check cache
  if (!$object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    return unless @similarity_links;
    $self->_sort_similarity_links($output_as_table, $show_version, $keys[0], @similarity_links );
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;
  @links = $self->remove_redundant_xrefs(@links) if $keys[0] eq 'ALT_TRANS';
  return unless @links;

  my $db    = $object->get_db;
  my $entry = lc(ref $obj);
  $entry =~ s/bio::ensembl:://;

  my @rows;
  my $html = $species_defs->ENSEMBL_SITETYPE eq 'Vega' ? '' : "<p><strong>This $entry corresponds to the following database identifiers:</strong></p>";

  # in order to preserve the order, we use @links for acces to keys
  while (scalar @links) {
    my $key = $links[0][0];
    my $j   = 0;
    my $text;

    # display all other vales for the same key
    while ($j < scalar @links) {
      my ($other_key , $other_text) = @{$links[$j]};
      if ($key eq $other_key) {
        $text      .= $other_text;
        splice @links, $j, 1;
      } else {
        $j++;
      }
    }

    push @rows, { dbtype => $key, dbid => $text };
  }

  my $table;
  @rows = sort { $a->{'dbtype'} cmp $b->{'dbtype'} } @rows;

  if ($output_as_twocol) {
    $table = $self->new_twocol;
    $table->add_row("$_->{'dbtype'}:", " $_->{'dbid'}") for @rows;    
  } elsif ($output_as_table) { # if flag is on, display datatable, otherwise a simple table
    $table = $self->new_table([
        { key => 'dbtype', align => 'left', title => 'External database' },
        { key => 'dbid',   align => 'left', title => 'Database identifier' }
      ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 }
    );
  } else {
    $table = $self->dom->create_element('table', {'cellspacing' => '0', 'children' => [
      map {'node_name' => 'tr', 'children' => [
        {'node_name' => 'th', 'inner_HTML' => "$_->{'dbtype'}:"},
        {'node_name' => 'td', 'inner_HTML' => " $_->{'dbid'}"  }
      ]}, @rows
    ]});
  }

  return $html.$table->render;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $output_as_table  = shift || 0;
  my $show_version     = shift || 0;
  my $xref_type        = shift || '';
  my @similarity_links = @_;

  my $hub              = $self->hub;
  my $object           = $self->object;
  my $database         = $hub->database;
  my $db               = $object->get_db;
  my $urls             = $hub->ExtURL;
  my $fv_type          = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
  my (%affy, %exdb);

  # Get the list of the mapped ontologies 
  my @mapped_ontologies = @{$hub->species_defs->SPECIES_ONTOLOGIES || ['GO']};
  my $ontologies = join '|', @mapped_ontologies, 'goslim_goa';

  foreach my $type (sort {
    $b->priority        <=> $a->priority        ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links) {
    my $link       = '';
    my $join_links = 0;
    my $externalDB = $type->database;
    my $display_id = $type->display_id;
    my $primary_id = $type->primary_id;

    # hack for LRG
    $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';

    next if $type->status eq 'ORTH';                            # remove all orthologs
    next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
    next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
    next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
    next if $externalDB eq 'Vega_transcript';
    next if $externalDB eq 'Vega_translation';
    next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs
    next if $externalDB eq 'shares_CDS_with_ENST';
    next if $externalDB =~ /^Uniprot_/;

    if ($externalDB =~ /^($ontologies)$/) {
      push @{$object->__data->{'links'}{'go'}}, $display_id;
      next;
    } elsif ($externalDB eq 'GKB') {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}}, $type;
      next;
    }

    my $text = $display_id;

    (my $A = $externalDB) =~ s/_predicted//;

    if ($urls && $urls->is_linked($A)) {
      $type->{ID} = $primary_id;
      $link = $urls->get_url($A, $type);
      my $word = $display_id;
      $word .= " ($primary_id)" if $A eq 'MARKERSYMBOL';

      if ($link) {
        $text = qq{<a href="$link" class="constant">$word</a>};
      } else {
        $text = $word;
      }
    }
    if ($type->isa('Bio::EnsEMBL::IdentityXref')) {
      $text .= ' <span class="small"> [Target %id: ' . $type->ensembl_identity . '; Query %id: ' . $type->xref_identity . ']</span>';
      $join_links = 1;
    }

    if ($hub->species_defs->ENSEMBL_PFETCH_SERVER && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i && ref($object->Obj) eq 'Bio::EnsEMBL::Transcript' && $externalDB !~ /uniprot_genename/i) {
      my $seq_arg = $display_id;
      $seq_arg    = "LL_$seq_arg" if $externalDB eq 'LocusLink';

      my $url = $self->hub->url({
        type     => 'Transcript',
        action   => 'Similarity/Align',
        sequence => $seq_arg,
        extdb    => lc $externalDB
      });

      $text .= qq{ [<a href="$url">align</a>] };
    }

    $text .= sprintf ' [<a href="%s">Search GO</a>]', $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;

    if ($show_version && $type->version) {
      my $version = $type->version;
      $text .= " (version $version)";
    }

    if ($type->description) {
      (my $D = $type->description) =~ s/^"(.*)"$/$1/;
      $text .= '<br />' . encode_entities($D);
      $join_links = 1;
    }

    if ($join_links) {
      $text = qq{\n <div>$text};
    } else {
      $text = qq{\n <div class="multicol">$text};
    }

    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if ($externalDB =~ /^AFFY_/i) {
      next if $affy{$display_id} && $exdb{$type->db_display_name}; # remove duplicates

      $text = qq{\n  <div class="multicol"> $display_id};
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    # add link to featureview
    ## FIXME - another LRG hack! 
    if ($externalDB eq 'ENS_LRG_gene') {
      my $lrg_url = $self->hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });

      $text .= qq{ [<a href="$lrg_url">view all locations</a>]};
    } else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type    : "${fv_type}_$externalDB";

      my $k_url = $self->hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
      $text .= qq{  [<a href="$k_url">view all locations</a>]} unless $xref_type =~ /^ALT/;
    }

    $text .= '</div>';

    my $label = $type->db_display_name || $externalDB;
    $label    = 'LRG' if $externalDB eq 'ENS_LRG_gene'; ## FIXME Yet another LRG hack!

    push @{$object->__data->{'links'}{$type->type}}, [ $label, $text ];
  }
}

sub remove_redundant_xrefs {
  my ($self, @links) = @_;
  my %priorities;

  # We can have multiple OTT/ENS xrefs but need to filter some out since there can be duplicates.
  # Therefore need to generate a data structure that has the stable ID as the key
  my %links;
  foreach (@links) {
    if ($_->[1] =~ /[t|g]=(\w+)/) {
      my $sid = $1;
      if ($sid =~ /[ENS|OTT]/) { 
        push @{$links{$sid}->{$_->[0]}}, $_->[1];
      }
    }
  }

  # There can be more than db_link type for each particular stable ID, need to order by priority
  my @priorities = ('Transcript having exact match between ENSEMBL and HAVANA',
                    'Ensembl transcript having exact match with Havana',
                    'Havana transcript having same CDS',
                    'Ensembl transcript sharing CDS with Havana',
                    'Havana transcript');

  my @new_links;
  foreach my $sid (keys %links) {
    my $wanted_link_type;
  PRIORITY:
    foreach my $link_type (@priorities) {
      foreach my $db_link_type ( keys %{$links{$sid}} ) {
        if ($db_link_type eq $link_type) {
          $wanted_link_type = $db_link_type;
          last PRIORITY;
        }
      }
    }

    return @links unless $wanted_link_type; #show something rather than nothing if we have unexpected (ie none in the above list) xref types

    #if there is only one link for a particular db_link type it's easy...
    if ( @{$links{$sid}->{$wanted_link_type}} == 1) {
      push @new_links, [ $wanted_link_type, @{$links{$sid}->{$wanted_link_type}} ];
    }
    else {
      #... otherwise differentiate between multiple xrefs of the same type if the version numbers are different
      my $max_version = 0;
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        if ( $link =~ /version (\d{1,2})/ ) {
          $max_version = $1 if $1 > $max_version;
        }
      }
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        next if ($max_version && ($link !~ /version $max_version/));
        push @new_links, [ $wanted_link_type, $link ];
      }
    }
  }
  return @new_links;
}

############ VARIATION ###################################

sub structural_variation_table {
  my ($self, $slice, $title, $table_id, $functions, $open) = @_;
  my $hub = $self->hub;
  my $svf_adaptor = $hub->database('variation')->get_StructuralVariationFeatureAdaptor;
  my $rows;
  
  my $columns = [
     { key => 'id',          sort => 'string',         title => 'Name'   },
     { key => 'location',    sort => 'position_html',  title => 'Chr:bp' },
     { key => 'size',        sort => 'numeric_hidden', title => 'Genomic size (bp)' },
     { key => 'class',       sort => 'string',         title => 'Class'  },
     { key => 'source',      sort => 'string',         title => 'Source Study' },
     { key => 'description', sort => 'string',         title => 'Study description', width => '50%' },
  ];
  
  my $svfs;
  foreach my $func (@{$functions}) {
    push(@$svfs, @{$svf_adaptor->$func($slice)});
  }

  if ( !$svfs || scalar(@{$svfs}) < 1 ) {
    my $my_title = lc($title);
    return "<p>No $my_title associated with this variant.</p>";
  }
  
  foreach my $svf (@{$svfs}) {
    my $name        = $svf->variation_name;
    my $description = $svf->source_description;
    my $sv_class    = $svf->var_class;
    my $source      = $svf->source->name;
    
    if ($svf->study) {
      my $ext_ref    = $svf->study->external_reference;
      my $study_name = $svf->study->name;
      my $study_url  = $svf->study->url;
      
      if ($study_name) {
        $source      .= ":$study_name";
        $source       = qq{<a rel="external" href="$study_url">$source</a>} if $study_url;
        $description .= ': ' . $svf->study->description;
      }
      
      if ($ext_ref =~ /pubmed\/(.+)/) {
        my $pubmed_id   = $1;
        my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
           $description =~ s/$pubmed_id/<a href="$pubmed_link" target="_blank">$pubmed_id<\/a>/g;
      }
    }
    
    # SV size (format the size with comma separations, e.g: 10000 to 10,000)
    my $sv_size = $svf->length;
       $sv_size ||= '-';
 
    my $hidden_size  = sprintf(qq{<span class="hidden">%s</span>},($sv_size eq '-') ? 0 : $sv_size);

    my $int_length = length $sv_size;
    
    if ($int_length > 3) {
      my $nb         = 0;
      my $int_string = '';
      
      while (length $sv_size > 3) {
        $sv_size    =~ /(\d{3})$/;
        $int_string = ",$int_string" if $int_string ne '';
        $int_string = "$1$int_string";
        $sv_size    = substr $sv_size, 0, (length($sv_size) - 3);
      }
      
      $sv_size = "$sv_size,$int_string";
    }  
      
    my $sv_link = $hub->url({
      type   => 'StructuralVariation',
      action => 'Explore',
      sv     => $name
    });      

    my $loc_string = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;
        
    my $loc_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $loc_string,
    });      
    
    my %row = (
      id          => qq{<a href="$sv_link">$name</a>},
      location    => qq{<a href="$loc_link">$loc_string</a>},
      size        => $hidden_size.$sv_size,
      class       => $sv_class,
      source      => $source,
      description => $description,
    );
    
    push @$rows, \%row;
  }
  
  return $self->toggleable_table($title, $table_id, $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ], data_table_config => {iDisplayLength => 25} }), $open);
}
  
sub render_score_prediction {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($self, $pred, $score) = @_;
  
  return '-' unless defined($pred) || defined($score);
  
  my %classes = (
    '-'                 => '',
    'likely deleterious' => 'bad',
    'likely benign' => 'good',
    'likely disease causing' => 'bad',
    'tolerated' => 'good',
    'damaging'   => 'bad',
    'high'    => 'bad',
    'medium'  => 'ok',
    'low'     => 'good',
    'neutral' => 'good',
  );
  
  my %ranks = (
    '-'                 => 0,
    'likely deleterious' => 4,
    'likely benign' => 2,
    'likely disease causing' => 4,
    'tolerated' => 2,
    'damaging'   => 4,
    'high'    => 4,
    'medium'  => 3,
    'low'     => 2,
    'neutral' => 2,
  );
  
  my ($rank, $rank_str);
  
  if(defined($score)) {
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }
  
  return qq(
    <span class="hidden">$rank</span><span class="hidden export">$pred(</span><div align="center"><div title="$pred" class="_ht score score_$classes{$pred}">$rank_str</div></div><span class="hidden export">)</span>
  );
}

sub render_sift_polyphen {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($self, $pred, $score) = @_;
  
  return '-' unless defined($pred) || defined($score);
  
  my %classes = (
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad',
    
    # slightly different format for SIFT low confidence states
    # depending on whether they come direct from the API
    # or via the VEP's no-whitespace processing
    'tolerated - low confidence'   => 'neutral',
    'deleterious - low confidence' => 'neutral',
    'tolerated low confidence'     => 'neutral',
    'deleterious low confidence'   => 'neutral',
  );
  
  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );
  
  my ($rank, $rank_str);
  
  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }
  
  return qq(
    <span class="hidden">$rank</span><span class="hidden export">$pred(</span><div align="center"><div title="$pred" class="_ht score score_$classes{$pred}">$rank_str</div></div><span class="hidden export">)</span>
  );
}

sub classify_sift_polyphen {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($self, $pred, $score) = @_;

  return [undef,'-','','-'] unless defined($pred) || defined($score);

  my %classes = %{$self->predictions_classes};

  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );

  my ($rank, $rank_str);

  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }

  # 0 -- a value to use for sorting
  # 1 -- a value to use for exporting
  # 2 -- a class to use for styling
  # 3 -- a value for display
  return [$rank,$pred,$rank_str];
}

sub classify_score_prediction {
  ## render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
  my ($self, $pred, $score) = @_;
  
  return [undef,'-','','-'] unless defined($pred) || defined($score);
  
  my %classes = %{$self->predictions_classes};
  
  my %ranks = (
    '-'                 => 0,
    'likely deleterious' => 4,
    'likely benign' => 2,
    'likely disease causing' => 4,
    'tolerated' => 2,
    'damaging'   => 4,
    'high'    => 4,
    'medium'  => 3,
    'low'     => 2,
    'neutral' => 2,
  );
  
  my ($rank, $rank_str);
  
  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = "$score";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = $pred;
  }
  return [$rank,$pred,$rank_str];
}

# Common list of variant protein prediction results with their corresponding CSS classes
sub predictions_classes {
  my $self = shift;

  my %classes = (
    '-'                 => '',
    'probably damaging' => 'bad',
    'possibly damaging' => 'ok',
    'benign'            => 'good',
    'unknown'           => 'neutral',
    'tolerated'         => 'good',
    'deleterious'       => 'bad',

    'likely deleterious'     => 'bad',
    'likely benign'          => 'good',
    'likely disease causing' => 'bad',
    'damaging'               => 'bad',
    'high'                   => 'bad',
    'medium'                 => 'ok',
    'low'                    => 'good',
    'neutral'                => 'neutral',

    # slightly different format for SIFT low confidence states
    # depending on whether they come direct from the API
    # or via the VEP's no-whitespace processing
    'tolerated - low confidence'   => 'neutral',
    'deleterious - low confidence' => 'neutral',
    'tolerated low confidence'     => 'neutral',
    'deleterious low confidence'   => 'neutral',
  );

  return \%classes;
}


sub render_consequence_type {
  my $self        = shift;
  my $tva         = shift;
  my $most_severe = shift;
  my $var_styles  = $self->hub->species_defs->colour('variation');
  my $colourmap   = $self->hub->colourmap;

  my $overlap_consequences = ($most_severe) ? [$tva->most_severe_OverlapConsequence] || [] : $tva->get_all_OverlapConsequences || [];

  # Sort by rank, with only one copy per consequence type
  my @consequences = sort {$a->rank <=> $b->rank} (values %{{map {$_->label => $_} @{$overlap_consequences}}});

  my $type = join ' ',
    map {
      my $hex = $var_styles->{lc $_->SO_term}
        ? $colourmap->hex_by_name(
            $var_styles->{lc $_->SO_term}->{'default'}
          )
        : $colourmap->hex_by_name($var_styles->{'default'}->{'default'});
      $self->coltab($_->label, $hex, $_->description);
    }
    @consequences;
  my $rank = @consequences ? $consequences[0]->rank : undef;
      
  return ($type) ? qq{<span class="hidden">$rank</span>$type} : '-';
}

sub render_evidence_status {
  my $self      = shift;
  my $evidences = shift;

  my $render;
  foreach my $evidence (sort {$b =~ /1000|hap/i <=> $a =~ /1000|hap/i || $a cmp $b} @$evidences){
    my $evidence_label = $evidence;
       $evidence_label =~ s/_/ /g;
    $render .= sprintf('<img src="%s/val/evidence_%s.png" class="_ht" title="%s"/><div class="hidden export">%s</div>',
                        $self->img_url, $evidence, $evidence_label, $evidence
                      );
  }
  return $render;
}

sub render_clinical_significance {
  my $self       = shift;
  my $clin_signs = shift;

  my $render;
  foreach my $cs (sort {$b =~ /pathogenic/i cmp $a =~ /pathogenic/i || $a cmp $b} @$clin_signs){
    my $cs_img = $cs;
       $cs_img =~ s/\s/-/g;
    $render .= sprintf('<img src="%s/val/clinsig_%s.png" class="_ht" title="%s"/><div class="hidden export">%s</div>',
                        $self->img_url, $cs_img, $cs, $cs
                      );
  }
  return $render;
}

sub render_p_value {
  my $self = shift;
  my $pval = shift;
  my $bold = shift;

  my $render = $pval;
  # Only display 2 decimals
  if ($pval =~ /^(\d\.\d+)e-0?(\d+)$/) {
    # Only display 2 decimals
    my $val = sprintf("%.2f", $1);
    # Superscript
    my $exp = "<sup>-$2</sup>";
    $exp = "<b>$exp</b>" if ($bold);

    $render = $val.'e'.$exp;
  }
  return $render;
}

# Rectangular glyph displaying the location and coverage of the variant
# on a given feature (transcript, protein, regulatory element, ...)
sub render_var_coverage {
  my $self = shift;
  my ($f_s, $f_e, $v_s, $v_e, $color) = @_;

  my $render;
  my $var_render;

  $color ||= 'red';

  my $total_width = 100;
  my $left_width  = 0;
  my $right_width = 0;
  my $small_var   = 0;

  my $scale = $total_width / ($f_e - $f_s + 1);

  # middle part
  if ($v_s <= $f_e && $v_e >= $f_s) {
    my $s = (sort {$a <=> $b} ($v_s, $f_s))[-1];
    my $e = (sort {$a <=> $b} ($v_e, $f_e))[0];

    my $bp = ($e - $s) + 1;

    $right_width = sprintf("%.0f", $bp * $scale);
    if (($right_width <= 2) || $left_width == $total_width) {
      $right_width = 3;
      $small_var   = 1;
    }
    $var_render = sprintf(qq{<div class="var_trans_pos_sub" style="width:%ipx;background-color:%s"></div>}, $right_width, $color);
  }

  # left part
  if($v_s > $f_s) {
    $left_width = sprintf("%.0f", ($v_s - $f_s) * $scale);
    if ($left_width == $total_width)  {
      $left_width -= $right_width;
    }
    elsif (($left_width + $right_width) > $total_width) {
      $left_width = $total_width - $right_width;
    }
    elsif ($small_var && $left_width > 0) {
      $left_width--;
    }
    $left_width = 0 if ($left_width < 0);
    $render .= '<div class="var_trans_pos_sub" style="width:'.$left_width.'px"></div>';
  }
  $render .= $var_render if ($var_render);

  if ($render) {
    $render = qq{<div class="var_trans_pos">$render</div>};
  }

  return $render;
}

sub button_portal {
  my ($self, $buttons, $class) = @_;
  $class ||= '';
  my $html;

  my $img_url = $self->img_url;

  foreach (@{$buttons || []}) {
    if ($_->{'url'}) {
      my $counts = qq(<span class="counts">$_->{'count'}</span>) if $_->{'count'};
      $html .= qq(<div><a href="$_->{'url'}" title="$_->{'title'}" class="_ht"><img src="$img_url$_->{'img'}" alt="$_->{'title'}" />$counts</a></div>);
    } else {
      $html .= qq|<div><img src="$img_url$_->{'img'}" class="_ht unavailable" alt="$_->{'title'} (Not available)" title="$_->{'title'} (Not available)" /></div>|;
    }
  }

  return qq{<div class="portal $class">$html</div><div class="invisible"></div>};
}

sub vep_icon {
  my ($self, $inner_html) = @_;
  my $hub         = $self->hub;
  return '' unless $hub->species_defs->ENSEMBL_VEP_ENABLED;

  $inner_html   ||= 'Test your own variants with the <span>Variant Effect Predictor</span>';
  my $vep_link    = $hub->url({'__clear' => 1, qw(type Tools action VEP)});

  return qq(<a class="vep-icon" href="$vep_link">$inner_html</a>);
}

sub display_items_list {
  my ($self, $div_id, $title, $label, $display_data, $export_data, $no_count_label, $specific_count) = @_;

  my $html = "";
  my @sorted_data = ($display_data->[0] =~ /^<a/i) ? @{$display_data} : sort { lc($a) cmp lc($b) } @{$display_data};
  my $count = scalar(@{$display_data});
  my $count_threshold = ($specific_count) ? $specific_count : 5;
  if ($count >= $count_threshold) {
    $html = sprintf(qq{
        <a title="Click to show the list of %s" rel="%s" href="#" class="toggle_link toggle closed _slide_toggle _no_export">%s</a>
        <div class="%s"><div class="toggleable" style="display:none"><span class="hidden export">%s</span><ul class="_no_export">%s</ul></div></div>
      },
      $title,
      $div_id,
      ($no_count_label) ? $label : "$count $label",
      $div_id,
      join(",", sort { lc($a) cmp lc($b) } @{$export_data}),
      '<li>'.join("</li><li>", @sorted_data).'</li>'
    );
  }
  else {
    $html = join(", ", @sorted_data);
  }

  return $html;
}

1;
