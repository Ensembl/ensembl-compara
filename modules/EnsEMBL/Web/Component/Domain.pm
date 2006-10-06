package EnsEMBL::Web::Component::Domain;

# outputs chunks of XHTML for protein domain-based displays

use EnsEMBL::Web::Component;
our @ISA = qw(EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub spreadsheet_geneTable {
  my( $panel, $object ) = @_;

  my $genes = $object->get_all_genes;
  return unless @$genes;
  $panel->add_columns( 
    { 'key' => 'id',   'title' => 'Gene ID',               'width' => '20%', 'align' => 'center' },
    { 'key' => 'name', 'title' => 'Gene Name',             'width' => '20%', 'align' => 'center' },
    { 'key' => 'loc',  'title' => 'Genome Location',       'width' => '20%', 'align' => 'left' },
    { 'key' => 'desc', 'title' => 'Description(if known)', 'width' => '40%', 'align' => 'left' }
  );
  foreach my $gene ( sort { $object->seq_region_sort( $a->seq_region_name, $b->seq_region_name ) ||
                            $a->seq_region_start <=> $b->seq_region_start } @$genes ) {
    my $row = {};
    $row->{'id'} = sprintf '<a href="/%s/geneview?gene=%s">%s</a>',
                 $object->species, $gene->stable_id, $gene->stable_id;
    my( $name, $source, $acc ) = $gene->display_xref;
    if( $name ) {
      $row->{'name'} = $object->get_ExtURL_link( $name, $source, $acc );
    } else {
      $row->{'name'} = '-novel-';
    }
    $row->{'loc'}  = sprintf '<a href="/%s/contigview?gene=%s">%s</a>', 
                             $object->species, $gene->stable_id, $gene->readable_location;
    $row->{'desc'} = $gene->gene_description;
    $panel->add_row( $row );
  }
  return 1;
}

sub karyotype_image {
  my( $panel, $data ) = @_;
  return 1 unless @{$data->species_defs->ENSEMBL_CHROMOSOMES};

  my $species = $data->species;    
    
  my $wuc   = $data->get_userconfig( 'Vkaryotype' );
  my $image = $data->new_karyotype_image();
  $image->cacheable  = 'yes';
  $image->image_type = 'domain';
  $image->image_name = "$species-".$data->domainAcc;
  $image->imagemap = 'yes';
  unless( $image->exists ) { 
    my $genes   = $data->get_all_genes;
    return unless( @$genes );
    my %high = ( 'style' => 'arrow' );
    foreach my $gene (@$genes){
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $point = {
        'start' => $gene->seq_region_start,
        'end'   => $gene->seq_region_end,
        'col'   => 'red',
        'zmenu' => {
          'caption'               => 'Genes',
          "00:$stable_id"         => "/$species/geneview?gene=$stable_id",
          '01:Jump to contigview' => "/$species/contigview?geneid=$stable_id"
        }
      };
      if(exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    my $ret = $image->karyotype( $data, [\%high] );
    if( $ret ) {
      warn $ret;
      return;
    }
  }
  $panel->add_row( 
    'Location of genes containing Interpro hit', $image->render
  );
  return 1;
}     

sub name {
  my( $panel, $data ) = @_;
  $panel->add_row(
    'Interpro name',
    "<p>@{[ $data->domainDesc ]}</p>"
  );
  return 1;
}

sub interpro_link {
  my( $panel, $data ) = @_;
  $panel->add_row(
    'Further information',
    qq(
   <p>
    Further information for domain @{[$data->get_ExtURL_link( $data->domainAcc, 'INTERPRO', $data->domainAcc )]}
    can be found on the InterPro website.
   </p>)
  );
  return 1;
}

1;    
