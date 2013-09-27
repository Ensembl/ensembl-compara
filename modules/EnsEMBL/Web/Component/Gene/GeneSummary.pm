# $Id$

package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::TmpFile::Image;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $table        = $self->new_twocol;
  my $location     = $hub->param('r') || sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;
  my $site_type    = $species_defs->ENSEMBL_SITETYPE;
  my $matches      = $object->get_database_matches;
  my @CCDS         = grep $_->dbname eq 'CCDS', @{$object->Obj->get_all_DBLinks};
  my $db           = $object->get_db;
  my $alt_genes    = $self->_matches('alternative_genes', 'Alternative Genes', 'ALT_GENE', 'show_version'); #gets all xrefs, sorts them and stores them on the object. Returns HTML only for ALT_GENES

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

  ## LRG info
  # first link to direct xrefs (i.e. this gene has an LRG)
  my @lrg_matches = grep {$_->dbname eq 'ENS_LRG_gene'} @$matches;
  my $lrg_html;
  my %xref_lrgs;    # this hash will store LRGs we don't need to re-print

  if(scalar @lrg_matches) {
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

  if ($object->gene_type =~ /RNA/ && $self->hub->species_defs->R2R_BIN) {
    my $structure = $self->draw_structure;
    $table->add_row('Secondary structure', $structure) if $structure;
  }

  return $table->render;
}

sub draw_structure {
  my $self = shift;
  my $html = '';
  my $database = $self->hub->database('compara');
  if ($database) {
    my $gma = $database->get_GeneMemberAdaptor();
    my $sma = $database->get_SeqMemberAdaptor();
    my $gta = $database->get_GeneTreeAdaptor();

    my $member  = $gma->fetch_by_source_stable_id(undef, $self->object->stable_id);
    my $peptide = $sma->fetch_canonical_for_gene_member_id($member->member_id);

    my $gene_tree   = $gta->fetch_default_for_Member($member);
    my $model_name  = $gene_tree->get_tagvalue('model_name');
    my $ss_cons     = $gene_tree->get_tagvalue('ss_cons');
    my $input_aln   = $gene_tree->get_SimpleAlign( -id => 'MEMBER' );
    my $aln_file    = $self->_dump_multiple_alignment($input_aln, $model_name, $ss_cons);
    my ($thumbnail, $plot) = $self->_draw_structure($aln_file, $gene_tree, $peptide->stable_id);
    my $svg_path    = $self->hub->species_defs->ENSEMBL_TMP_URL_IMG.'/r2r';
    $html .= qq(<object data="$svg_path/$thumbnail" type="image/svg+xml"></object>
<br /><a href="$svg_path/$plot">[click to enlarge]</a>);
  }
  return $html;
}

sub _dump_multiple_alignment {
    my ($self, $aln, $model_name, $ss_cons) = @_;
    if ($ss_cons =~ /^\.+$/) {
      warn "The tree has no structure\n";
      return undef;
    }

    my $aln_file  = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                        filename => "${model_name}.sto",
                    ); 

    my $content = "# STOCKHOLM 1.0\n";
    for my $aln_seq ($aln->each_seq) {
      $content .= sprintf ("%-20s %s\n", $aln_seq->display_id, $aln_seq->seq);
    }
    $content .= sprintf ("%-20s\n", "#=GF R2R keep allpairs");
    $content .= sprintf ("%-20s %s\n//\n", "#=GC SS_cons", $ss_cons);

    $aln_file->print($content);
    return $aln_file;
}

sub _get_aln_file {
  my ($self, $aln_file) = @_;

  my $input_path  = $aln_file->{'full_path'};
  my $output_path = $input_path . ".cons";
  ## For information about these options, check http://breaker.research.yale.edu/R2R/R2R-manual-1.0.3.pdf
  $self->_run_r2r_and_check("--GSC-weighted-consensus", $input_path, $output_path, "3 0.97 0.9 0.75 4 0.97 0.9 0.75 0.5 0.1");

  return $output_path;
}

sub _draw_structure {
    my ($self, $aln_file, $tree, $peptide_id) = @_;

    my $output_path = $self->_get_aln_file($aln_file);
    my $r2r_path    = $self->hub->species_defs->ENSEMBL_TMP_DIR_IMG.'/r2r/';

    my $th_meta = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                        filename => $aln_file->filename . "-thumbnail.meta",
                    );
    my $th_content = "$output_path\tskeleton-with-pairbonds\n";
    $th_meta->print($th_content);
    my $thumbnail = $aln_file->filename.".thumbnail.svg";
    $self->_run_r2r_and_check("", $th_meta->{'full_path'}, $r2r_path.$thumbnail, "");

    my $meta_file  = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                        filename => $aln_file->filename . ".meta",
                    ); 
    my $content = "$output_path\n";
    $content .= $aln_file->{'full_path'}."\toneseq\t$peptide_id\n";
    $meta_file->print($content);

    my $plot_file = $aln_file->filename."-${peptide_id}.svg";
    $self->_run_r2r_and_check("", $meta_file->{'full_path'}, $r2r_path.$plot_file, "");

    return ($thumbnail, $plot_file);
}

sub _run_r2r_and_check {
    my ($self, $opts, $infile, $outfile, $extra_params) = @_;
    my $r2r_exe = $self->hub->species_defs->R2R_BIN; 
    warn "$r2r_exe doesn't exist" unless ($r2r_exe);

    my $cmd = "$r2r_exe $opts $infile $outfile $extra_params";
    system($cmd);
    if (! -e $outfile) {
       warn "Problem running r2r: $outfile doesn't exist\nThis is the command I tried to run:\n$cmd\n";
    }
    return;
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
