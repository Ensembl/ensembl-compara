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

package EnsEMBL::Web::Component::LRG::Summary;

### NAME: EnsEMBL::Web::Component::LRG::Summary;
### Generates a context panel for an LRG page

### STATUS: Under development

### DESCRIPTION:
### Because the LRG page is a composite of different domain object views, 
### the contents of this component vary depending on the object generated
### by the factory

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self          = shift;
  my $object        = $self->object;
  my $hub           = $self->hub;
  my $external_urls = $hub->species_defs->ENSEMBL_EXTERNAL_URLS;
  my $html;
  
  my $lrg_url = $external_urls->{'LRG_URL'};

  if ($hub->action eq 'Genome' || !$object) {
    $html =
      '<p>LRG (Locus Reference Genomic) sequences provide a stable genomic DNA framework ' .
      'for reporting mutations with a permanent ID and core content that never changes. ' . 
      'For more information, visit the <a href="'.$lrg_url.'">LRG website</a>.</p>';
  } else {
    my $lrg         = $object->Obj;
    my $lrg_gene    = $hub->param('lrg');
    my $transcript  = $hub->param('lrgt');
    (my $href       = $external_urls->{'LRG'}) =~ s/###ID###/$lrg_gene/;
    my $description = qq{LRG region <a rel="external" href="$href">$lrg_gene</a>.};
    my @genes       = @{$lrg->get_all_Genes('lrg_import')||[]};
    my $display     = $genes[0]->display_xref();

    my @hgnc_xrefs  = grep {$_->dbname =~ /hgnc/i} @{$genes[0]->get_all_DBEntries()}; # Retrieve the HGNC Xref
    my $slice       = $lrg->feature_Slice;
    my $source      = $genes[0]->source;
       $source      = 'LRG' if $source =~ /LRG/;
    my $source_url  = ($source eq 'LRG') ?  $lrg_url : $external_urls->{uc $source};
       $source_url  =~ s/\/###ID###//;

    if (scalar(@hgnc_xrefs)) {
      my $hgnc = $hgnc_xrefs[0]->display_id;
      $description .= sprintf(
        ' This LRG was created as a reference standard for the <a href="%s">%s</a> gene.',
        $hub->url({
          type   => 'Gene',
          action => 'Summary',
          g      => $hgnc,
        }),
        $hgnc
      );
    }
    else {
      $description .= $display->description;
    }
 
    $description  =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
    $description .= qq{ Source: <a rel="external" href="$source_url">$source</a>.} if $source_url;
    
    my $location_html = sprintf(
      '<p>maps to <a href="%s" class="constant">%s: %s-%s</a> %s.</p>',
      $hub->url({
        type             => 'Location',
        action           => 'View',
        r                => $slice->seq_region_name . ':' . $slice->start . '-' . $slice->end,
        contigviewbottom => 'lrg_transcript=transcript_label'
      }),
      $self->neat_sr_name($slice->coord_system->name, $slice->seq_region_name),
      $self->thousandify($slice->start),
      $self->thousandify($slice->end),
      $slice->strand < 0 ? ' reverse strand' : 'forward strand'
    );
    
    my $transcripts = $lrg->get_all_Transcripts(undef, 'LRG_import'); 

    my %distinct_tr = map { $_->external_name => 1} @$transcripts;
    if (scalar (keys(%distinct_tr)) == 0) {
      %distinct_tr = map { $_->stable_id => 1} @$transcripts;
    }

    my $count  = scalar (keys(%distinct_tr));
    my $plural = 'transcripts';
    
    if ($count == 1) { 
      $plural =~ s/s$//; 
    }
   
    my $tr_html = "This LRG has $count $plural";

    my $tr_cookie = $hub->get_cookie_value('toggle_transcripts_table');
    my $show = (defined($tr_cookie) && $tr_cookie ne '' ) ? $tr_cookie eq 'open' : 'open';

    my $tr_line = $tr_html . sprintf(
        ' <a rel="transcripts_table" class="button toggle _slide_toggle no_img set_cookie %s" href="#" title="Click to toggle the transcript table">
          <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
        </a>',
        $show ? 'open' : 'closed'
    );
    
    $html = $self->new_twocol(
      ['Description', $description],
      ['LRG location', $location_html],
      ['LRG transcripts', $tr_line]
    )->render;
    $html .= $self->transcript_table($tr_cookie);
  }

  return qq{<div class="summary_panel">$html</div>};
}


sub transcript_table {

  my $self        = shift;
  my $tr_cookie   = shift; 
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $lrg         = $object->Obj;
  my $lrg_id      = $hub->param('lrg');
  my $transcript  = $hub->param('lrgt');
  my $table       = $self->new_twocol;
  my $transcripts = $lrg->get_all_Transcripts(undef, 'LRG_import');
  my $count       = @$transcripts;

  my $trans_attribs = {};
  foreach my $trans (@$transcripts) {
    foreach my $attrib_type (qw(CDS_start_NF CDS_end_NF)) {
      (my $attrib) = @{$trans->get_all_Attributes($attrib_type)};
      if ($attrib && $attrib->value) {
        $trans_attribs->{$trans->stable_id}{$attrib_type} = $attrib->value;
      }
    }
  }
  my %url_params = (
    type   => 'LRG',    
    lrg    => $lrg_id
  );
    
  my $show    = (defined($tr_cookie) && $tr_cookie ne '' ) ? $tr_cookie eq 'open' : 'open';
  my @columns = (
     { key => 'transcript', sort => 'html',    title => 'Transcript ID' },
     { key => 'bp_length',  sort => 'numeric', title => 'Length (bp)'   },
     { key => 'protein',sort =>'html_numeric', title => 'Protein ID'    },
     { key => 'aa_length',  sort => 'numeric', title => 'Length (aa)'   },
  );

  push @columns, { key => 'cds_tag', sort => 'html', title => 'CDS incomplete' } if %$trans_attribs; 
    
  my @rows;
    
  foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->display_id, $_ ] } @$transcripts) {
    my $transcript_length = $_->length;
    my $t_label           = ($_->external_name && $_->external_name ne '') ? $_->external_name : $_->stable_id; # Because of LRG_321: several proteins per transcripti
    my $tsi               = $_->stable_id;
    my $protein           = 'No protein product';
    my $protein_length    = '-';
    my $ccds              = '-';
    my $cds_tag           = '-';
    my $url               = $hub->url({ %url_params, t => $tsi});
      
    if ($_->translation) {
      $protein = sprintf(
        '<a href="%s">%s</a>',
        $hub->url({
          %url_params,
          action => 'ProteinSummary',
          lrgt   => $tsi
        }),
        $_->translation->display_id
      );
        
      $protein_length = $_->translation->length;
    }
      
    if ($trans_attribs->{$tsi}) {
      if ($trans_attribs->{$tsi}{'CDS_start_NF'}) {
        if ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
          $cds_tag = "5' and 3'";
        }
        else {
          $cds_tag = "5'";
        }
      }
      elsif ($trans_attribs->{$tsi}{'CDS_end_NF'}) {
       $cds_tag = "3'";
      }
    }
      
    my $row = {
      transcript => sprintf('<a href="%s">%s</a>', $hub->url({ %url_params, action => 'Sequence_cDNA', lrgt => $tsi }), $t_label),
      bp_length  => $transcript_length,
      protein    => $protein,
      aa_length  => $protein_length,
      cds_tag    => $cds_tag,
      options    => { class => $count == 1 || $tsi eq $transcript ? 'active' : '' }
    };
      
    push @rows, $row;
  }

  my $tr_table = $self->new_table(\@columns, \@rows, {
    data_table        => 1,
    sorting           => [ 'transcript asc' ],
    data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
    toggleable        => 1,
    class             => 'fixed_width' . ($show ? '' : ' hide'),
    id                => 'transcripts_table',
    exportable        => 0
  });
    
  return $tr_table->render;
}

1;
