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

package EnsEMBL::Web::Component::UserData::DasCoords;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Filter::DAS;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(@GENE_COORDS @PROT_COORDS @SNP_COORDS);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Choose a coordinate system';
}

sub content {
  my $self = shift;
  my $object  = $self->object;
  my $species = $object->species;
  my $server  = $object->param('das_server');
  my $url     = $object->species_path($object->data_species).'/UserData/';
  my $form;

  if ($server) {
    my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$object});
    my $sources = $filter->catch($server, $object->param('logic_name'));

    if ($filter->error_code) {
      $form = $self->modal_form('select_das', $url.'SelectDAS', {'wizard' => 1});
      $object->param('filter_module', 'DAS');
      $object->param('filter_code', $filter->error_code);
    }
    else {
  
      $form = $self->modal_form('select_species', $url.'ValidateDAS', {'wizard' => 1});
      my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
      $form->add_notes( {'heading' => 'Info', 'text' => "$sitename is not able to automatically configure one or more DAS sources. Please select the coordinate system(s) the sources below have data for."} );

      my @species = ($self->object->param('species'));
      if (grep /NONE/, @species) {
        @species = ();
      }

      foreach my $source (@$sources) {

        $self->output_das_text($form, $source); 

        foreach my $species (@species) {
          my $fieldset = $form->add_fieldset({'name' => $species.'_cs1', 'legend' => "Genomic ($species)"});
          my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");
          my @coords = sort {
            $a->rank <=> $b->rank
            } grep {
              ! $_->is_top_level
            } @{ $csa->fetch_all };
          foreach my $cs (@coords) {
            my $cs_hashref = {
              'name'  => $cs->name,
              'version' => $cs->version,
              'species' => $species,
            };
            my $das_cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_hashref($cs_hashref);
            $fieldset->add_field({
              'type'    => 'checkbox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $das_cs->to_string,
              'label'   => $das_cs->label 
            });
          }
        }

        if (scalar(@GENE_COORDS)) {
          my $gene_fieldset = $form->add_fieldset({'name' => $source->logic_name.'_gene', 'legend' => 'Gene'});
          for my $cs (@GENE_COORDS) {
            $cs->matches_species($species) || next;
            $gene_fieldset->add_field({ 
              'type'    => 'checkbox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $cs->to_string,
              'label'   => $cs->label 
            });
          }
        }

        if (scalar(@PROT_COORDS)) {
          my $prot_fieldset = $form->add_fieldset({'name' => $source->logic_name.'_prot', 'legend' => 'Protein'});
          for my $cs (@PROT_COORDS) {
            $cs->matches_species($species) || next;
            $prot_fieldset->add_field({ 
              'type'    => 'checkbox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $cs->to_string,
              'label'   => $cs->label 
            });
          }
        }

        if (scalar(@SNP_COORDS)) {
          my $snp_fieldset = $form->add_fieldset({'name' => $source->logic_name.'_snp', 'legend' => 'Variation'});
          for my $cs (@SNP_COORDS) {
            $cs->matches_species($species) || next;
            $snp_fieldset->add_field({ 
              'type'    => 'checkbox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $cs->to_string,
              'label'   => $cs->label 
            });
          }
        }
      }
      
      $form->add_hidden([
        {'name' => 'das_server',  'value' => $object->param('das_server')},
        {'name' => 'species',     'value' => $object->param('species')},
      ]);
      $form->add_hidden({'name' => 'logic_name', 'value' => $_}) for $object->param('logic_name');
    }
  }
  else {
    $form = $self->modal_form('select_species', $url.'SelectServer', {'wizard' => 1});
    $form->add_element(
      'type'  => 'Information',
      'value' => "Sorry, there was a problem with this page. Please click on the 'Attach DAS' link to try again.",
    );
  }

  return $form->render;
}

1;
