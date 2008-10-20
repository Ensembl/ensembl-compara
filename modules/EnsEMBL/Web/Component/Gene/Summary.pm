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

warn ref($object->Obj );
  if( $object->Obj->isa('Bio::EnsEMBL::Compara::Family' ) ){
    return sprintf '<p>%s</p>', CGI::escapeHTML( $object->Obj->description );
  } # elsif( $object->Obj->isa('Bio::EnsEMBL::ID
  if( $object->Obj->isa('Bio::EnsEMBL::ArchiveStableId' ) ){
    return sprintf '<p>%s</p>', 'This identifier is not in the current EnsEMBL database';
  }
  my $html = '';
  my($edb, $acc);
  my $description = escapeHTML( $object->gene_description() );
  if( $description ) {
    if ($description ne 'No description') {
      if ($object->get_db eq 'vega') {
        $edb = 'Vega';
        $acc = $object->Obj->stable_id;
        $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb", $edb.'_gene', $acc) ]}</span>);
      }
      else {
        $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
        $description =~ s/\[\w+:([-\w\/]+)\;\w+:(\w+)\]//g;
        ($edb, $acc) = ($1, $2);
	my $link = $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc);
        $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if ($acc ne 'content');
      }
      $html .= qq(
      <p>
        $description
      </p>);
    }
  }

## Now a link to location;

  my $url = $self->object->_url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end
  });

  my $location_html = sprintf( '<a href="%s">%s: %s-%s</a> %s.',
    $url,
    $object->neat_sr_name( $object->seq_region_type, $object->seq_region_name ),
    $object->thousandify( $object->seq_region_start ),
    $object->thousandify( $object->seq_region_end ),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );

  # alternative (Vega) coordinates
  my $lc_type  = lc( $object->type_name );
  my $alt_assembly = $object->species_defs->ALTERNATIVE_ASSEMBLY;
  if ( $alt_assembly and $object->get_db eq 'vega' ) {
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg = "Bio::EnsEMBL::Registry";
    my $orig_group = $reg->get_DNAAdaptor($object->species, "vega")->group;
    $reg->add_DNAAdaptor($object->species, "vega", $object->species, "vega");
    # project feature slice onto Vega assembly
    my $alt_slices = $object->vega_projection($alt_assembly);
    # link to Vega if there is an ungapped mapping of whole gene
    if ((scalar(@$alt_slices) == 1) && ($alt_slices->[0]->length == $object->feature_length) ) {
      my $l = $alt_slices->[0]->seq_region_name.":".$alt_slices->[0]->start."-".$alt_slices->[0]->end;
      my $url = $object->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
      $location_html .= qq( [<span class="small">This corresponds to );
      $location_html .= sprintf(qq(<a href="%s" target="external">%s-%s</a>),
				$url,
				$object->thousandify($alt_slices->[0]->start),
				$object->thousandify($alt_slices->[0]->end)
			    );
      $location_html .= " in $alt_assembly coordinates</span>]";
  } else {
    $location_html .= qq( [<span class="small">There is no ungapped mapping of this $lc_type onto the $alt_assembly assembly</span>]);
  }
    # set dnadb back to the original group
    $reg->add_DNAAdaptor($object->species, "vega", $object->species, $orig_group);
  }

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
        <table id="transcripts" summary="List of transcripts for this gene - along with translation information and type">);
    foreach(
      map { $_->[2] }
      sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } 
      map { [$_->external_name, $_->stable_id, $_] }
      @$transcripts
    ) {
      my $url = $self->object->_url({
        'type'   => 'Transcript',
        'action' => 'Summary',
        't'      => $_->stable_id
      }); 
      my $protein = 'No protein product';
      if( $_->translation ) {
        $protein = sprintf '<a href="%s">%s</a>',
          $self->object->_url({
            'type'   => 'Transcript',
            'action' => 'ProteinSummary',
            't'      => $_->stable_id
          }),
	  CGI::escapeHTML( $_->translation->stable_id );
      }
      $html .= sprintf( '
          <tr%s>
            <th>%s</th>
            <td><a href="%s">%s</a></td>
            <td>%s</td>
            <td>%s</td>
          </tr>',
        $_->stable_id eq $transcript ? ' class="active"' : '',
        CGI::escapeHTML( $_->display_xref ? $_->display_xref->display_id : 'Novel' ),
        $url,
        CGI::escapeHTML( $_->stable_id ),
	$protein,
	$_->biotype
      );
    }
    $html .= '
        </table>
      </dd>
    </dl>';
  } else {
    my $transcript = @$transcripts[0];
    my $display;
    eval {
	$display = $transcript->display_xref->display_id || $transcript->stable_id;
    };
    my $id = $transcript->stable_id;
    $html .= qq(
    <dl class="summary">
      <dt>Transcripts</dt>
      <dd>
        <p id="transcripts_text">There is one transcript in this gene: );

    my $url = $self->object->_url({
      'type'   => 'Transcript',
      'action' => 'Summary',
      't'      => $transcript->stable_id
    });
 
    $html .= sprintf q(
       <a href="%s">%s</a> (<a href="%s">%s</a>)), $url, CGI::escapeHTML( $display), $url, CGI::escapeHTML( $id );
    if( $transcript->translation ) {
      $html .= sprintf ', with protein product <a href="%s">%s</a>', $self->object->_url({
        'type'   => 'Transcript',
        'action' => 'ProteinSummary',
        't'      => $transcript->stable_id
      }), CGI::escapeHTML( $transcript->translation->stable_id );
    }
       
    $html .= qq(.</p>
     </dd>
    </dl>
    );
  }
  return $html;
}

1;
