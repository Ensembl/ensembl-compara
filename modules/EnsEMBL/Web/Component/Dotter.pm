package EnsEMBL::Web::Component::Dotter;

# outputs chunks of XHTML for protein domain-based displays

use EnsEMBL::Web::Component;
our @ISA = qw(EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::File::Image;
use Bio::Dotter::Matrix;

sub dotter_error {
  my( $panel, $object ) = @_;
  $panel->print(qw(<p>Error we do not have two slices</p>));
  return 1;
}

sub dotterview {
  my( $panel, $object ) = @_;
  my( $primary_loc, $secondary_loc ) = $object->Locations;
  my $dotter_bin_file = $object->generate_dotter_bin_file( $object->param('w')/500 );
  my $dotter = new Bio::Dotter::Matrix( {
    'ref'        => $primary_loc,
    'hom'        => $secondary_loc,
    'threshold'  => $object->param( 't' ),
    'usegrid'    => $object->param( 'g' ),
    'usehsp'     => $object->param( 'h' ),
    'size'       => $object->param( 'w' ),
## General display options...
    'h_border'   => 160,
    'v_border'   => 160,
    'dotter_bin_file' => $dotter_bin_file
  });
  my $img = new EnsEMBL::Web::File::Image( $object->species_defs );
     $img->set_tmp_filename();
     $img->{'img_map'} = 1;
     $img->dc = $dotter;
  my $T = $img->render_image_tag;
  $panel->print( $img->render_image_tag );
  $panel->print( $img->render_image_map );
  unlink( $dotter_bin_file );
  return 1;
}

1;
