package EnsEMBL::Web::Component::LRG::Summary;

### NAME: EnsEMBL::Web::Component::LRG::Summary;
### Generates a context panel for an LRG page

### STATUS: Under development

### DESCRIPTION:
### Because the LRG page is a composite of different domain object views, 
### the contents of this component vary depending on the object generated
### by the factory

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::LRG);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $model = $self->model;
  my $hub = $model->hub;
  my $html = '';

## Grab the description of the object...

  if ($hub->action eq 'Genome') {
    $html = 'LRG (Locus Reference Genomic) sequences provide a stable genomic DNA framework 
for reporting mutations with a permanent ID and core content that never changes. For more
information, visit the <a href="http://www.lrg-sequence.org">LRG website</a>.
';
  }
  elsif ($model->object('ArchiveStableId')) {
    $html = '<p>This identifier is not in the current '.$hub->species_defs->ENSEMBL_SITETYPE.' database</p>';
  }
  elsif ($model->object('Family')) {
    $html = '<p>'.CGI::escapeHTML( $model->object->description ).'</p>';
  } 
  else {
    my($edb, $acc);
    my $description = ' LRG region <a target="_blank" href="http://www.lrg-sequence.org/LRG/'. $hub->param('lrg').'">'.$hub->param('lrg').'</a>.';
    if ($description) {
      if ($description ne 'No description') {
        my @genes = @{$self->object->Obj->get_all_Genes('LRG_import')||[]};
        my $db_entry = $genes[0]->get_all_DBLinks('HGNC');
		
		    my $gene_url = $object->_url({
		      type           => 'Gene',
		      action         => 'Summary',
		      g              => $db_entry->[0]->display_id,
        });
		
        $description .= ' This LRG was created as a reference standard for the <a href="'.$gene_url.'">'.$db_entry->[0]->display_id.'</a> gene.';
      
        $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
        $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:(\w+)\]//g;
        ($edb, $acc) = ($1, $2);
	      my $link = $self->model->hub->get_ExtURL_link("Source: $edb $acc",$edb, $acc);
        warn ">>> ACC $acc, LINK $link";
        if ($acc ne 'content') { 
          $description .= '<span class="small">'
                        .@{[ $self->model->hub->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}
                        .'</span>';
        }
        $html .= qq(<p>$description</p>);
      }
    }

    ## Now a link to location;

    my $fSlice = $model->api_object('LRG')->feature_Slice;
    my $r = $fSlice->seq_region_name.':'.$fSlice->start.'-'.$fSlice->end;

    my $url = $hub->url({
      'type'   => 'Location',
      'action' => 'View',
      'r'      => $r,
    });

    #my $location_html = sprintf( '<a href="%s">%s: %s-%s</a> %s.',
    #  $url,
    #  $object->neat_sr_name( $fSlice->coord_system->name, $fSlice->seq_region_name ),
    #  $object->thousandify( $fSlice->start ),
    #  $object->thousandify( $fSlice->end ),
    #  $fSlice->strand < 0 ? ' reverse strand' : 'forward strand'
    #);
    my $location_html = sprintf( '%s: %s-%s %s.',
      $object->neat_sr_name( $fSlice->coord_system->name, $fSlice->seq_region_name ),
      $object->thousandify( $fSlice->start ),
      $object->thousandify( $fSlice->end ),
      $fSlice->strand < 0 ? ' reverse strand' : 'forward strand'
    );

    # alternative (Vega) coordinates
    my $lc_type  = lc( $object->type_name );


    $html .= qq(
      <dl class="summary">
        <dt>Location</dt>
        <dd>
          $location_html
        </dd>
      </dl>);


    ## Now create the transcript information...
    if (0) {
      my $lrg_slice = $object->Obj;

      foreach my $gene (@{$lrg_slice->{_orig_slice}->get_all_Genes(undef,  undef, 1)}) {
        warn join ' * ', ' G ', $gene->stable_id || 'No Stable ID', $gene->slice->seq_region_name, "\n";
        foreach my $t (@{$gene->get_all_Transcripts}) {
	        warn "T: ", $t->stable_id, "\t", $t->analysis->logic_name;
        }
      
      }
    }
    #  my $transcripts = $object->Obj->{_orig_slice}->get_all_Transcripts(undef, 'LRG_download'); 

    my $transcripts = $object->Obj->get_all_Transcripts(undef, 'LRG_import'); 

    my $count = @$transcripts;
    my $plural_1 = "are";
    my $plural_2 = "transcripts"; 
    if ($count == 1 ) {
      $plural_1 = "is"; 
      $plural_2 =~s/s$//; 
    }

    my $transcript = $self->model->hub->param('t');
    $html .= qq(
      <dl class="summary">
        <dt>Transcripts</dt>
        <dd>
        <p class="toggle_text" id="transcripts_text">There $plural_1  $count $plural_2 in this region:</p>
        <table class="toggle_table" id="transcripts" summary="List of transcripts for this region - along with translation information and type">
        <tr>
          <th>Name</th>
          <th>Transcript ID</th>
          <th>Protein ID</th>
          <th>Description</th> 
        </tr>
    );
 
    foreach (
      map { $_->[2] }
      sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } 
      map { [$_->external_name, $_->stable_id, $_] }
      @$transcripts
    ) {
 #     warn "T: ", join ' * ', $_->stable_id, $_->biotype, $_->analysis->logic_name;

      my $transcript = CGI::escapeHTML( $_->stable_id );
      #my $transcript = sprintf '<a href="%s">%s</a>',
      #  $self->object->_url({
      #  'type'   => 'Transcript',
      #  'action' => 'Summary',
      #  't'      => $_->stable_id
      #  }),
      #  CGI::escapeHTML( $_->stable_id );
 
      my $protein = 'No protein product';
      if ($_->translation) {
        $protein = 'LRG Protein';
        #$protein = sprintf '<a href="%s">%s</a>',
        #$self->object->_url({
        #  'type'   => 'Transcript',
        #  'action' => 'ProteinSummary',
        #  't'      => $_->stable_id
        #  }),
	      #  'LRG Protein'; #CGI::escapeHTML( $_->translation->stable_id );
      }
      $html .= sprintf( '
        <tr%s>      
          <th>%s</th>
          <td>%s</td>
          <td>%s</td>
          <td>%s</td>
        </tr>',
        $_->stable_id eq $transcript ? ' class="active"' : '',
        CGI::escapeHTML( $_->display_xref ? $_->display_xref->display_id : '-' ),
        $transcript,
	      $protein,
		       'Fixed transcript for reporting purposes'
#	    $_->biotype
      );
    }
    $html .= '</table>';
    $html .= '
        </dd>
      </dl>';
  }
  return $html;
}

1;
