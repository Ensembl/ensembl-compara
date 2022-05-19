=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::Component);

sub _configure_display {
  my ($self, $message) = @_;
  
  $message = sprintf 'You currently have %d tracks on the display turned off', $message if $message =~ /^\d+$/;
  
  return $self->_info(
    'Configuring the display',
    qq{<p>$message. To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>}
  );
}

sub chromosome_form {
  my ($self, $ic)   = @_;
  my $hub           = $self->hub;
  my $object        = $self->object || $hub->core_object('location');
  my $image_config  = $hub->get_imageconfig($ic);
  my $vwidth        = $image_config->image_height;
  my $values        = [{ 'caption' => '-- Select --', 'value' => ''}];
  my @chrs          = map { 'caption' => $_, 'value' => $_.':1-1000' }, @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
  push @$values, @chrs;
  my $is_chr        = grep {$_ eq $object->seq_region_name} @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
  my $form          = $self->new_form({ id => 'change_chr', action => $hub->url({ __clear => 1 }), method => 'get', class => 'autocenter', style => $vwidth ? sprintf "width:${vwidth}px" : undef });

  $form->add_field({
    'label'       => 'Change chromosome',
    'inline'      => 1,
    'elements'    => [{
      'type'        => 'dropdown',
      'name'        => 'r',
      'values'      => $values,
      'value'       => $is_chr ? $object->seq_region_name.':1-1000' : '',
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
        ProbeTranscript     => [ 'lharrow', 'blue'],
        Domain              => [ 'lharrow', 'blue' ],
        Variation           => [ 'rharrow', 'gradient', [qw(90 #0000FF #770088 #BB0044 #CC0000)]],
  );
  
  return $hash{$feature_type};
}

## Create a set of highlights from a userdata set
sub create_user_pointers {
  my ($self, $image, $data) = @_;
  my $hub          = $self->hub;
  my $image_config = $hub->get_imageconfig('Vkaryotype');
  my @pointers     = ();
  my %used_colour  = ();
  my @all_colours  = @{$hub->species_defs->TRACK_COLOUR_ARRAY||[]};

  while (my ($key, $tracks) = each (%$data)) {
    my $display = $image_config->get_node($key)->get('display');
    my ($render, $style) = split '_', $display;
    ## Set some defaults
    $render = 'highlight' if $render eq 'normal';
    $style ||= 'lharrow';
    $image_config->get_node($key)->set('display', $style);

    while (my ($name, $track) = each (%$tracks)) {    
      my $colour = $track->{'config'}{'color'}; 
      if (!$colour || $used_colour{$colour}) {
        ## pick a unique colour
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
          track       => $key.'_'.$name,
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

  foreach (grep $_->get('display') ne 'off', @{$image_config->get_node('user_data')->get_all_nodes}) {

    my $id = $_->id;

    ## Check for individual feature colours
    my $colours_done = 0;
    if ($_->has_user_settings) {
      my $data = $features->{$id};
      while (my($name, $track) = each (%$data)) {
        my %colour_key;
        if ($track->{'metadata'}) { 

          if ($track->{'metadata'}{'itemRgb'} =~ /on/i) {
            foreach my $f (@{$track->{'features'}}) {
              my $colour = $f->{'colour'} && ref($f->{'colour'}) eq 'ARRAY' 
                              ? join(',', @{$f->{'colour'}})
                              : $f->{'colour'};
              push @{$colour_key{$colour}}, $f->{'label'} if $f->{'label'};
            }
          }
          elsif ($track->{'metadata'}{'color'}) {
            my $colour = $track->{'metadata'}{'color'};
            foreach my $f (@{$track->{'features'}}) {
              push @{$colour_key{$colour}}, $f->{'label'} if $f->{'label'};
            }
          }

          while (my($colour, $text) = each(%colour_key)) {
            if (scalar @$text <= 5) {
              $labels{$colour} = join(', ', @$text); 
              $colours_done = 1;
            }
            else {
              $labels{$colour} = $name;
              $colours_done = 1;
            }
          }

        }
      }
    }

    ## Fall back to main config settings
    unless ($colours_done) {
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
