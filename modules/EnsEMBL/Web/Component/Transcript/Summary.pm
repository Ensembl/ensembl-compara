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

  return '<p>This transcript is not in the current gene set</p>' unless $object->Obj->isa('Bio::EnsEMBL::Transcript');

## Grab the description of the object...

  my $html = '';
  my $description = escapeHTML( $object->trans_description() );

  my ($edb,$acc);
  if( $description ) {
    if ($description ne 'No description') {
      if ($object->get_db eq 'vega') {
        $edb = 'Vega';
        $acc = $object->Obj->stable_id;
        $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb", $edb.'_transcript', $acc) ]}</span>);
      }
      else {
        $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
        $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
        ($edb, $acc) = ($1, $2);
        $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if ($acc ne 'content') ;
      }
      $html .= qq(
      <p>
        $description
      </p>);
    }
  }

## Now a link to location;

  my $location_html = sprintf( '<a href="/%s/Location/View?r=%s:%s-%s">%s: %s-%s</a> %s.',
    $object->species,
    $object->seq_region_name,
    $object->seq_region_start,
    $object->seq_region_end,
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

## Now create the gene and transcript information...

  my $gene = $object->core_objects->gene; 
if( $gene ) {
  my $gene_id = $gene->stable_id;
  my $gene_url = $object->_url({
   'type'    => 'Gene',
   'action'  => 'Summary',
   'g'       => $gene_id
  });
  my $transcripts = $gene->get_all_Transcripts;
  my $transcript = $object->stable_id;
  my $count = @$transcripts;
  if( $count > 1 ) { 
    $html .= qq(
    <dl class="summary">
      <dt>Gene</dt>
      <dd>
        <p id="transcripts_text">This transcript is a product of gene <a href="$gene_url">$gene_id</a> - There are $count transcripts in this gene: </p>
       <table id="transcripts" summary="List of transcripts for this gene - along with translation information and type">);
    foreach(
      map { $_->[2] }
      sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
      map { [$_->external_name, $_->stable_id, $_] }
      @$transcripts
    ) {
      my $url = $self->object->_url({
        'type'   => 'Transcript',
        't'      => $_->stable_id
      });
      my $protein = 'No protein product';
      if( $_->translation ) {
        $protein = sprintf '<a href="%s">%s</a>',
          $self->object->_url({
            'type'   => 'Transcript',
            'action' => 'Protein',
            't'      => $_->stable_id
          }),
          $_->translation->stable_id ;
      }
      $html .= sprintf( '
          <tr%s>
            <th>%s</th>
            <td><a href="%s">%s</a></td>
            <td>%s</td>
            <td>%s</td>
          </tr>',
        $_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id,
        $protein,
        $_->biotype
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
        <p id="gene_text">This transcript is a product of gene <a href="$gene_url">$gene_id</a></p>
      </dd>
    </dl>);

  }

  if( $count == 1 ) {
    ## Now add the protein information...
    $html .= qq(
    <dl class="summary">
    <dt>Protein</dt>
    <dd>);
    if (my $translation = $object->translation_object) {
      my $protein = sprintf ('<a href="%s">%s</a>', $self->object->_url({ 'action' => 'Protein'}), $translation->stable_id );
        $html .= qq(<p id="prot_text">$protein is the protein product of this transcript</p>);
      } else {
        $html .= qq(<p id="prot_text">This transcript has no translation</p>);
      }
    $html .= qq(</dd> </dl>);
  }
}
  return  $html;
}

1;
