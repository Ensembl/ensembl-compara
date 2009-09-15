package EnsEMBL::Web::Component::UserData::DasCoords;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Filter::DAS;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(@GENE_COORDS @PROT_COORDS);

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
  my $object = $self->object;

  my $server = $self->object->param('das_server');
  my $url = '/'.$object->data_species.'/UserData/';
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
          my $fieldset = {'name' => $species.'_cs1', 'legend' => "Genomic ($species)"};
          my $f_elements = [];

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
            push @$f_elements, {
              'type'    => 'CheckBox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $das_cs->to_string,
              'label'   => $das_cs->label 
            };
          }
          $fieldset->{'elements'} = $f_elements;
          $form->add_fieldset(%$fieldset);
        }

        if (scalar(@GENE_COORDS)) {
          my $gene_fieldset = {'name' => $source->logic_name.'_gene', 'legend' => 'Gene'};
          my $g_elements = [];
          for my $cs (@GENE_COORDS) {
            $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
            push @$g_elements, { 
              'type'    => 'CheckBox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $cs->to_string,
              'label'   => $cs->label 
            };
          }
          $gene_fieldset->{'elements'} = $g_elements;
          $form->add_fieldset(%$gene_fieldset);
        }

        if (scalar(@PROT_COORDS)) {
          my $prot_fieldset = {'name' => $source->logic_name.'_prot', 'legend' => 'Protein'};
          my $p_elements = [];
          for my $cs (@PROT_COORDS) {
            $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
            push @$p_elements, { 
              'type'    => 'CheckBox',
              'name'    => $source->logic_name.'_coords',
              'value'   => $cs->to_string,
              'label'   => $cs->label 
            };
          }
          $prot_fieldset->{'elements'} = $p_elements;
          $form->add_fieldset(%$prot_fieldset);
        }
      }

      $form->add_element(
        'type' => 'Hidden',
        'name' => 'das_server',
        'value' => $object->param('das_server'),
      );
      $form->add_element(
        'type' => 'Hidden',
        'name' => 'species',
        'value' => $object->param('species'),
      );
      for my $v ($object->param('logic_name')) {
        $form->add_element(
          'type' => 'Hidden',
          'name' => 'logic_name',
          'value' => $v,
        );
      }
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
