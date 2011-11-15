# $Id$

package EnsEMBL::Web::Component::Location;

use strict;

use Digest::MD5 qw(md5_hex);

use Sanger::Graphics::ColourMap;

use base qw(EnsEMBL::Web::Component);

sub _configure_display {
  my ($self, $message) = @_;
  
  $message = sprintf 'You currently have %d tracks on the display turned off', $message if $message =~ /^\d+$/;
  
  return $self->_info(
    'Configuring the display',
    qq{<p>$message. To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>}
  );
}

# TODO: Needs moving to viewconfig so we don't have to work it out each time
sub default_otherspecies {
  my $self         = shift;
  my $object       = $self->object;
  my $species_defs = $object->species_defs;
  my $species      = $object->species;
  my $primary_sp   = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  my $secondary_sp = $species_defs->ENSEMBL_SECONDARY_SPECIES;
  my %synteny      = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');

  return $primary_sp if  ($synteny{$species}->{$primary_sp});

  return $secondary_sp if  ($synteny{$species}->{$secondary_sp});

  my @has_synteny  = sort keys %{$synteny{$species}};
  return $has_synteny[0];
}

# Method to create an array of chromosome names for use in dropdown lists
sub chr_list {
  my $self = shift;
  
  my @all_chr = @{$self->object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chrs;
  
  push @chrs, { 'name' => $_, 'value' => $_ } for @all_chr;
  
  return @chrs;
}

##---------------------------------------------------------------------------------------

## USER DATA DISPLAYS ON VERTICAL DRAWING CODE

sub cell_style {my $self = shift; return 'padding:4px 10px';}

sub pointer_default {
  my ($self, $feature_type) = @_;
  
  my %hash = (
        DnaAlignFeature     => [ 'rharrow', 'red' ],
        ProteinAlignFeature => [ 'rharrow', 'red' ],
        RegulatoryFactor    => [ 'rharrow', 'red' ],
        ProbeFeature        => [ 'rharrow', 'red' ],
        Xref                => [ 'rharrow', 'red' ],
        Gene                => [ 'lharrow', 'orange'],
        Transcript          => [ 'lharrow', 'blue'],
        Domain              => [ 'lharrow', 'blue' ],
        Variation           => [ 'rharrow', 'gradient', [qw(90 #0000FF #770088 #BB0044 #CC0000)]],
  );
  
  return $hash{$feature_type};
}

## Create a set of highlights from a userdate set
sub create_user_pointers {
  my ($self, $image, $data) = @_;
  my $hub          = $self->hub;
  my $image_config = $hub->get_imageconfig('Vkaryotype');
  my @pointers     = ();

  while (my ($key, $hash) = each %$data) {
    my $display = $image_config->get_node($key)->get('display');
    
    while (my ($analysis, $track) = each %$hash) {
      my ($render, $style) = split '_', $display;
      my $colour = $self->_user_track_colour($track); 

      if ($render eq 'highlight') {
        push @pointers, $image->add_pointers($hub, {
          config_name => 'Vkaryotype',
          features    => $track->{'features'},          
          color       => $colour,
          style       => $style,
        });
      }
    }
  }
  
  return @pointers;
}

sub configure_UserData_table {
  my ($self, $image_config) = @_;
  my $header       = 'Key to user tracks';
  my $column_order = [qw(colour track)];
  my @rows;
  
  foreach (grep $_->get('display') ne 'off', $image_config->get_node('user_data')->nodes) {
    my $colour = $_->get('colour');
    my $label  = $_->get('caption');
    
    if ($colour =~ /,/) {
      $colour = '#' . Sanger::Graphics::ColourMap::hex_by_rgb(undef, [ split ',', $colour ]); ## Convert RGB colours to hex, because rgb attributes getting stripped out of HTML
    } elsif ($colour =~ /^[0-9a-f]{6}$/i) { 
      $colour = "#$colour"; ## Hex with no initial hash symbol
    }
      
    my $swatch = qq{<span style="width:30px;height:15px;display:inline-block;background-color:$colour" title="$colour"></span>};
      
    push @rows, {
      colour => { value => $swatch, style => $self->cell_style },
      track  => { value => $label,  style => $self->cell_style },
    };
  }
  
  return { header => $header, column_order => $column_order, rows => \@rows };
} 

sub _user_track_colour {
  my ($self, $track) = @_;
  return $track->{'config'} && $track->{'config'}{'color'} ? $track->{'config'}{'color'} : 'black';      
}

1;
