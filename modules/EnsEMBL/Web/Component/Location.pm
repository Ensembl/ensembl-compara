package EnsEMBL::Web::Component::Location;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Document::SpreadSheet;
use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Component);

sub has_image {
  my $self = shift;
  $self->{'has_image'} = shift if @_;
  return $self->{'has_image'} || 0;
}

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
  my @has_synteny  = sort keys %synteny;
  my $sp;

  # Set default as primary species, if available
  unless ($species eq $primary_sp) {
    foreach my $sp (@has_synteny) {
      return $sp if $sp eq $primary_sp;
    }
  }

  # Set default as secondary species, if primary not available
  unless ($species eq $secondary_sp) {
    foreach $sp (@has_synteny) {
      return $sp if $sp eq $secondary_sp;
    }
  }

  # otherwise choose first in list
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

## POINTERS FOR VERTICAL DRAWING CODE

sub pointer_default {
  my ($self, $feature_type) = @_;
  
  my %hash = (
      'DnaAlignFeature'     => [ 'red', 'rharrow' ],
      'ProteinAlignFeature' => [ 'red', 'rharrow' ],
      'RegulatoryFactor'    => [ 'red', 'rharrow' ],
      'ProbeFeature'        => [ 'red', 'rharrow' ],
      'Xref'                => [ 'red', 'rharrow' ],
      'Gene'                => [ 'blue','lharrow' ]
  );
  
  return $hash{$feature_type};
}

# Adds a set of userdata pointers to vertical drawing code
sub create_user_set {
  my ($self, $image, $colours, $non_user_tracks) = @_;
  my $object = $self->object;
  my $hub = $self->hub;

  my $user = $hub->user;
  my $image_config = $hub->get_imageconfig('Vkaryotype');
  my $pointers = [];

  # Key to track colours
  my $has_table;
  my $table =  new EnsEMBL::Web::Document::SpreadSheet([], [], { 'width' => '500px', 'margin' => '1em 0px' });
  
  $table->add_columns(
    {'key' => 'colour', 'title' => 'Track colour', 'align' => 'center' },
    {'key' => 'track',  'title' => 'Track name',   'align' => 'center' },
  );

  my $i = 0;

  foreach my $key (keys %{$image_config->{'_tree'}{'_user_data'}}) {
    $i = 0 if $i > scalar(@$colours) - 1; # reset if we have loads of tracks (unlikely)
    
    my $track = {};
    my ($status, $type, $id) = split '-', $key;
    my $details = $image_config->get_node($key);
    my $display = $details->{'_user_data'}{$key}{'display'};
    my ($render, $style) = split '_', $display;
    
    next if (!$display || $display eq 'off');
    $has_table = 1;

    ## Create pointer configuration
    my $tracks = $hub->get_tracks($key);
    while (my ($key, $track) = each (%$tracks)) {
      my $colour; 
      if ($track->{'config'} && $track->{'config'}{'color'}) {
        $colour = $track->{'config'}{'color'};
      }
      else {
        $colour = $colours->[$i];
        $i++;
      }
        
      if ($render eq 'highlight') {
        push @$pointers, $image->add_pointers( $hub, {
          'config_name'   => 'Vkaryotype',
          'features'      => $track->{'features'},          
          'color'         => $colour,
          'style'         => $style,
        });
      }
      if ($has_table) {
        ## Create key entry
        my $label = $key;
        if ($key eq 'default') {
          $label = $track->{'config'}{'name'};
        }
        my $swatch = '<img src="/i/blank.gif" style="width:30px;height:15px;background-color:';
        if ($colour =~ /^[a-z0-9]{6}$/i) {
          $colour = '#'.$colour;
        }
        $swatch .= $colour.'" title="'.$colour.'" />';
        $table->add_row({'colour' => $swatch, 'track' => $label});
      }
    }
  }
  
  my $data_type = $hub->param('ftype');  
  if( $data_type =~ 'Xref')
  {    
    $has_table = 1;    
    my $hash;
    
    foreach my $row (@$non_user_tracks){             
      my $style = $row->{'style'};
      
      #the right hand arrow is xref and is red
      my $label = ($style eq 'rharrow') ? "Xref" : "Gene";
      $hash->{$label} = ($style eq 'rharrow') ? "red" : "blue";     #using hash to remove duplicate when there are more than 1 xref and genes      

      push @$pointers, $image->add_pointers( $hub, {
          'config_name'   => 'Vkaryotype',
          'features'      => [],
          'color'         => $hash->{$label},
          'style'         => $style,
        });        
                
        my $swatch = '<img src="/i/blank.gif" style="width:30px;height:15px;background-color:';
        $swatch .= $hash->{$label}.'" title="'.$hash->{$label}.'" />';
        $table->add_row({'colour' => $swatch, 'track' => $label});
      }      
   }            
  ## delete table if no tracks turned on
  $table = undef unless $has_table;
  
  return ($pointers, $table );
}

1;