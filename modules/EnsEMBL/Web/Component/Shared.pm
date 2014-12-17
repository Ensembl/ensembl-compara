=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::Component);

use HTML::Entities  qw(encode_entities);
use Text::Wrap      qw(wrap);
use List::MoreUtils qw(uniq);

use EnsEMBL::Draw::DrawableContainer;
use EnsEMBL::Draw::VDrawableContainer;

use EnsEMBL::Web::Document::Image;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Document::TwoCol;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Form::ModalForm;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;

######### USED ON VARIOUS PAGES ###########

sub coltab {
  my ($self,$text,$colour,$title) = @_;

  $title ||= '';
  return sprintf(
    qq(
      <div class="coltab">
        <span class="colour coltab_tab" style="background-color:%s;">&nbsp;</span>
        <div class="_ht conhelp coltab_text" title="%s">%s</div>
      </div>),
    $colour,$title,$text
  );
}


########### GENES AND TRANSCRIPTS ###################

sub colour_biotype {
  my ($self,$html,$transcript,$title) = @_;

  my $colours       = $self->hub->species_defs->colour('gene');
  my $key = $transcript->biotype;
  $key = 'merged' if $transcript->analysis->logic_name =~ /ensembl_havana/;
  my $colour = ($colours->{lc($key)}||{})->{'default'};
  my $hex = $self->hub->colourmap->hex_by_name($colour);
  return $self->coltab($html,$hex,$title);
}

sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $species     = $hub->species;
  my $table       = $self->new_twocol;
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  my $description = $object->gene_description;
     $description = '' if $description eq 'No description';

  if ($description) {
    my ($edb, $acc);
    
    if ($object->get_db eq 'vega') {
      $edb = 'Vega';
      $acc = $object->Obj->stable_id;
      $description .= sprintf ' <span class="small">%s</span>', $hub->get_ExtURL_link("Source: $edb", $edb . '_' . lc $page_type, $acc);
    } else {
      $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
      $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:([\w\.]+)\]//g;
      ($edb, $acc) = ($1, $2);

      my $l1   =  $hub->get_ExtURL($edb, $acc);
      $l1      =~ s/\&amp\;/\&/g;
      my $t1   = "Source: $edb $acc";
      my $link = $l1 ? qq(<a href="$l1">$t1</a>) : $t1;

      $description .= qq( <span class="small">@{[ $link ]}</span>) if $acc && $acc ne 'content';
    }

    $table->add_row('Description', $description);
  }

  my $location    = $hub->param('r') || sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;

  my $site_type         = $hub->species_defs->ENSEMBL_SITETYPE; 
  my @SYNONYM_PATTERNS  = qw(%HGNC% %ZFIN%);
  my (@syn_matches, $syns_html);
  push @syn_matches,@{$object->get_database_matches($_)} for @SYNONYM_PATTERNS;

  my $gene = $page_type eq 'gene' ? $object->Obj : $object->gene;
  foreach (@{$object->get_similarity_hash(0, $gene)}) {
    next unless $_->{'type'} eq 'PRIMARY_DB_SYNONYM';
    my $id           = $_->display_id;
    my $synonym     = $self->get_synonyms($id, @syn_matches);
    next unless $synonym;
    $syns_html .= "<p>$synonym</p>";
  }

  $table->add_row('Synonyms', $syns_html) if $syns_html;

  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;

  my $location_html = sprintf(
    '<a href="%s" class="constant">%s: %s-%s</a> %s.',
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
 
  # alternative (Vega) coordinates
  if ($object->get_db eq 'vega') {
    my $alt_assemblies  = $hub->species_defs->ALTERNATIVE_ASSEMBLIES || [];
    my ($vega_assembly) = map { $_ =~ /VEGA/; $_ } @$alt_assemblies;
    
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;
    
    $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');

    my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external" class="constant">%s-%s</a>',
        $hub->ExtURL->get_url('VEGA_CONTIGVIEW', $l),
        $self->thousandify($alt_slices->[0]->start),
        $self->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $vega_assembly coordinates</span>]";
    } else {
      $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
    }
    
    $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
  }

  $location_html = "<p>$location_html</p>";

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
  my $gencode_desc = "The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).";
  my $trans_5_3_desc = "5' and 3' truncations in transcript evidence prevent annotation of the start and the end of the CDS.";
  my $trans_5_desc = "5' truncation in transcript evidence prevents annotation of the start of the CDS.";
  my $trans_3_desc = "3' truncation in transcript evidence prevents annotation of the end of the CDS.";
  my %glossary     = $hub->species_defs->multiX('ENSEMBL_GLOSSARY');
  my $gene_html    = '';
  my $transc_table;

  if ($gene) {
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural      = 'transcripts';
    my $splices     = 'splice variants';
    my $action      = $hub->action;
    my %biotype_rows;

    my $trans_attribs = {};
    my $trans_gencode = {};
    my @appris_codes  = qw(appris_pi appris_ci appris_ci1 appris_ci2 appris_ci3);

    foreach my $trans (@$transcripts) {
      foreach my $attrib_type (qw(CDS_start_NF CDS_end_NF gencode_basic TSL), @appris_codes) {
        (my $attrib) = @{$trans->get_all_Attributes($attrib_type)};
        next unless $attrib;
        if($attrib_type eq 'gencode_basic' && $attrib->value) {
          $trans_gencode->{$trans->stable_id}{$attrib_type} = $attrib->value;
        } elsif ($attrib_type =~ /appris/  && $attrib->value) {
          ## There should only be one APPRIS code per transcript
          (my $code = $attrib->code) =~ s/appris_//;
          $trans_attribs->{$trans->stable_id}{'appris'} = [$code, $attrib->name]; 
          last;
        } else {
          $trans_attribs->{$trans->stable_id}{$attrib_type} = $attrib->value if ($attrib && $attrib->value);
        }
      }
    }
    my %url_params = (
      type   => 'Transcript',
      action => $page_type eq 'gene' || $action eq 'ProteinSummary' ? 'Summary' : $action
    );
    
    if ($count == 1) { 
      $plural =~ s/s$//;
      $splices =~ s/s$//;
    }

    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
      $gene_html .= qq(<p>This transcript is a product of gene <a href="$gene_url">$gene_id</a></p>);
    }
   
    ## Link to other haplotype genes
    my $alt_link = $object->get_alt_allele_link;
    if ($alt_link) {
      if ($page_type eq 'gene') {
        $location_html .= "<p>$alt_link</p>";
      }
    }

    my $show    = $hub->get_cookie_value('toggle_transcripts_table') eq 'open';

    $gene_html .= sprintf('<p>This gene has %s %s (%s)
      <a rel="transcripts_table" class="button toggle no_img _slide_toggle set_cookie %s" href="#" title="Click to toggle the transcript table">
      <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
      </a></p>',
      $count,
      $plural,
      $splices,
      $show ? 'open' : 'closed'
    );

    my @columns = (
       { key => 'name',       sort => 'string',  title => 'Name'          },
       { key => 'transcript', sort => 'html',    title => 'Transcript ID' },
       { key => 'bp_length',  sort => 'numeric', label => 'bp', title => 'Length in base pairs'},
       { key => 'protein',    sort => 'html',    label => 'Protein', title => 'Protein length in amino acids' },
       { key => 'biotype',    sort => 'html',    title => 'Biotype', align => 'left' },
    );

    push @columns, { key => 'ccds', sort => 'html', title => 'CCDS' } if $species =~ /^Homo_sapiens|Mus_musculus/;
    
    my @rows;
   
    my %extra_links = (
      uniprot => { match => "^UniProt", name => "UniProt", order => 0, hidden => 1 },
      refseq => { match => "^RefSeq", name => "RefSeq", order => 1 },
    );
    my %any_extras;
 
    foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      my $transcript_length = $_->length;
      my $tsi               = $_->stable_id;
      my $protein           = 'No protein';
      my $protein_url       = '';
      my $protein_length    = '-';
      my $ccds              = '-';
      my %extras;
      my $cds_tag           = '-';
      my $gencode_set       = '-';
      my $url               = $hub->url({ %url_params, t => $tsi });
      my (@flags, @evidence);
      
      if ($_->translation) {
        $protein_url = $hub->url({
                          type   => 'Transcript',
                          action => 'ProteinSummary',
                          t      => $tsi
                        });
        
        $protein_length = $_->translation->length;
      }

      my $dblinks = $_->get_all_DBLinks;
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @$dblinks) { 
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }
      foreach my $k (keys %extra_links) {
        if(my @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'match'}/i } @$dblinks) {
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
      if ($trans_attribs->{$tsi}) {
        if ($trans_attribs->{$tsi}{'CDS_start_NF'}) {
          if ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
            push @flags,qq(<span class="glossary_mouseover">CDS 5' and 3' incomplete<span class="floating_popup">$trans_5_3_desc</span></span>);
          }
          else {
            push @flags,qq(<span class="glossary_mouseover">CDS 5' incomplete<span class="floating_popup">$trans_5_desc</span></span>);
          }
        }
        elsif ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
         push @flags,qq(<span class="glossary_mouseover">CDS 3' incomplete<span class="floating_popup">$trans_3_desc</span></span>);
        }
        if ($trans_attribs->{$tsi}{'TSL'}) {
          my $tsl = uc($trans_attribs->{$tsi}{'TSL'} =~ s/^tsl([^\s]+).*$/$1/gr);
          push @flags, sprintf qq(<span class="glossary_mouseover">TSL:%s<span class="floating_popup">%s</span></span>), $tsl, $glossary{"TSL$tsl"};
        }
      }

      if ($trans_gencode->{$tsi}) {
        if ($trans_gencode->{$tsi}{'gencode_basic'}) {
          push @flags,qq(<span class="glossary_mouseover">GENCODE basic<span class="floating_popup">$gencode_desc</span></span>);
        }
      }
      if ($trans_attribs->{$tsi}{'appris'}) {
        my ($code, $text) = @{$trans_attribs->{$tsi}{'appris'}};
        my $glossary_url  = $hub->url({'type' => 'Help', 'action' => 'Glossary', 'id' => '493', '__clear' => 1});
        my $appris_link   = $hub->get_ExtURL_link('APPRIS website', 'APPRIS');
        push @flags, $code
          ? sprintf('<span class="glossary_mouseover">APPRIS %s<span class="floating_popup">%s<br /><a href="%s" class="popup">Glossary entry for APPRIS</a><br />%s</span></span>', uc $code, $text, $glossary_url, $appris_link)
          : sprintf('<span class="glossary_mouseover">APPRIS<span class="floating_popup">%s<br />%s</span></span>', $text, $appris_link);
      }

      (my $biotype_text = $_->biotype) =~ s/_/ /g;
      if ($biotype_text =~ /rna/i) {
        $biotype_text =~ s/rna/RNA/;
      }
      else {
        $biotype_text = ucfirst($biotype_text);
      } 
      my $merged = '';
      $merged .= " Merged Ensembl/Havana gene." if $_->analysis->logic_name =~ /ensembl_havana/;
      $extras{$_} ||= '-' for(keys %extra_links);
      my $row = {
        name       => { value => $_->display_xref ? $_->display_xref->display_id : 'Novel', class => 'bold' },
        transcript => sprintf('<a href="%s">%s</a>', $url, $tsi),
        bp_length  => $transcript_length,
        protein    => ($protein_length ne '-') ?
                          sprintf('<a href="%s" title="View protein">%s</a>', $protein_url, $protein_length.' aa') 
                          : $protein,
        biotype    => $self->colour_biotype($self->glossary_mouseover($biotype_text,undef,$merged),$_),
        ccds       => $ccds,
        %extras,
        has_ccds   => $ccds eq '-' ? 0 : 1,
        cds_tag    => $cds_tag,
        gencode_set=> $gencode_set,
        options    => { class => $count == 1 || $tsi eq $transcript ? 'active' : '' },
        flags => join('',map { $_ =~ /<img/ ? $_ : "<span class='ts_flag'>$_</span>" } @flags),
        evidence => join('', @evidence),
      };
      
      $biotype_text = '.' if $biotype_text eq 'Protein coding';
      $biotype_rows{$biotype_text} = [] unless exists $biotype_rows{$biotype_text};
      push @{$biotype_rows{$biotype_text}}, $row;
    }
    foreach my $k (sort { $extra_links{$a}->{'order'} cmp
                          $extra_links{$b}->{'order'} } keys %any_extras) {
      my $x = $extra_links{$k};
      push @columns, { key => $k, sort => 'html', title => $x->{'name'}};
    }
    push @columns, { key => 'flags', sort => 'html', title => 'Flags' };

    ## Additionally, sort by CCDS status and length
    while (my ($k,$v) = each (%biotype_rows)) {
      my @subsorted = sort {$b->{'has_ccds'} cmp $a->{'has_ccds'}
                            || $b->{'bp_length'} <=> $a->{'bp_length'}} @$v;
      $biotype_rows{$k} = \@subsorted;
    }

    # Add rows to transcript table
    push @rows, @{$biotype_rows{$_}} for sort keys %biotype_rows; 

    my @hidecols;
    foreach my $id (keys %extra_links) {
      foreach my $i (0..$#columns) {
        if($columns[$i]->{'key'} eq $id and $extra_links{$id}->{'hidden'}) {
          push @hidecols,$i;
          last;
        }
      }
    }

    $transc_table = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width' . ($show ? '' : ' hide'),
      id                => 'transcripts_table',
      exportable        => 1,
      hidden_columns    => \@hidecols,
    });
  }

  $table->add_row('Location', $location_html);

  my $insdc_accession;
  $insdc_accession = $self->object->insdc_accession if $self->object->can('insdc_accession');
  $table->add_row('INSDC coordinates',$insdc_accession) if $insdc_accession;

  $table->add_row($page_type eq 'gene' ? 'Transcripts' : 'Gene', $gene_html) if $gene_html;

  return sprintf '<div class="summary_panel">%s%s</div>', $table->render, $transc_table ? $transc_table->render : '';
}

sub get_synonyms {
  my ($self, $match_id, @matches) = @_;
  my ($ids, $syns);
  foreach my $m (@matches) {
    my $dbname = $m->db_display_name;
    my $disp_id = $m->display_id;
    if ($dbname =~/(HGNC|ZFIN)/ && $disp_id eq $match_id) {
      my $synonyms = $m->get_all_synonyms;
      $ids = '';
      $ids = $ids . ', ' . (ref $_ eq 'ARRAY' ? "@$_" : $_) for @$synonyms;
    }
  }
  $ids  =~ s/^\,\s*//;
  $syns = $ids if $ids =~ /^\w/;
  return $syns;
}

sub species_stats {
  my $self = shift;
  my $sd = $self->hub->species_defs;
  my $html = '<h3>Summary</h3>';

  my $db_adaptor = $self->hub->database('core');
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $genome_container = $db_adaptor->get_GenomeContainer();

  my %glossary          = $sd->multiX('ENSEMBL_GLOSSARY');
  my %glossary_lookup   = (
      'coding'              => 'Protein coding',
      'snoncoding'          => 'Small non coding gene',
      'lnoncoding'          => 'Long non coding gene',
      'pseudogene'          => 'Pseudogene',
      'transcript'          => 'Transcript',
    );


  my $cols = [
    { key => 'name', title => '', width => '30%', align => 'left' },
    { key => 'stat', title => '', width => '70%', align => 'left' },
  ];
  my $options = {'header' => 'no', 'rows' => ['bg3', 'bg1']};

  ## SUMMARY STATS
  my $summary = EnsEMBL::Web::Document::Table->new($cols, [], $options);

  my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
  if ($a_id) {
    # look for long name and accession num
    if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
      $a_id .= " ($long)";
    }
    if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
      $acc = sprintf('INSDC Assembly <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>', $acc, $acc);
      $a_id .= ", $acc";
    }
  }
  $summary->add_row({
      'name' => '<b>Assembly</b>',
      'stat' => $a_id.', '.$sd->ASSEMBLY_DATE
  });
  $summary->add_row({
      'name' => '<b>Database version</b>',
      'stat' => $sd->ENSEMBL_VERSION.'.'.$sd->SPECIES_RELEASE_VERSION
  });
  $summary->add_row({
      'name' => '<b>Base Pairs</b>',
      'stat' => $self->thousandify($genome_container->get_total_length()),
  });
  my $header = '<span class="glossary_mouseover">Golden Path Length<span class="floating_popup">'.$glossary{'Golden path length'}.'</span></span>';
  $summary->add_row({
      'name' => "<b>$header</b>",
      'stat' => $self->thousandify($genome_container->get_ref_length())
  });
  $summary->add_row({
      'name' => '<b>Genebuild by</b>',
      'stat' => $sd->GENEBUILD_BY
  });
  my @A         = @{$meta_container->list_value_by_key('genebuild.method')};
  my $method  = ucfirst($A[0]) || '';
  $method     =~ s/_/ /g;
  $summary->add_row({
      'name' => '<b>Genebuild method</b>',
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
  my $gencode = $sd->GENCODE_VERSION;
  if ($gencode) {
    $summary->add_row({
      'name' => '<b>Gencode version</b>',
      'stat' => $gencode,
    });
  }

  $html .= $summary->render;
  ## GENE COUNTS (FOR PRIMARY ASSEMBLY)
  my $counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
  my @stats = qw(coding snoncoding lnoncoding pseudogene transcript);
  my $has_alt = $genome_container->get_alt_coding_count();

  my $primary = $has_alt ? ' (Primary assembly)' : '';
  $html .= "<h3>Gene counts$primary</h3>";

  foreach (@stats) {
    my $name = $_.'_cnt';
    my $method = 'get_'.$_.'_count';
    my $title = $genome_container->get_attrib($name)->name();
    my $term = $glossary_lookup{$_};
    my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
    my $stat = $self->thousandify($genome_container->$method);
    unless ($_ eq 'transcript') {
      my $rmethod = 'get_r'.$_.'_count';
      my $readthrough = $genome_container->$rmethod;
      if ($readthrough) {
        $stat .= ' (incl. '.$self->thousandify($readthrough).' <span class="glossary_mouseover">readthrough<span class="floating_popup">'.$glossary{'Readthrough'}.'</span></span>)';
      }
    }
    $counts->add_row({
      'name' => "<b>$header</b>",
      'stat' => $stat,
    }) if $stat;
  }

  $html .= $counts->render;

  ## GENE COUNTS FOR ALTERNATIVE ASSEMBLY
  if ($has_alt) {
    $html .= "<h3>Gene counts (Alternative sequence)</h3>";
    my $alt_counts = EnsEMBL::Web::Document::Table->new($cols, [], $options);
    foreach (@stats) {
      my $name = $_.'_acnt';
      my $method = 'get_alt_'.$_.'_count';
      my $title = $genome_container->get_attrib($name)->name();
      my $term = $glossary_lookup{$_};
      my $header = $term ? qq(<span class="glossary_mouseover">$title<span class="floating_popup">$glossary{$term}</span></span>) : $title;
      my $stat = $self->thousandify($genome_container->$method);
      unless ($_ eq 'transcript') {
        my $rmethod = 'get_alt_r'.$_.'_count';
        my $readthrough = $genome_container->$rmethod;
        if ($readthrough) {
          $stat .= ' (incl. '.$self->thousandify($readthrough).' <span class="glossary_mouseover">readthrough<span class="floating_popup">'.$glossary{'Readthrough'}.'</span></span>)';
        }
      }
      $alt_counts->add_row({
        'name' => "<b>$header</b>",
        'stat' => $stat,
      }) if $stat;
    }
    $html .= $alt_counts->render;
  }
  ## OTHER STATS
  my $rows = [];
  ## Prediction transcripts
  my $analysis_adaptor = $db_adaptor->get_AnalysisAdaptor();
  my $attribute_adaptor = $db_adaptor->get_AttributeAdaptor();
  my @analyses = @{ $analysis_adaptor->fetch_all_by_feature_class('PredictionTranscript') };
  foreach my $analysis (@analyses) {
    my $logic_name = $analysis->logic_name;
    my $stat = $genome_container->get_prediction_count($logic_name);
    my $name = $attribute_adaptor->fetch_by_code($logic_name)->[2];
    push @$rows, {
      'name' => "<b>$name</b>",
      'stat' => $self->thousandify($stat),
    } if $stat;
  }
  ## Variants
  if ($self->hub->database('variation')) {
    my @other_stats = (
      {'name' => 'SNPCount', 'method' => 'get_short_variation_count'},
      {'name' => 'struct_var', 'method' => 'get_structural_variation_count'}
    );
    foreach (@other_stats) {
      my $method = $_->{'method'};
      my $stat = $self->thousandify($genome_container->$method);
      push @$rows, {
        'name' => '<b>'.$genome_container->get_attrib($_->{'name'})->name().'</b>',
        'stat' => $stat,
      } if $stat;
    }
  }
  if (scalar(@$rows)) {
    $html .= '<h3>Other</h3>';
    my $other = EnsEMBL::Web::Document::Table->new($cols, $rows, $options);
    $html .= $other->render;
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

  my @messages = $self->object->check_for_align_in_database($args->{align}, $args->{species}, $args->{cdb});
  push @messages, $self->object->check_for_missing_species($args);

  return $self->show_warnings(\@messages);
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
    push(@$svfs,@{$slice->$func});
  }
  
  foreach my $svf (@{$svfs}) {
    my $name        = $svf->variation_name;
    my $description = $svf->source_description;
    my $sv_class    = $svf->var_class;
    my $source      = $svf->source;
    
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
    'deleterious'       => 'bad'
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
      $self->coltab($_->label,$hex,$_->description);
    }
    @consequences;
  my $rank = $consequences[0]->rank;
      
  return ($type) ? qq{<span class="hidden">$rank</span>$type} : '-';
}

1;
