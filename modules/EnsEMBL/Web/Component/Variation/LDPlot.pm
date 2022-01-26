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

package EnsEMBL::Web::Component::Variation::LDPlot;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Shared);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('variation');
  my $vf_id  = $hub->param('vf'); 

  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my $width         = $hub->param('context') || 50000;
  my $default_track = 'r2';

  return unless $vf_id;
  return unless (grep {$_ =~ /^pop(\d+|name)$/} $hub->param); # e.g pop1, pop2, popname

  my %mappings = %{$object->variation_feature_mapping};
  my $v        = $mappings{$vf_id}; 

 
  my $slice = $object->slice;
  
  if ($slice->length >= 100000) {
    return $self->_error(
      'Region too large', 
      '<p>The region you have selected is too large to display linkage data, a maximum region of 100kb is allowed. Please change the region using the navigation controls above.<p>'
    );
  }
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $hub->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $hub->species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $hub->species_defs->ENSEMBL_TMP_TMP;

  my $seq_region = $v->{'Chr'};
  my $seq_type   = $v->{'type'};
  my $start      = $v->{'start'} <= $v->{'end'} ? $v->{'start'} : $v->{'end'};
  my $end        = $v->{'start'} <= $v->{'end'} ? $v->{'end'}   : $v->{'start'};
  my $length     = $end - $start + 1;
  my $img_start  = $start;
  my $img_end    = $end;

  $img_start -= int($width/2 - ($length/2));
  $img_end   += int($width/2 - ($length/2));

  $slice = $slice_adaptor->fetch_by_region($seq_type, $seq_region, $img_start, $img_end, 1);

  my $image_config = $hub->get_imageconfig('ldmanplot');
  my $parameters   = { 
    image_width     => $self->image_width || 800, 
    container_width => $slice->length,
    ld_type         => $hub->param('ld_type') || $default_track,
    r2_mark         => $hub->param('r2_mark') || 0.8,
    d_prime_mark    => $hub->param('d_prime_mark') || 0.8,
    vf              => $vf_id
  };
  
  $image_config->init_slice($parameters);
  

  my @pops;
  if (grep {$_ =~ /^pop\d+$/} $hub->param) { # population ID in pop1, pop2, ...
    @pops = sort { $a cmp $b } map { $self->pop_name_from_id($_) || () } @{$self->current_pop_id};
  }
  
  $image_config->add_populations(\@pops);

  # Do images for first section
  my $containers_and_configs = [ $slice, $image_config ];

  my $image = $self->new_image($containers_and_configs, $object->highlights);
  
  ## Add parameters needed by export
  foreach ($hub->param) {
    push @{$image->{'export_params'}}, [$_, $hub->param($_)] if ($_ =~ /^pop(\d+|name)$/); 
  }

  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'top';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image->render;
}

sub current_pop_id {
  my $self = shift;
  my $hub  = $self->hub;
 
  my %pops_on = map { $hub->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $hub->param;

  return [keys %pops_on]  if keys %pops_on;
  my $default_pop =  $self->get_default_pop_name;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return ( [$default_pop], [] );
}

sub get_default_pop_name {

  ### Example : my $pop_id = $self->get_default_pop_name
  ### Description : returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation();
  return unless $pop;
  return $pop->name;
}

sub pop_name_from_id {

  ### Arg1 : Population id
  ### Example : my $pop_name = $self->pop_name_from_id($pop_id);
  ### Description : returns population name as string
  ### Returns string

  my $self = shift;
  my $pop_id = shift;
  return $pop_id if $pop_id =~ /\D+/ && $pop_id !~ /^\d+$/;

  my $variation_db = $self->hub->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return "" unless $pop;
  return $pop->name;
}

1;
