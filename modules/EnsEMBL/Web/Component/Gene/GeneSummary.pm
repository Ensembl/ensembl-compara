package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Document::HTML::TwoCol;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $table     = new EnsEMBL::Web::Document::HTML::TwoCol;
  my $location  = $object->param('r') || sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;
  my $site_type = $object->species_defs->ENSEMBL_SITETYPE;
  my $matches   = $object->get_database_matches;
  my @CCDS      = grep $_->dbname eq 'CCDS', @{$object->Obj->get_all_DBLinks};
  my $db        = $object->get_db;
  my $alt_genes = $self->_matches('alternative_genes', 'Alternative Genes', 'ALT_GENE');
  my $disp_syn  = 0;
  
  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;
  my ($prefix, $name, $disp_id_table, $HGNC_table, %syns, %text_info, $syns_html);

  # remove prefix from the URL for Vega External Genes
  if ($object->species eq 'Mus_musculus' && $object->source eq 'vega_external') {
    ($prefix, $name) = split ':', $display_name;
    $display_name = $name;
  }
  
  my $linked_display_name = $object->get_ExtURL_link($display_name, $dbname, $ext_id);
  $linked_display_name = $prefix . ':' . $linked_display_name if $prefix;
  $linked_display_name = $display_name if $dbname_disp =~ /^Projected/; # i.e. don't have a hyperlink
  $info_text = '';
  
  $table->add_row('Name', "<p>$linked_display_name ($dbname_disp) $info_text</p>", 1) if $linked_display_name;
  
  $self->_sort_similarity_links(@$matches);
  
  foreach my $link (@{$object->__data->{'links'}{'PRIMARY_DB_SYNONYM'}||[]}) {
    my ($key, $text) = @$link;
    my $id           = [split /\<|\>/, $text]->[4];
    my $synonyms     = $self->get_synonyms($id, @$matches);
    
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
      my $url = $object->_url({
        type   => 'Location',
        action => 'Genome', 
        r      => $location,
        id     => $display_name,
        ftype  => 'Gene'
      });
      
      $syns_html .= qq{<p>$syn [<span class="small">To view all $site_type genes linked to the name <a href="$url">click here</a>.</span>]</p></dd>};
    }
  }
  
  $table->add_row('Synonyms', $syns_html, 1) if $syns_html;

  # add CCDS info
  if (scalar @CCDS) {
    my %temp = map { $_->primary_id, 1 } @CCDS;
    @CCDS = sort keys %temp;
    $table->add_row('CCDS', sprintf('<p>This gene is a member of the %s CCDS set: %s</p>', $object->species_defs->DISPLAY_NAME, join ', ', map $object->get_ExtURL_link($_, 'CCDS', $_), @CCDS), 1);
  }
  
  # add some Vega info
  if ($db eq 'vega') {
    my $type    = $object->gene_type;
    my $version = $object->version;
    my $c_date  = $object->created_date;
    my $m_date  = $object->mod_date;
    my $author  = $object->get_author_name;
    
    $table->add_row('Gene type', qq{<p>$type [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>}, 1);
    $table->add_row('Version & date', qq{<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>}, 1);
    $table->add_row('Author', "This transcript was annotated by $author");
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
    
    $table->add_row($label, "<p>$text</p>", 1);
  };
  
  $table->add_row('Alternative genes', "<p>$alt_genes</p>", 1) if $alt_genes; # add alternative transcript info
  
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
