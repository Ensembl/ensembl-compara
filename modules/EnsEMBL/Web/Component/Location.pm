package EnsEMBL::Web::Component::Location;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::SpreadSheet;

use base 'EnsEMBL::Web::Component';

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
  my $self = shift;
  my $sd = $self->object->species_defs;
  my %synteny = $sd->multi('DATABASE_COMPARA', 'SYNTENY');
  my @has_synteny = sort keys %synteny;
  my $sp;

  # Set default as primary species, if available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_PRIMARY_SPECIES) {
    foreach my $sp (@has_synteny) {
      return $sp if $sp eq $sd->ENSEMBL_PRIMARY_SPECIES;
    }
  }

  # Set default as secondary species, if primary not available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_SECONDARY_SPECIES) {
    foreach $sp (@has_synteny) {
      return $sp if $sp eq $sd->ENSEMBL_SECONDARY_SPECIES;
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
      'XRef'                => [ 'red', 'rharrow' ],
      'Gene'                => [ 'blue','lharrow' ]
  );
  
  return $hash{$feature_type};
}

sub colour_array {
  return [qw(red blue green purple orange grey brown magenta darkgreen darkblue violet darkgrey)];
}

# Adds a set of userdata pointers to vertical drawing code
sub create_user_set {
  my ($self, $image, $colours) = @_;
  my $object = $self->object;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $image_config = $object->get_session->getImageConfig('Vkaryotype');
  my $pointers = [];

  # Key to track colours
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
    
    next if $display eq 'off';

    if ($render eq 'highlight') {
      ## Create pointer configuration
      my $tracks = $object->get_tracks($key);
      while (my ($label, $track) = each (%$tracks)) {
        my $colour; 
        if ($track->{'config'} && $track->{'config'}{'color'}) {
          $colour = $track->{'config'}{'color'};
        }
        else {
          $colour = $colours->[$i];
          $i++;
        }
        push @$pointers, $image->add_pointers( $object, {
          'config_name'   => 'Vkaryotype',
          'features'      => $track->{'features'},
          'color'         => $colour,
          'style'         => $style,
        });
      }

      ## Add to key
      #my $label = $data->{'label'};
      #$table->add_row({
      #  'colour' => qq(<span style="background-color:$colour;color:#ffffff;padding:2px"><img src="/i/blank.gif" style="width:30px;height:10px" alt="[$colour]" /></span>),
      #  'track' => $label,
      #});
    }
    else {
      ## TODO - add density tracks to table
    }
  }

  return ($pointers, $table);
}

# --------------------- OLD FUNCTIONS ---------------------

sub ldview_nav {
  my ($pops_on, $pops_off) = $_[1]->current_pop_name;
  my $pop;
  
  map { $pop .= "opt_pop_$_:on;" } @$pops_on;
  map { $pop .= "opt_pop_$_:off;" } @$pops_off;

  return bottom_nav(@_, 'ldview', {
    'snp'    => $_[1]->param('snp') || undef,
    'gene'   => $_[1]->param('gene') || undef,
    'bottom' => $pop || undef,
    'source' => $_[1]->param('source'),
    'h'      => $_[1]->highlights_string || undef,
  });    
}

1;
