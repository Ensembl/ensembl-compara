package EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable(  1 );
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;
  my $species     = $object->species;
## Which alignment do we have...
  if( $object->length > $threshold ) {
    return $self->_warning( 'Region too large','
  <p>
    The region selected is too large to display in this view - use the navigation above to zoom in...
  </p>' );
  }
  my $align = $object->param( 'align' );
  ## Check that it exists!
  unless($align) {
    return $self->_info( 'No alignment specified',sprintf '
  <p>
    Select the alignment you wish to display from the box above.
  </p>' );

  }
  my $h = $object->species_defs->multi_hash->{DATABASE_COMPARA};
  my %c = exists $h->{'ALIGNMENTS'} ? %{$h->{'ALIGNMENTS'}} : ();
  if( !exists $c{$align} ) {
    return $self->_error( 'Unknown alignment',sprintf '
  <p>
    The alignment you have select "%s" does not exist in the current
    database.
  </p>',escapeHTML($align) );
  }

  my $align_details = $c{$align};
  if( !exists $align_details->{'species'}{$species} ) {
    return $self->_error( 'Unknown alignment',sprintf '
  <p>
    %s is not part of the %s alignment in the database.
  </p>', $object->species_defs->species_label($species), escapeHTML( $align_details->{'name'} )
    );
  }
  
  my $html = '';
  my @species = ();
  my @skipped = ();
  if( $align_details->{'class'} =~ /pairwise/ ) { ## This is a pairwise alignment
    foreach ( keys %{$align_details->{species}} ) {
      push @species,$_ unless $species eq $_;
    }
  } else { ## This is a multiway alignment
    foreach ( keys %{$align_details->{species}} ) {
      my $key = sprintf 'species_%d_%s', $align, lc($_);
      next if $species eq $_;
      if( $object->param($key) eq 'no' ) {
        push @skipped,$_;
      } else {
        push @species,$_;
      }
    }
  }
  $html .= $self->_info( "so far so good", "so far so good @species" );

  if( @skipped ) {
    $html .= $self->_warning( 'Species hidden by configuration', sprintf '
  <p>
    The following %d species in the alignment are not shown in the image: %s. Use the "<strong>Configure this page</strong>" on the left to show them.
  </p>%s', scalar(@skipped), join (', ', sort map { $object->species_defs->species_label($_) } @skipped )
    )
  }
  return $html;
}

1;
__END__
  my $slice = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $T = time;
  my $wuc = $object->image_config_hash( 'contigviewbottom' );
  $T = sprintf "%0.3f", time - $T;
  $wuc->tree->dump("View Bottom configuration [ time to generate $T sec ]", '([[caption]])')
    if $object->species_defs->ENSEMBL_DEBUG_FLAGS & $object->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $image_width || 800, ## hack at the moment....
    'slice_number'    => '1|3',
  });

## Lets see if we have any das sources....

## This is where we turn on tracks related to our alignment!
  $wuc->modify_configs( 
    [ "_".$object->param('align') ],
    [ 'display' => 'normal' ]
  );
#  warn "DAS SOURCES @das_sources";
  
  $wuc->_update_missing( $object );
  my $image    = $object->new_image( $slice, $wuc, $object->highlights );
     $image->{'panel_number'} = 'bottom';
     $image->imagemap = 'yes';

     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return $image->render;
}


1;
