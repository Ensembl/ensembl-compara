# $Id$

package EnsEMBL::Web::Component::Location::Compara_AlignSliceBottom;

use strict;

use base qw(EnsEMBL::Web::Component::Location EnsEMBL::Web::Component::Compara_Alignments);

use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $threshold = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $align_params = $object->param('align');
  my ($align,$target_slice_name);
  ($align,undef,$target_slice_name) = split '--', $align_params;
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  return $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>') unless $align;
  
  my $align_details = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'}->{$align};

  return $self->_error('Unknown alignment', '<p>The alignment you have select does not exist in the current database.</p>') unless $align_details;
  
  my $primary_species = $object->species;
  
  if (!exists $align_details->{'species'}->{$primary_species}) {
    return $self->_error('Unknown alignment', sprintf(
      '<p>%s is not part of the %s alignment in the database.</p>', 
      $object->species_defs->species_label($primary_species),
      escapeHTML($align_details->{'name'})
    ));
  }
  
  my $image_width = $self->image_width;
  my $slice = $object->slice;
  my ($slices) = $self->get_slices($object, $slice, $align_params, $primary_species);
  
  my @skipped;
  my @missing;
  my @images;
  my $i = 1;
  my $html;
  my $info;
  
  if ($align_details->{'class'} !~ /pairwise/) {
    my %aligned_species = map { $_->{'name'} => 1 } @$slices;
    
    foreach (keys %{$align_details->{'species'}}) {
      next if /^($primary_species|merged)$/;
      
      push @skipped, $_ if ($object->param(sprintf 'species_%d_%s', $align, lc)||'off') eq 'off';
      push @missing, $_ unless $aligned_species{$_} || $_ eq 'Ancestral_sequences';
    }
  }
  
  foreach (@$slices) {
    my $image_config = $object->image_config_hash('alignsliceviewbottom_' . $i, 'alignsliceviewbottom', $_->{'name'});
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width || 800, # hack at the moment
      slice_number    => "$i|3",
      compara         => $i == 1 ? 'primary' : 'secondary'
    });
    
    my ($species_name,$slice_name) = split ':',$_->{'display_name'};
    my $panel_caption = $object->species_defs->get_config($species_name, 'SPECIES_COMMON_NAME') || 'Ancestral sequences';
    $panel_caption .= " $slice_name" if $slice_name;

    $image_config->get_node('alignscalebar')->set('caption', $panel_caption);
    
    push @images, $_->{'slice'}, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  $html .= $image->render;
  
  if (scalar @skipped) {
    $info .= sprintf(
      '<p>The following %d species in the alignment are not shown in the image. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>', 
      scalar @skipped, 
      join "</li>\n<li>", sort map $object->species_defs->species_label($_), @skipped
    );
  }
  
  if (scalar @missing) {
    $info .= sprintf(
      '<p>The following %d species have no alignment in this region:<ul><li>%s</li></ul></p>', 
      scalar @missing, 
      join "</li>\n<li>", sort map $object->species_defs->species_label($_), @missing
    );
  }
  
  $html .= $self->_info('Notes', $info) if $info;
  
  return $html;
}

1;
