package EnsEMBL::Web::Configuration::Feature;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::Feature;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

## Function to configure featureview

sub featureview {
  my $self   = shift;
  my $object = $self->{'object'};

  $self->initialize_zmenu_javascript;

  ## the "featureview" wizard uses 4 nodes: select feature, process selection, 
  ## configure image (only shown if species has chromosomes), and display features
  my $wizard = EnsEMBL::Web::Wizard::Feature->new($object);
  $wizard->add_nodes([qw(fv_select fv_process fv_layout fv_display)]);
  $wizard->default_node('fv_display');

  ## chain the nodes together
  $wizard->chain_nodes([
          ['fv_select'=>'fv_process'],
          ['fv_process'=>'fv_layout'],
          ['fv_process'=>'fv_display'],
          ['fv_layout'=>'fv_display'],
  ]);

  $self->add_wizard($wizard);

  ## need custom panels for display page
  my $here = $wizard->current_node($object);
  if ($here eq 'fv_display') {
    if (!$object->param('id')) { ## redirect to form
      $wizard->current_node($object, 'fv_select');
    }
  }

  $here = $wizard->current_node($object);
  if ($here eq 'fv_display') {
    my $type = $object->param('type');
    my $id   = $object->param('id');

    if( $type eq 'Gene' ) {
      $id = uc($id);
    }

    $self->{page}->set_title( "FeatureView: $type $id");

    ## determine which panels are needed
    my ($karyo_panel, $key_panel, $unmapped_panel, $gene_panel, $reg_panel, $feature_panel, $xref_panel);
    if ($object->Obj && $object->Obj->{'Xref'}) {
      $karyo_panel = 1;
      $xref_panel = 1;
    } else {
      if (!$object->feature_mapped) {
        $unmapped_panel = 1;
      } else {
        ## standard spreadsheet panel
        $feature_panel = 1;
        ## karyotype
        if (@{$object->species_defs->ENSEMBL_CHROMOSOMES}) {
          $karyo_panel = 1;
        }
        ## extra spreadsheet panel(s)
        if ($object->Obj->{'Gene'} && scalar(keys %{$object->Obj}) > 1) {
          $gene_panel = 1;
          $key_panel = 1;
        }
        if ($object->Obj->{'RegulatoryFactor'}) {
          $reg_panel = 1;
        }
      }
    }

    ## generate required panels
    if ($karyo_panel) {
      $karyo_panel = new EnsEMBL::Web::Document::Panel::Image(
        'code'    => "info$self->{flag}",
        'caption' => "Feature Location(s)",
        'object'  => $self->{object},
      );
      $karyo_panel->add_components(qw(image EnsEMBL::Web::Component::Feature::show_karyotype));
    }

=pod
    if ($key_panel) {
      $key_panel = new EnsEMBL::Web::Document::Panel::Image(
        'code'    => "info$self->{flag}",
        'caption' => "$type: $id",
        'object'  => $self->{object},
      );
      $key_panel->add_components(qw(image EnsEMBL::Web::Component::Feature::key_to_pointers));
    }
=cut

    if ($gene_panel) {  
      ## data includes one or more subsidiary gene objects (currently OligoProbes only)
      $gene_panel = new EnsEMBL::Web::Document::Panel::SpreadSheet(
        'code'    => "info$self->{flag}",
        'caption' => "Gene Information",
        'object'  => $self->{object},
      );
      $gene_panel->add_components(qw(genes    EnsEMBL::Web::Component::Feature::genes))
    }

    if ($reg_panel) {
      $reg_panel = $self->new_panel('Information',
         'code'    => "info$self->{flag}",
         'caption' => "Regulatory Factor $id",
               );

      $reg_panel->add_components(qw(
    regulatory_factor EnsEMBL::Web::Component::Feature::regulatory_factor
            ));
    }
   
    if ($feature_panel) {
      $feature_panel = new EnsEMBL::Web::Document::Panel::SpreadSheet(
        'code'    => "info$self->{flag}",
        'caption' => 'Feature Information', 
        'object'  => $self->{object},
      );
      $feature_panel->add_components( qw(features
          EnsEMBL::Web::Component::Feature::spreadsheet_featureTable));
    }

    if ($xref_panel) {
      $xref_panel = new EnsEMBL::Web::Document::Panel::SpreadSheet(
        'code'    => "info$self->{flag}",
        'caption' => 'Feature Information', 
        'object'  => $self->{object},
      );
      $xref_panel->add_components( qw(xrefs
          EnsEMBL::Web::Component::Feature::spreadsheet_xrefTable));
    }

    if ($unmapped_panel) {
      $unmapped_panel = new EnsEMBL::Web::Document::Panel::Information(
        'code'    => "info$self->{flag}",
        'caption' => 'Unmapped Feature', 
        'object'  => $self->{object},
      );
      $unmapped_panel->add_components( qw(
          id          EnsEMBL::Web::Component::Feature::unmapped_id
          unmapped    EnsEMBL::Web::Component::Feature::unmapped
          reason      EnsEMBL::Web::Component::Feature::unmapped_reason
          details     EnsEMBL::Web::Component::Feature::unmapped_details
      ));
    }

    ## add required panels to webpage
    $self->initialize_zmenu_javascript;
    $self->{page}->content->add_panel($unmapped_panel)  if $unmapped_panel;
    #$self->{page}->content->add_panel($key_panel)  if $key_panel;
    $self->{page}->content->add_panel($karyo_panel)     if $karyo_panel;
    $self->{page}->content->add_panel($feature_panel)   if $feature_panel;
    $self->{page}->content->add_panel($xref_panel)      if $xref_panel;
    $self->{page}->content->add_panel($gene_panel)      if $gene_panel;
    $self->{page}->content->add_panel($reg_panel)       if $reg_panel;
  }
  else {
    $self->wizard_panel('Featureview');
  }
}


#---------------------------------------------------------------------------

sub context_menu {
  my $self         = shift;
  my $obj          = $self->{object};
  my $species      = $obj->species;
  my $flag         = "feat";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Display Feature" );

  # pass configuration options in URL
  my $style       = $obj->param('style');
  my $col         = $obj->param('col');
  my $zmenu       = $obj->param('zmenu');
  my $chr_length  = $obj->param('chr_length');
  my $v_padding   = $obj->param('v_padding');
  my $h_padding   = $obj->param('h_padding');
  my $h_spacing   = $obj->param('h_spacing');
  my $rows        = $obj->param('rows');
  my $config = "style=$style;col=$col;zmenu=$zmenu;chr_length=$chr_length;v_padding=$v_padding;h_padding=$h_padding;h_spacing=$h_spacing;rows=$rows";

  my $features = [];
  my $href_root = "/$species/featureview?node=fv_select;type=";
  #look in species defs to find available features
  foreach my $avail_feature (@{$obj->find_available_features}) {
	push @$features, {'text'=>$avail_feature->{'text'},'href'=>$href_root.$avail_feature->{'value'},'raw'=>1 } ;
  }

  $self->add_entry( $flag, code=>'other_feat', 'text' => "Select another feature to display",
                                  'href' => "/@{[$obj->species]}/featureview?$config", 'options' => $features );
  $self->add_entry( $flag, 'text' => "Display your own features on a karyotype",
                                  'href' => "/@{[$obj->species]}/karyoview" );
}

1;
