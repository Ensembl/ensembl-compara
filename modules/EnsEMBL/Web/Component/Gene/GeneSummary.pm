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

package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

# Uses SQL wildcards
my @SYNONYM_PATTERNS = qw(%HGNC% %ZFIN%);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $table        = $self->new_twocol;
  my $location     = $hub->param('r') || sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;
  my $site_type    = $species_defs->ENSEMBL_SITETYPE;
  my @syn_matches;
  push @syn_matches,@{$object->get_database_matches($_)} for @SYNONYM_PATTERNS;
  my @CCDS         = grep $_->dbname eq 'CCDS', @{$object->Obj->get_all_DBLinks('CCDS')};
  my $db           = $object->get_db;
  my $alt_genes    = $self->_matches('alternative_genes', 'Alternative Genes', 'ALT_GENE', 'show_version'); #gets all xrefs, sorts them and stores them on the object. Returns HTML only for ALT_GENES
  my @RefSeqMatches  = @{$object->gene->get_all_Attributes('refseq_compare')};

  my $disp_syn     = 0;

  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;
  my ($prefix, $name, $disp_id_table, $HGNC_table, %syns, %text_info, $syns_html);

  # remove prefix from the URL for Vega External Genes
  if ($hub->species eq 'Mus_musculus' && $object->source eq 'vega_external') {
    ($prefix, $name) = split ':', $display_name;
    $display_name = $name;
  }

  my $linked_display_name = $hub->get_ExtURL_link($display_name, $dbname, $ext_id);
  $linked_display_name = $prefix . ':' . $linked_display_name if $prefix;
  $linked_display_name = $display_name if $dbname_disp =~ /^Projected/; # i.e. don't have a hyperlink
  $info_text = '';

  $table->add_row('Name', qq{<p>$linked_display_name ($dbname_disp) $info_text</p>}) if $linked_display_name;

  foreach my $link (@{$object->__data->{'links'}{'PRIMARY_DB_SYNONYM'}||[]}) {
    my ($key, $text) = @$link;
    my $id           = [split /\<|\>/, $text]->[4];
    my $synonyms     = $self->get_synonyms($id, @syn_matches);

    $text =~ s/\<div\s*class="multicol"\>|\<\/div\>//g;
    $text =~ s/<br \/>.*$//gism;

    if ($id =~ /$display_name/ && $synonyms =~ /\w/) {
      $disp_syn  = 1;
      $syns{$id} = $synonyms;
    }
    $text_info{$id} = $text;
    $syns{$id}      = $synonyms if $synonyms =~ /\w/ && $id !~ /$display_name/;
  }
  foreach my $k (keys %text_info) {
    my $syn = $syns{$k};
    my $syn_entry;
    if ($disp_syn == 1) {
      my $url = $hub->url({
        type   => 'Location',
        action => 'Genome', 
        r      => $location,
        id     => $display_name,
        ftype  => 'Gene'
      });
      $syns_html .= qq{<p>$syn [<span class="small">To view all $site_type genes linked to the name <a href="$url">click here</a>.</span>]</p>};
    }
  }

  $table->add_row('Synonyms', $syns_html) if $syns_html;

  # add CCDS info
  if (scalar @CCDS) {
    my %temp = map { $_->primary_id, 1 } @CCDS;
    @CCDS = sort keys %temp;
    $table->add_row('CCDS', sprintf('<p>This gene is a member of the %s CCDS set: %s</p>', $species_defs->DISPLAY_NAME, join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS));
  }

  ## add RefSeq match info where appropriate
  if (scalar @RefSeqMatches) {
    my $string;
    foreach my $match (@RefSeqMatches) {
      my $v = $match->value;
      $v =~ /RefSeq Gene ID ([\d]+)/;
      my $id = $1;
      my $url = $hub->get_ExtURL('REFSEQ_GENEIMP', $id);
      (my $link = $v) =~ s/RefSeq Gene ID ([\d]+)/RefSeq Gene ID <a href="$url" rel="external">$1<\/a>/;
      $string .= sprintf('<p>%s</p>', $link);
    }
    $table->add_row('RefSeq', $string);
  }

  ## LRG info
  # first link to direct xrefs (i.e. this gene has an LRG)
  my @lrg_matches = @{$object->get_database_matches('ENS_LRG_gene')};
  my $lrg_html;
  my %xref_lrgs;    # this hash will store LRGs we don't need to re-print

  if(scalar @lrg_matches && $hub->species_defs->HAS_LRG) {
    my $lrg_link;
    for my $i(0..$#lrg_matches) {
      my $lrg = $lrg_matches[$i];
      my $link = $hub->get_ExtURL_link($lrg->display_id, 'ENS_LRG_gene', $lrg->display_id);

      if($i == 0) { # first one
        $lrg_link .= $link;
      }
      elsif($i == $#lrg_matches) { # last one
        $lrg_link .= " and ".$link;
      }
      else { # any other
        $lrg_link .= ", ".$link;
      }
      $xref_lrgs{$lrg->display_id} = 1;
    }
    $lrg_link =
      $lrg_link." provide".
      (@lrg_matches > 1 ? "" : "s").
      " a stable genomic reference framework ".
      "for describing sequence variations for this gene";

    $lrg_html .= $lrg_link;
  }

  # now look for lrgs that contain or partially overlap this gene
  foreach my $attrib(@{$object->gene->get_all_Attributes('GeneInLRG')}, @{$object->gene->get_all_Attributes('GeneOverlapLRG')}) {
    next if $xref_lrgs{$attrib->value};
    my $link = $hub->get_ExtURL_link($attrib->value, 'ENS_LRG_gene', $attrib->value);
    $lrg_html .= '<br/>' if $lrg_html;
    $lrg_html .=
      'This gene is '.
      ($attrib->code =~ /overlap/i ? "partially " : " ").
      'overlapped by the stable genomic reference framework '.$link;
  }

  # add a row to the table
  $table->add_row('LRG', $lrg_html) if $lrg_html;

  $table->add_row('Ensembl version', $object->stable_id.'.'.$object->version);

  ## Link to another assembly, e.g. previous archive
  my $current_assembly = $hub->species_defs->ASSEMBLY_NAME;
  my $alt_assembly = $hub->species_defs->SWITCH_ASSEMBLY;
  if ($alt_assembly) {
    my $alt_release = $hub->species_defs->SWITCH_VERSION;
    my $url = 'http://'.$hub->species_defs->SWITCH_ARCHIVE_URL;
    my $txt;
    ## Are we jumping backwards or forwards?
    if ($alt_release < $hub->species_defs->ENSEMBL_VERSION) {
      ## get coordinates on other assembly if available
      if (my @mappings = @{$hub->species_defs->get_config($hub->species, 'ASSEMBLY_MAPPINGS')||[]}) {
        foreach my $mapping (@mappings) {
          next unless $mapping eq sprintf ('chromosome:%s#chromosome:%s', $current_assembly, $alt_assembly);
          my $segments = $object->get_Slice->project('chromosome', $alt_assembly);
          ## link if there is an ungapped mapping of whole gene
          if (scalar(@$segments) == 1) {
            my $new_slice = $segments->[0]->to_Slice;
            $txt .= "<p>This gene maps to ";
            $txt .= sprintf(qq(<a href="${url}%s/Location/View?r=%s:%s-%s" target="external">%s-%s</a>),
                          $hub->species_path,
                          $new_slice->seq_region_name,
                          $new_slice->start,
                          $new_slice->end,
                          $self->thousandify($new_slice->start),
                          $self->thousandify($new_slice->end));
            $txt .= qq( in $alt_assembly coordinates.</p>);
          }
          else {
            $txt .= qq(<p>There is no ungapped mapping of this gene onto the $alt_assembly assembly.</p>);
          } 
        }
      }
      ## Plus direct link to feature in Ensembl
      my $old_id;
      my $history = $object->history;
      foreach my $a ( @{ $history->get_all_ArchiveStableIds } ) {
        next unless $a->release <= $alt_release;
        $old_id = $a->stable_id;
        last;
      }
      if ($old_id) {
        $txt .= sprintf(qq(<p><a href="%s" rel="external">Jump to this stable ID</a> in the $alt_assembly archive.</p>),
                      $url.$hub->species_path."/Gene/Summary?g=".$old_id);
      }
      else {
        $txt .= 'Stable ID '.$hub->param('g')." not present in $alt_assembly.";
      }
      $table->add_row('Previous assembly', $txt);
    }
    else {
      ## Jumping forwards is less accurate as we probably don't have mappings - do our best here!
      $txt .= sprintf('<p><a href="%s/%s/Search/Results?q=%s" rel="external">Search for this gene</a> on assembly %s.</p>', $url, $hub->species_path, $hub->param('g'), $alt_assembly);
      $table->add_row('Latest assembly', $txt);
    } 
  }

  # add some Vega info
  if ($db eq 'vega') {
    my $type    = $object->gene_type;
    my $version = $object->version;
    my $c_date  = $object->created_date;
    my $m_date  = $object->mod_date;
    my $author  = $object->get_author_name;
    my $remarks = $object->retrieve_remarks;

    $table->add_row('Gene type', qq{<p>$type [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>});
    $table->add_row('Version &amp; date', qq{<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>});
    $table->add_row('Author', "This transcript was annotated by $author");
    if ( @$remarks ) {
      my $text;
      foreach my $rem (@$remarks) {
      	next unless $rem;  #ignore remarks with a value of 0
        $text .= "<p>$rem</p>";
      }
      $table->add_row('Remarks', $text) if $text;
    }
  } else {
    my $type = $object->gene_type;
    $table->add_row('Gene type', $type) if $type;
  }

  eval {
    # add prediction method
    my $label = ($db eq 'vega' || $site_type eq 'Vega' ? 'Curation' : 'Prediction') . ' Method';
    my $text  = "<p>No $label defined in database</p>";
    my $o     = $object->Obj;

    if ($o && $o->can('analysis') && $o->analysis && $o->analysis->description) {
      $text = $o->analysis->description;
    } elsif ($object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description) {
      $text = $object->gene->analysis->description;
    }

    $table->add_row($label, $text);
  };

  $table->add_row('Alternative genes', $alt_genes) if $alt_genes; # add alternative gene info

  my $cv_terms = $object->get_cv_terms;
  if (@$cv_terms) {
    my $first = shift @$cv_terms;
    my $text = qq(<p>$first [<a href="http://vega.sanger.ac.uk/info/about/annotation_attributes.html">Definitions</a>]</p>);
    foreach my $next (@$cv_terms) {
      $text .= "<p>$next</p>";
    }
    $table->add_row('Annotation Attributes', $text) if $text;;
  }

  ## Secondary structure (currently only non-coding RNAs)
  if ($self->hub->database('compara') && $object->{'_availability'}{'can_r2r'}) {
    my $svg_path = $self->draw_structure($display_name, 1);
    my $html;
    if ($svg_path) {
      my $fullsize = $self->hub->url({'action' => 'SecondaryStructure'});
      $html = qq(<object data="$svg_path" type="image/svg+xml"></object>
<br /><a href="$fullsize">[click to enlarge]</a>);
      $table->add_row('Secondary structure', $html);
    }
  }

  return $table->render;
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

1;
