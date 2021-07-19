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

package EnsEMBL::Web::Component::Location::SyntenyImage;

### Module to replace part of the former SyntenyView, in this case displaying 
### an image of the syntenous chromosome regions 

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object || $self->hub->core_object('location');
  my $species = $hub->species;
  my %synteny = $hub->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my $other   = $self->hub->otherspecies; 
  my $other_prodname = $hub->species_defs->get_config($other, 'SPECIES_PRODUCTION_NAME');
  my $chr     = $object->seq_region_name;
  my %chr_1   = map { $_, 1 } @{$hub->species_defs->ENSEMBL_CHROMOSOMES || []};
  my $chr_2   = scalar @{$hub->species_defs->get_config($other, 'ENSEMBL_CHROMOSOMES')||[]};
  
  unless ($synteny{$other_prodname}) {
    $hub->problem('fatal', "Can't display synteny",  "There is no synteny data for these two species ($species and $other)");
    return undef;
  }
  
  unless ($chr_1{$chr} && $chr_2 > 0) {
    $hub->problem('fatal', "Unable to display", "Synteny view only displays synteny between real chromosomes - not fragments");
    return undef;
  }

  my $ka         = $hub->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
  my $ka2        = $hub->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
  my $compara_db = $hub->database('compara');
  my $raw_data   = $object->chromosome->get_all_compara_Syntenies($other, undef, $compara_db);   
  my $chr_length = $object->chromosome->length;
  
  my ($localgenes, $offset) = $object->get_synteny_local_genes;
  my $loc = (@$localgenes ? $localgenes->[0]->start + $object->seq_region_start : 1); # Jump loc to the location of the genes
  
  my $image_config = $hub->get_imageconfig('Vsynteny');
  
  $image_config->{'other_species_installed'} = $synteny{$other};
  $image_config->container_width($chr_length);

  my $image = $self->new_vimage({
    chr           => $chr,
    ka_main       => $ka,
    sa_main       => $hub->get_adaptor('get_SliceAdaptor'),
    ka_secondary  => $ka2,
    sa_secondary  => $hub->get_adaptor('get_SliceAdaptor', 'core', $other),
    synteny       => $raw_data,
    other_species => $other,
    line          => $loc,
    format        => $hub->param('export')
  }, $image_config);

  $image->centred    = 1;  
  $image->imagemap   = 'yes';
  $image->image_type = 'syntenyview';
  $image->image_name = "$species-$chr-$other";
  $image->set_button('drag', 'title' => 'Click or drag to change region');

  $image->{'export_params'} = [['otherspecies', $other]];

  my $chr_form = $self->chromosome_form('Vsynteny');

  $chr_form->add_element(
      type  => 'Hidden',
      name  => 'otherspecies',
      value => $hub->param('otherspecies') || $hub->otherspecies,
  );
 

  my @coords = split(/[:-]/, $hub->param('r'));
  my $caption = sprintf('Synteny between %s chromosome %s and %s', 
                    $hub->species_defs->SPECIES_DISPLAY_NAME,
                    $coords[0],
                    $hub->species_defs->get_config($hub->otherspecies, 'SPECIES_DISPLAY_NAME'),
                );
 
  return if $self->_export_image($image,'no_text no_pdf');
  my $html = sprintf('
  <div class="synteny_image">
    <h2>%s</h2>
    %s
    <span class="hash_change_reload"></span>
  </div>
  <div class="synteny_forms">
    %s
    %s
  </div>
', $caption, $image->render, $self->species_form->render, $chr_form->render);

  return $html;
}

sub species_form {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $url               = $hub->url({ otherspecies => undef }, 1);
  my $image_config      = $hub->get_imageconfig('Vsynteny');
  my $vwidth            = $image_config->image_height;
  my $form              = $self->new_form({ id => 'change_sp', action => $url->[0], method => 'get', class => 'autocenter', style => $vwidth ? "width:${vwidth}px" : undef });
  my %synteny_hash      = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my $prod_name         = $species_defs->get_config($hub->species, 'SPECIES_PRODUCTION_NAME');
  my %synteny           = %{$synteny_hash{$prod_name} || {}};
  my $url_map           = $species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP');
  my @sorted            = sort { $a->{'display'} cmp $b->{'display'} } map {{ name => $url_map->{$_}, display => $species_defs->get_config($url_map->{$_}, 'SPECIES_DISPLAY_NAME') }} keys %synteny;
  my @values;

  foreach my $next (@sorted) {
    next if $next->{'name'} eq $hub->species;
    push @values, { caption => $next->{'display'}, value => $next->{'name'} };
  }

  $form->add_hidden({ name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
  $form->add_field({
    'label'       => 'Change Species',
    'inline'      => 1,
    'elements'    => [{
      'type'        => 'dropdown',
      'name'        => 'otherspecies',
      'values'      => \@values,
      'value'       => $hub->param('otherspecies') || $hub->param('species') || $hub->otherspecies,
    }, {
      'type'        => 'submit',
      'value'       => 'Go'
    }]
  });

  return $form;
}


1;
