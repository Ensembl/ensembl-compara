=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Location;

use strict;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Draw::Utils::ColourMap;

use base qw(EnsEMBL::Web::Component::Shared);

sub _configure_display {
  my ($self, $message) = @_;
  
  $message = sprintf 'You currently have %d tracks on the display turned off', $message if $message =~ /^\d+$/;
  
  return $self->_info(
    'Configuring the display',
    qq{<p>$message. To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>}
  );
}

sub default_otherspecies {
## DEPRECATED - use Hub::otherspecies instead
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

sub chromosome_form {
  my ($self, $ic)   = @_;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $image_config  = $hub->get_imageconfig($ic);
  my $vwidth        = $image_config->image_height;
  my @chrs          = map { 'caption' => $_, 'value' => $_.':1-1000' }, @{$self->object->species_defs->ENSEMBL_CHROMOSOMES};
  my $form          = $self->new_form({ id => 'change_chr', action => $hub->url({ __clear => 1 }), method => 'get', class => 'autocenter', style => $vwidth ? sprintf "width:${vwidth}px" : undef });

  $form->add_field({
    'label'       => 'Change chromosome',
    'inline'      => 1,
    'elements'    => [{
      'type'        => 'dropdown',
      'name'        => 'r',
      'values'      => \@chrs,
      'value'       => $object->seq_region_name . ':1-1000',
    }, {
      'type'        => 'submit',
      'value'       => 'Go'
    }]
  });

  return $form;
}

##---------------------------------------------------------------------------------------

## USER DATA DISPLAYS ON VERTICAL DRAWING CODE

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
  my %used_colour  = ();
  my @all_colours  = @{$hub->species_defs->TRACK_COLOUR_ARRAY||[]};

  while (my ($key, $hash) = each %$data) {
    my $display = $image_config->get_node($key)->get('display');
    
    while (my ($analysis, $track) = each %$hash) {
      my ($render, $style) = split '_', $display;
      my $colour = $self->_user_track_colour($track); 
      if ($used_colour{$colour}) {
        ## pick a unique colour instead
        foreach (@all_colours) {
          next if $used_colour{$_};
          $colour = $_;
          last;
        }
      }
      $image_config->get_node($key)->set('colour', $colour);
      $used_colour{$colour} = 1;
      if ($render eq 'highlight') {
        push @pointers, $image->add_pointers($hub, {
          config_name => 'Vkaryotype',
          features    => $track->{'features'},          
          color       => $colour,
          style       => $style,
          zmenu       => 'VUserData',
          track       => $key,
        });
      }
    }
  }
  
  return @pointers;
}

sub configure_UserData_key {
  my ($self, $image_config, $features) = @_;
  my $header       = 'Key to user tracks';
  my $column_order = [qw(colour track)];
  my (@rows, %labels);

  foreach (grep $_->get('display') ne 'off', $image_config->get_node('user_data')->nodes) {
    my $id;

    ## Check for individual feature colours
    while (my($key, $data) = each(%{$_->{'user_data'}||{}})) {
      next unless $key eq $_->id;
      $id = $key;
      last;
    }
    if ($id) {
      my $data = $features->{$id};
      while (my($name, $track) = each (%$data)) {
        if ($track->{'config'} && $track->{'config'}{'itemRgb'} =~ /on/i) {
          foreach my $f (@{$track->{'features'}}) {
            my $colour = join(',', @{$f->{'item_colour'}});
            if ($labels{$colour}) {
              $labels{$colour} .= ', '.$f->{'label'};
            }
            else {
              $labels{$colour} = $f->{'label'};
            }
          }
        }
      }
    }

    ## Fall back to main config settings
    unless (scalar keys %labels) {
      $labels{$_->get('colour')} = $_->get('caption');
    }
  }

  foreach my $colour (sort {$labels{$a} cmp $labels{$b}} keys %labels) {
    my $label = $labels{$colour};
    if ($colour =~ /,/) {
      $colour = '#' . EnsEMBL::Draw::Utils::ColourMap::hex_by_rgb(undef, [ split ',', $colour ]); ## Convert RGB colours to hex, because rgb attributes getting stripped out of HTML
    } elsif ($colour =~ /^[0-9a-f]{6}$/i) { 
      $colour = "#$colour"; ## Hex with no initial hash symbol
    }
      
    my $swatch = qq{<span style="width:30px;height:15px;display:inline-block;background-color:$colour" title="$colour"></span>};
      
    push @rows, {
      colour => { value => $swatch },
      track  => { value => $label },
    };
  }
  
  return { header => $header, column_order => $column_order, rows => \@rows };
} 

sub _user_track_colour {
  my ($self, $track) = @_;
  return $track->{'config'} && $track->{'config'}{'color'} ? $track->{'config'}{'color'} : 'black';      
}

sub get_chr_legend {
  my ($self,$legend) = @_;
  return '' if (!$legend || 1> keys %$legend);
  my $hub            = $self->hub;
  my $species_defs = $hub->species_defs;
  my $styles       = $species_defs->colour('ideogram');
  my $image_config   = $hub->get_imageconfig('text_seq_legend');
  $image_config->{'legend'}={'Chromosome Type'=>$legend};
  $image_config->image_width(650);
  my $image = $self->new_image(EnsEMBL::Web::Fake->new({}), $image_config);
  $image->set_button('drag',undef);
  return $image->render;
  
  #return $self->new_image(EnsEMBL::Web::Fake->new({}), $image_config)->render;
}

sub chr_colour_key {
#figure out which chromosomes to colorize
  my $self = shift;
  my $hub          = $self->hub;
  my $species = $hub->param('species') || $hub->species;
  my $db = $hub->databases->get_DBAdaptor('core', $species);
  my $sa = $db->get_SliceAdaptor,
  my $species_defs = $hub->species_defs;
  my $styles       = $species_defs->colour('ideogram');
  my $colours = {};
  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];
  for my $chr (@$chromosomes){
    my $slice = $sa->fetch_by_region(undef,$chr);
    my ($disp) = map {$_->value} @{$slice->get_all_Attributes('chr_type')};
    if($disp){
      $colours->{$chr}=$styles->{$disp};
    }
  }
  return $colours;
}

1;
