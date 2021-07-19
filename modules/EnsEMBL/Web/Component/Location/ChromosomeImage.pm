=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::ChromosomeImage;

### Module to replace part of the former MapView, in this case displaying 
### an overview image of an individual chromosome 

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::Location);

use List::MoreUtils qw(first_index);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
  $self->configurable( 1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $config_name = 'Vmapview';
  my $species   = $object->species;
  my $chr_name  = $object->seq_region_name;

  my $config = $object->get_imageconfig($config_name);
     $config->set_parameters({
       'container_width', $object->Obj->{'slice'}->seq_region_length,
       'slice_number'    => '2|1'
     });
  my $ideo_height = $config->get_parameter('image_height');
  my $top_margin  = $config->get_parameter('top_margin');
  my $hidden = {
    'seq_region_name'   => $chr_name,
    'seq_region_width'  => '100000',
    'seq_region_left'   => '1',
    'seq_region_right'  => $object->Obj->{'slice'}->seq_region_length,
    'click_right'       => $ideo_height+$top_margin,
    'click_left'        => $top_margin,
  };

  $config->get_node('Videogram')->set('label',   ucfirst($object->seq_region_type) );
  $config->get_node('Videogram')->set('label_2', $chr_name );

  #configure two Vega tracks in one
  if ($config->get_node('Vannotation_status_left') && $config->get_node('Vannotation_status_right')) {
    $config->get_node('Vannotation_status_left')->set('display', $config->get_node('Vannotation_status_right')->get('display'));
  }
  my $image                 = $self->new_karyotype_image($config);
  $image->image_type        = 'chromosome';
  $image->image_name        = $species.'-'.$chr_name;
  $image->set_button('drag', 'title' => 'Click or drag to jump to a region' );
  $image->imagemap          = 'yes';
  $image->{'panel_number'}  = 'chrom';

  ## Add user tracks if turned on
  my @pointers;
  my ($user_features) = $config->load_user_track_data;
  if (keys %$user_features) {
    @pointers = $self->create_user_pointers($image, $user_features);
  }

  my $script = $object->species_defs->NO_SEQUENCE ? 'Overview' : 'View';
  $image->karyotype($self->hub, $object, \@pointers, $config_name);
  $image->caption = 'Click on the image above to zoom into that point';

  my $chr_form    = $self->chromosome_form('Vsynteny');
  my $image_html  = $image->render; # needs to be done before getting the width of image

  my $html = sprintf('
  <div class="chromosome_image">
    %s
  </div>
  <div class="chromosome_stats" style="width: %spx">
    %s
    <h3>Chromosome Statistics</h3>
    %s
    %s
  </div>',
  $image_html, 2 + ($image->{'width'} || 348),  $self->chromosome_form('Vmapview')->render, $self->stats_table->render, $self->legend);

  return $html;
}

sub stats_table {
  my $self = shift;
  my $object = $self->object;

  my @order = qw(_length coding noncoding noncoding/s noncoding/l noncoding/m
                 pseudogene SNPCount);
  my @suffixes = (['','~'],['r',' (incl. ~ readthrough)']);
  my @data;

  # Attributes
  my $chr = $object->Obj->{'slice'};
  foreach my $attrib (@{$chr->get_all_Attributes}) {
    my ($name,$inline,$sub) = ($attrib->code,'',0);
    if($name =~ s/^(.*?)_(r)?a?cnt(_([^_]*))?$/$1/) { # Counts
      $sub = 1 if $4;
      $name .= "/$4" if $4;
      $inline = $2;
    }
    my $pos = first_index { $_ eq $name } @order;
    next if $pos == -1;
    my $value =  $object->thousandify($attrib->value);
    ($data[$pos]||={})->{$inline} = $value;
    $data[$pos]->{'_name'} = $attrib->name if $inline eq '';
    $data[$pos]->{'_sub'} = 1 if $sub;
  }

  # Add length
  my $name = "Length (bps)";
  $name = 'Estimated length (bps)' if $object->species_defs->NO_SEQUENCE;
  $data[0]->{'_name'} = $name;
  $data[0]->{''} = $object->thousandify($chr->seq_region_length);

  my $table = EnsEMBL::Web::Document::Table->new([{ key => 'header'}, { key => 'value'}], [], { header => 'no', exportable => 0, 'class' => 'tint' });
  foreach my $d (@data) {
    my $value = '';
    foreach my $s (@suffixes) {
      next unless defined $d->{$s->[0]};
      $value .= $s->[1];
      $value =~ s/~/$d->{$s->[0]}/g;
    }
    next unless $value;
    my $class = '';
    $class = 'row-sub' if $d->{'_sub'};
    $table->add_row({ header => $d->{'_name'}, value => $value,
                      options => { class => $class }}); 
  }
  return $table;
}

sub legend {
  my $self = shift;
  return;
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  return unless @{$hub->species_defs->ENSEMBL_CHROMOSOMES};

  my @buttons;

  my $params = {
                'type'    => 'UserData',
                'action'  => 'FeatureView',
                };

  push @buttons, {
                    'url'     => $hub->url($params),
                    'caption' => 'Add features',
                    'class'   => 'add',
                    'modal'   => 1
                    };

  return @buttons;
}

1;
