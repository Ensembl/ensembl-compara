package EnsEMBL::Web::Component::Gene::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

## Grab the description of the object...

  my $html = '';
  my $description = escapeHTML( $object->gene_description() );
  if( $description ) {
    $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
    $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
    my($edb, $acc) = ($1, $2);
    $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if $acc;

    $html .= qq(
    <p>
      $description
    </p>);
  }

## Now a link to location;

  my $url = $self->object->_url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end
  });

  my $location_html = sprintf( '<a href="%s">%s: %s-%s</a>%s',
    $url,
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

## Now create the transcript information...
  my $transcripts = $object->Obj->get_all_Transcripts;
  my $count = @$transcripts;
  if( $count > 1 ) {
    my $transcript = $object->core_objects->{'parameters'}{'t'};
    $html .= qq(
    <dl class="summary">
      <dt>Transcripts</dt>
      <dd>
        <p id="transcripts_text">There are $count transcripts in this gene:</p>
        <table id="transcripts" style="display:none">);
    foreach( sort { $a->stable_id cmp $b->stable_id } @$transcripts ) {
      my $url = $self->object->_url({
        'type'   => 'Transcript',
        'action' => 'Summary',
        't'      => $_->stable_id
      });
      $html .= sprintf( '
          <tr%s>
            <th>%s</th>
            <td><a href="%s">%s</a></td>
          </tr>',
        $_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id
      );
    }
    $html .= '
        </table>
      </dd>
    </dl>';
  }
  return $html;
}

1;
