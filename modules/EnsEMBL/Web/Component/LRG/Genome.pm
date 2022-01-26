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

#$ Id: Genome.pm,v 1.9 2010-08-09 11:59:35 sb23 Exp $

package EnsEMBL::Web::Component::LRG::Genome;

### Hacky copy of Component::Location::Genome, as there's an AJAX bug that breaks
### Component rendering when trying to use components from a different namespace
## FIXME - remove this module when bug is fixed!!

use strict;

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES;

  my ($html, @all_features);
  
  my $features = $self->builder->create_object('Feature')->convert_to_drawing_parameters('LRG')->[0];
  my $table    = $self->feature_tables($features);
  
  if ($chromosomes && scalar @$chromosomes && $species_defs->MAX_CHR_LENGTH) {
    my $image    = $self->new_karyotype_image;
    my $pointers = $image->add_pointers($hub, {
      features      => $features,
      config_name   => 'Vkaryotype',
      feature_type  => 'LRG',
      color         => 'dodgerblue3', 
      style         => 'lharrow'
    });
    
    $image->image_name = "LRG-$species";
    $image->caption    = 'Click on the image above to jump to a chromosome, or click and drag to select a region';
    $image->imagemap   = 'yes';
    $image->set_button('drag', 'title' => 'Click on a chromosome');
    $image->karyotype($hub, $self->object, [ $pointers ], 'Vkaryotype');
    
    $html .= $image->render;
  } else {
    $html .= $self->_info('Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>');
  }
  
  $html .= $table || EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, "/ssi/species/stats_$species.html");
  
  return $html;
}

sub feature_tables {
  my $self         = shift;
  my $features     = shift;
  my $species_path = $self->hub->species_defs->species_path;
  my $columns      = [
    { key => 'loc',    title => 'Genomic location(strand)', width => '15%', align => 'left', sort => 'position'      },
    { key => 'length', title => 'LRG length',               width => '10%', align => 'left', sort => 'numeric'       },
    { key => 'lrg',    title => 'LRG name',                 width => '15%', align => 'left', sort => 'position_html' },
    { key => 'hgnc',   title => 'HGNC name',                width => '15%', align => 'left', sort => 'string'        }
  ];
  
  my $rows = [];
  
  foreach (@$features) {
    push @$rows, {
      loc    => "$_->{'region'}:$_->{'start'}-$_->{'end'}($_->{'strand'})",
      length => $_->{'length'},
      lrg    => qq{<span class="hidden">$_->{'lrg_number'}</span><a href="$species_path/LRG/Summary?lrg=$_->{'lrg_name'}">$_->{'lrg_name'}</a>},
      hgnc   => $_->{'hgnc_name'}
    };
  }
  
  return '<strong>LRG Information</strong>' . $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'loc asc' ] })->render if scalar @$rows;
}

1;
