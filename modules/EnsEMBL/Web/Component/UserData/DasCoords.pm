package EnsEMBL::Web::Component::UserData::DasCoords;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Filter::DAS;

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

  ## Catch any errors at the server end
  my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$object});
  my $sources = $filter->catch($object->param('dsn'));
  my $form;

  my $url = '/'.$object->data_species.'/UserData/';
  if ($filter->error_code) {
    $form = $self->modal_form('select_das', $url.'SelectDAS', {'wizard' => 1});
    $object->param->('filter_module', 'DAS');
    $object->param->('filter_code', $filter->error_code);
  }
  else {

    $form = $self->modal_form('select_species', $url.'SelectDasCoords', {'wizard' => 1});
    my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
    $form->add_notes( {'heading' => 'Info', 'text' => "$sitename is not able to automatically configure one or more DAS sources. Please select the coordinate system(s) the sources below have data for. If the DAS sources shown below do not use the same coordinate system, go back and add them individually."} );

    my @species = $self->object->param('species');
    if (grep /NONE/, @species) {
      @species = ();
    }

    for my $species (@species) {

      my $fieldset = {'legend' => "Genomic ($species)"};
      my $f_elements = [];

      my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");
      my @coords = sort {
        $a->rank <=> $b->rank
      } grep {
        ! $_->is_top_level
      } @{ $csa->fetch_all };
      for my $cs (@coords) {
        $cs->{'species'} = $species;
        $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_hashref($cs);
        push @$f_elements, {'type'    => 'CheckBox',
                          'name'    => 'coords',
                          'value'   => $cs->to_string,
                          'label'   => $cs->label };
      }
      $fieldset->{'elements'} = $f_elements;
      $form->add_fieldset($fieldset);
    }

    if (scalar(@GENE_COORDS)) {
      my $gene_fieldset = {'legend' => 'Gene'};
      my $g_elements = [];
      for my $cs (@GENE_COORDS) {
        $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
        push @$g_elements, { 'type'    => 'CheckBox',
                           'name'    => 'coords',
                           'value'   => $cs->to_string,
                           'label'   => $cs->label };
      }
      $gene_fieldset->{'elements'} = $g_elements;
      $self->add_fieldset($gene_fieldset);
    }

    if (scalar(@PROT_COORDS)) {
      my $prot_fieldset = {'legend' => 'Protein'};
      my $p_elements = [];
      for my $cs (@PROT_COORDS) {
        $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
        push @$p_elements, { 'type'    => 'CheckBox',
                           'name'    => 'coords',
                           'value'   => $cs->to_string,
                           'label'   => $cs->label };
      }
      $prot_fieldset->{'elements'} = $p_elements;
      $self->add_fieldset($prot_fieldset);
    }

    $form->add_element( 'type' => 'SubHeader',   'value' => 'DAS Sources' );
    my @coord_unknown = grep { !scalar @{$_->coord_systems} } @{ $sources };
    $self->output_das_text(@coord_unknown);
  }
  return $form->render;
}

1;
