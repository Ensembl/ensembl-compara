# $Id$

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

  # Haplotype/PAR locations
  my $alt_locs = $object->get_alternative_locations;
  if( @$alt_locs ) {
    $location_html .= qq(
          <p> This gene is mapped to the following HAP/PARs:</p>
          <ul>);
    foreach my $loc (@$alt_locs){
      my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
      $location_html .= sprintf( qq(
                                 <li>
                                 <a href="/%s/Location/View?l=%s:%s-%s">%s : %s-%s</a>
                                 </li>), $object->species, $altchr, $altstart, $altend, $altchr,
		       $object->thousandify( $altstart ),
		       $object->thousandify( $altend ));
    }
    $location_html .= "\n    </ul>";
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
  my $plural_1 = "are";
  my $plural_2 = "transcripts"; 
  if( $count == 1  ) {
    $plural_1 = "is"; 
    $plural_2 =~s/s$//; 
  }

  my $transcript = $object->core_objects->{'parameters'}{'t'};
  $html .= qq(
    <dl class="summary">
      <dt>Transcripts</dt>
      <dd>
        <p class="toggle_text" id="transcripts_text">There $plural_1  $count $plural_2 in this gene:</p>
        <table class="toggle_table" id="transcripts" summary="List of transcripts for this gene - along with translation information and type">
        <tr>
          <th>Name</th>
          <th>Transcript ID</th>
          <th>Protein ID</th>
          <th>Description</th> 
        </tr>
  );
 
  foreach(
    map { $_->[2] }
    sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } 
    map { [$_->external_name, $_->stable_id, $_] }
    @$transcripts
  ){
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
      </table>';
  $html .= '
    </dd>
  </dl>';
  my $site_type = $object->species_defs->ENSEMBL_SITETYPE;
  $html .= $self->_hint( 'gene', 'Transcript and Gene level displays',
   qq(
  <p>
In $site_type a gene is made up of one or more transcripts. We provide displays at two levels:
</p>
<ul>
  <li>Transcript views which provide information specific to an individual transcript such as the cDNA and CDS sequences and protein domain annotation.</li>
  <li>Gene views which provide displays for data associated at the gene level such as orthologues and paralogues, regulatory regions and splice variants.</li>
</ul>
<p>
This view is a gene level view. To access the transcript level displays select a Transcript ID in the table above and then navigate to the information you want using the menu at the left hand side of the page.  To return to viewing gene level information click on the Gene tab in the menu bar at the top of the page.
</p>) );
  return $html;
}

1;
