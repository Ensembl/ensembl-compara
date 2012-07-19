# $Id$

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
  
  if ($hub->action eq 'Genome' || !$object) {
    $html =
      'LRG (Locus Reference Genomic) sequences provide a stable genomic DNA framework ' .
      'for reporting mutations with a permanent ID and core content that never changes. ' . 
      'For more information, visit the <a href="http://www.lrg-sequence.org">LRG website</a>.';
  } else {
    my $lrg         = $object->Obj;
    my $param       = $hub->param('lrg');
    my $transcript  = $hub->param('lrgt');
		(my $href       = $external_urls->{'LRG'}) =~ s/###ID###//;
    my $description = qq{LRG region <a rel="external" href="$href">$param</a>.};
    my @genes       = @{$lrg->get_all_Genes('LRG_import')||[]};
    my $db_entry    = $genes[0]->get_all_DBLinks('HGNC');
    my $slice       = $lrg->feature_Slice;
    my $source      = $genes[0]->source;
       $source      = 'LRG' if $source =~ /LRG/;
    (my $source_url = $external_urls->{uc $source}) =~ s/###ID###//;
    
    $description .= sprintf(
      ' This LRG was created as a reference standard for the <a href="%s">%s</a> gene.',
      $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $db_entry->[0]->display_id,
      }),
      $db_entry->[0]->display_id
    );
    
    $description  =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
    $description .= qq{ Source: <a rel="external" href="$source_url">$source</a>.} if $source_url;
    
    my $location_html = sprintf(
      '<a href="%s">%s: %s-%s</a> %s.',
      $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $slice->seq_region_name . ':' . $slice->start . '-' . $slice->end
      }),
      $self->neat_sr_name($slice->coord_system->name, $slice->seq_region_name),
      $self->thousandify($slice->start),
      $self->thousandify($slice->end),
      $slice->strand < 0 ? ' reverse strand' : 'forward strand'
    );
    
    my $transcripts = $lrg->get_all_Transcripts(undef, 'LRG_import'); 

    my $count    = @$transcripts;
    my $plural_1 = 'are';
    my $plural_2 = 'transcripts';
    
    if ($count == 1) {
      $plural_1 = 'is'; 
      $plural_2 =~ s/s$//; 
    }
    
    my $hide    = $hub->get_cookies('toggle_transcripts_table') eq 'closed';
    my @columns = (
       { key => 'name',        sort => 'string', title => 'Name'          },
       { key => 'transcript',  sort => 'html',   title => 'Transcript ID' },
       { key => 'description', sort => 'none',   title => 'Description'   },
    );
		
    my @rows;
    
		my %url_params = (
      type => 'LRG',
			lrg  => $param
    );
 
    foreach (map $_->[2], sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map [$_->external_name, $_->stable_id, $_], @$transcripts) {
      push @rows, {
        name        => { value => encode_entities($_->display_xref ? $_->display_xref->display_id : '-'), class => 'bold' },
        transcript  => sprintf('<a href="%s">%s</a>', $hub->url({ %url_params, lrgt => $_->stable_id }), $_->stable_id),
        description => 'Fixed transcript for reporting purposes',
        options     => { class => $count == 1 || $_->stable_id eq $transcript ? 'active' : '' }
      };
    }
    
    my $table = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width no_col_toggle',
      id                => 'transcripts_table',
      style             => $hide ? 'display:none' : '',
      exportable        => 0
    });
    
    $html = $self->new_twocol(
      ['Description', "<p>$description</p>", 1],
      ['Location', "<p>$location_html</p>", 1],
      [sprintf('<a rel="transcripts_table" class="toggle set_cookie %s" href="#" title="Click to toggle the transcript table">Transcripts</a>', $hide ? 'closed' : 'open'), "There $plural_1 $count $plural_2 in this region:", 1]
    )->render.$table->render;
  }

  return qq{<div class="summary_panel">$html</div>};
}

1;
