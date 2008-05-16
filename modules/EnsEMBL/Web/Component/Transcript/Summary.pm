package EnsEMBL::Web::Component::Transcript::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';

## Grab the description of the object...

  my $description = escapeHTML( $object->trans_description() );
  if( $description ) {
    $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/EC_URL($object,$1)/e;
    $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
    my($edb, $acc) = ($1, $2);
    $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if $acc;

    $html .= qq(
    <p>
      $description
    </p>);
  }

## Now a link to location;

  my $location_html = sprintf( '<a href="/%s/Location/View?r=%s:%s-%s">%s: %s-%s</a> %s',
    $object->species,
    $object->seq_region_name,
    $object->seq_region_start,
    $object->seq_region_end,
    $object->neat_sr_name( $object->seq_region_type, $object->seq_region_name ),
    $object->thousandify( $object->seq_region_start ),
    $object->thousandify( $object->seq_region_end ),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
  
  $html .= qq(
    <dl class="summary">
      <dt>Location</dt>
      <dd>
        $location_html
      </dd>
    </dl>);

## Now create the gene and transcript information...
 
  my $gene = $object->core_objects->gene;
  my $gene_id = $gene->stable_id;
  my $gene_url = $object->_url({
   'type'    => 'Gene',
   'action'  => 'Summary',
   'g'       => $gene_id
  });
  my $transcripts = $gene->get_all_Transcripts;
  my $count = @$transcripts;
  if( $count > 1 ) { 
    $html .= qq(
    <dl class="summary">
      <dt>Gene</dt>
      <dd>
        <p id="transcripts_text">This transcript is a product of gene <a href=$gene_url>$gene_id</a> - There are $count transcripts in this gene: </p>
       <table id="transcripts" style="display:none">);
    foreach( sort { $a->stable_id cmp $b->stable_id } @$transcripts ) {
      my $url = $object->_url({
         'type'   => 'Transcript',
         'action' => 'Summary',
         't'      => $_->stable_id
      }); 
      $html .= sprintf( '
          <tr%s>
      <th>%s</th>
      <td><a href="%s">%s</a></td>
    </tr>',
  $_->stable_id eq $object->stable_id ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id
      );
    }
    $html .= '
       </table>
     </dd>
    </dl>';  
  } else {
    $html .= qq(
    <dl class="summary">
      <dt>Gene</dt>
      <dd>
        <p id="gene_text">This transcript is a product of gene <a href=$gene_url>$gene_id</a></p>
      </dd>
    </dl>);

  }

## Now add the protein information...

  my $translation = $object->translation_object;
  my $protein = $translation->stable_id;
  $html .= qq(
    <dl class="summary">
      <dt>Protein</dt>
      <dd>
        <p id="gene_text">$protein is the protein product of this transcript</p>
      </dd>
    </dl>);


  
  return  $html;
}

1;
