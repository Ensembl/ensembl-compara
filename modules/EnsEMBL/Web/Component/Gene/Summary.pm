package EnsEMBL::Web::Component::Gene::Summary;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  # Grab the description of the object
  if ($object->Obj->isa('Bio::EnsEMBL::Compara::Family')) {
    return sprintf '<p>%s</p>', encode_entities($object->Obj->description);
  }
  
  if ($object->Obj->isa('Bio::EnsEMBL::ArchiveStableId')) {
    return sprintf '<p>%s</p>', 'This identifier is not in the current EnsEMBL database';
  }
  
  my $html = '';
  my $description = encode_entities($object->gene_description);
  my ($edb, $acc);
  
  if ($description) {
    if ($description ne 'No description') {
      if ($object->get_db eq 'vega') {
        $edb = 'Vega';
        $acc = $object->Obj->stable_id;
        $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb", $edb . '_gene', $acc);
      } else {
        $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
        $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:(\w+)\]//g;
        ($edb, $acc) = ($1, $2);
        $description .= sprintf ' <span class="small">%s</span>', $object->get_ExtURL_link("Source: $edb $acc", $edb, $acc) if $acc ne 'content';
      }
      
      $html .= "<p>$description</p>";
    }
  }

  # Now a link to location;
  my $url = $self->object->_url({
    type   => 'Location',
    action => 'View',
    r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
  });
  
  my $location_html = sprintf(
    '<a href="%s">%s: %s-%s</a> %s.',
    $url,
    $object->neat_sr_name($object->seq_region_type, $object->seq_region_name),
    $object->thousandify($object->seq_region_start),
    $object->thousandify($object->seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
  
  # alternative (Vega) coordinates
  my $lc_type      = lc $object->type_name;
  my $alt_assembly = $object->species_defs->ALTERNATIVE_ASSEMBLY;
  
  if ($alt_assembly && $object->get_db eq 'vega') {
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($object->species, 'vega')->group;
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, 'vega');

    my $alt_slices = $object->vega_projection($alt_assembly); # project feature slice onto Vega assembly
    
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l   = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      my $url = $object->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
      
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external">%s-%s</a>',
        $url,
        $object->thousandify($alt_slices->[0]->start),
        $object->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $alt_assembly coordinates</span>]";
    } else {
      $location_html .= qq{ [<span class="small">There is no ungapped mapping of this $lc_type onto the $alt_assembly assembly</span>]};
    }
    
    $reg->add_DNAAdaptor($object->species, 'vega', $object->species, $orig_group); # set dnadb back to the original group
  }

  # Haplotype/PAR locations
  my $alt_locs = $object->get_alternative_locations;
  
  if (@$alt_locs) {
    $location_html .= '
      <p> This gene is mapped to the following HAP/PARs:</p>
      <ul>';
    
    foreach my $loc (@$alt_locs){
      my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
      $location_html .= sprintf('
        <li><a href="/%s/Location/View?l=%s:%s-%s">%s : %s-%s</a></li>', 
        $object->species, $altchr, $altstart, $altend, $altchr,
        $object->thousandify($altstart),
        $object->thousandify($altend)
      );
    }
    
    $location_html .= '
      </ul>';
  }

  $html .= qq{
    <dl class="summary">
      <dt>Location</dt>
      <dd>
        $location_html
      </dd>
    </dl>
  };


  # Now create the transcript information
  my $transcripts = $object->Obj->get_all_Transcripts; 
  my $transcript  = $object->param('t');
  my $count       = @$transcripts;
  my $plural_1    = 'are';
  my $plural_2    = 'transcripts'; 
  
  if ($count == 1) {
    $plural_1 = 'is'; 
    $plural_2 =~ s/s$//; 
  }
  
  $html .= qq{
    <dl class="summary">
      <dt>Transcripts</dt>
      <dd>
        <p class="toggle_text" id="transcripts_text">There $plural_1 $count $plural_2 in this gene:</p>
        <table class="toggle_table" id="transcripts" summary="List of transcripts for this gene - along with translation information and type">
        <tr>
          <th>Name</th>
          <th>Transcript ID</th>
          <th>Length (bp)</th>
          <th>Protein ID</th>
          <th>Length (aa)</th>
          <th>Biotype</th> 
  };

  if ($object->species =~/^Homo|Mus/){
    $html .= "<th>CCDS</th>";
  } 

  $html .= "</tr>"; 

  foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
    my $transcript_length = $_->length;
    my $protein = 'No protein product';
    my $protein_length = 'N/A';
    
    my $url = $self->object->_url({
      type   => 'Transcript',
      action => 'Summary',
      t      => $_->stable_id
    });
    
    if ($_->translation) {
      $protein = sprintf(
        '<a href="%s">%s</a>',
        $self->object->_url({
          type   => 'Transcript',
          action => 'ProteinSummary',
          t      => $_->stable_id
        }),
        encode_entities($_->translation->stable_id)
      );
      $protein_length = $_->translation->length;
    }

    my $ccds = "N/A";
    if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$_->get_all_DBLinks} ) {
      my %T = map { $_->primary_id,1 } @CCDS;
      @CCDS = sort keys %T;
      $ccds = join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS;
    }  
   
    (my $biotype = $_->biotype) =~ s/_/ /g; 
    $html .= sprintf('
      <tr%s>      
        <th>%s</th>
        <td><a href="%s">%s</a></td>
        <td>%s</td>  
        <td>%s</td>
        <td>%s</td>
        <td>%s</td>',
      $count == 1 || $_->stable_id eq $transcript ? ' class="active"' : '',
      encode_entities($_->display_xref ? $_->display_xref->display_id : 'Novel'),
      $url,
      encode_entities($_->stable_id),
      $transcript_length,
      $protein,
      $protein_length,
      $self->glossary_mouseover(ucfirst($biotype), $_->biotype),
    );

    if ($object->species =~/^Homo|Mus/){
      $html .= "<td>$ccds</td>";
    }
    $html .= "</tr>";
  }
  
  $html .= '
      </table>
    </dd>
  </dl>';
  
  my $site_type = $object->species_defs->ENSEMBL_SITETYPE;
  
  $html .= $self->_hint('gene', 'Transcript and Gene level displays', "
    <p>In $site_type a gene is made up of one or more transcripts. We provide displays at two levels:</p>
    <ul>
      <li>Transcript views which provide information specific to an individual transcript such as the cDNA and CDS sequences and protein domain annotation.</li>
      <li>Gene views which provide displays for data associated at the gene level such as orthologues and paralogues, regulatory regions and splice variants.</li>
    </ul>
    <p>
      This view is a gene level view. To access the transcript level displays select a Transcript ID in the table above and then navigate to the information you want using the menu at the left hand side of the page.  
      To return to viewing gene level information click on the Gene tab in the menu bar at the top of the page.
    </p>"
  );

  return $html;
}

1;
