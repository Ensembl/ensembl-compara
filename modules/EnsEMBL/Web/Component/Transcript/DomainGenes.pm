package EnsEMBL::Web::Component::Transcript::DomainGenes;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  my $accession = $self->object->param('domain');
  if ($accession) {
    return "Other genes with domain $accession";
  }
  else {
    return undef;
  }
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  return unless $object->param('domain');
  my $genes   = $object->get_domain_genes;
  return unless( @$genes );
  
  my $html;

  ## Karyotype showing genes associated with this domain (optional)
  if (@{$object->species_defs->ENSEMBL_CHROMOSOMES}) {

    $object->param('aggregate_colour', 'red'); ## Fake CGI param - easiest way to pass this parameter
    my $wuc   = $object->get_imageconfig( 'Vkaryotype' );
    my $image = $object->new_karyotype_image();
    $image->image_type = 'domain';
    $image->image_name = "$species-".$object->param('domain');
    $image->imagemap = 'yes';
    my %high = ( 'style' => 'arrow' );
    foreach my $gene (@$genes){
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $colour    = $stable_id eq $object->core_objects->gene->stable_id ? 'red' : 'blue';
      my $point = {
        'start' => $gene->seq_region_start,
        'end'   => $gene->seq_region_end,
        'col'   => $colour,
        'href'  => $object->url("/$species/Gene/Summary?g=$stable_id"),
      };
      if(exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    $image->set_button('drag');
    $image->karyotype( $object, [\%high] );
    $html .= '<div style="margin-top:10px">'.$image->render.'</div>';
  }

  ## Now do table
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

  $table->add_columns(
    { 'key' => 'id',   'title' => 'Gene',                  'width' => '30%', 'align' => 'center' },
    { 'key' => 'loc',  'title' => 'Genome Location',       'width' => '20%', 'align' => 'left' },
    { 'key' => 'desc', 'title' => 'Description(if known)', 'width' => '50%', 'align' => 'left' }
  );
  foreach my $gene ( sort { $object->seq_region_sort( $a->seq_region_name, $b->seq_region_name ) ||
                            $a->seq_region_start <=> $b->seq_region_start } @$genes ) {
    my $row = {};
    my $xref_id;
    if ($gene->display_xref) {
	$xref_id = $gene->display_xref->display_id;
    }
    else { $xref_id = '-novel-';}
    $row->{'id'} = sprintf '<a href="/%s/Gene/Summary?g=%s">%s</a><br />(%s)',
	$object->species, $gene->stable_id, $gene->stable_id, $xref_id;

    my $readable_location =  sprintf(qq(%s: %s),
      $self->neat_sr_name( $gene->slice->coord_system->name, $gene->slice->seq_region_name ),
      $self->round_bp( $gene->start )
    );
    $row->{'loc'}  = sprintf '<a href="/%s/Location/View?g=%s">%s</a>',
                             $object->species, $gene->stable_id, $readable_location;
    my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
    $row->{'desc'} = $gene->description || $description_by_type{ $gene->biotype } || 'No description';
    $table->add_row( $row );
  }
  $html .= $table->render;

  return $html;
}

1;

