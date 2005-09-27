package EnsEMBL::Web::Configuration::Feature;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Image;

use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

## Function to configure featureview

## This view has two pages: a form to select the required feature and
## configure the image, then a display page with multiple panels

sub featureview {
  my $self   = shift;

  # this is a two-step view, so we need 2 separate sections
  my %data = %{$self->{'object'}->__data};
  if ($self->{'object'}->param('id') && $data{'_object'}) {
    # Step 2 - user has chosen valid feature
    my $type = $self->{'object'}->param('type');
    my $id   = $self->{'object'}->param('id');
    if ($type eq 'Gene') {
        $id = uc($id);
    }
    $self->{page}->set_title( "FeatureView: $type $id");
    # do karytype
    my $panel2a = new EnsEMBL::Web::Document::Panel::Image(
        'code'    => "info$self->{flag}",
        'caption' => "$type: $id",
        'object'  => $self->{object},
    );
    $panel2a->add_components(qw(image EnsEMBL::Web::Component::Feature::show_karyotype));
    # do feature information table
    my $panel2b = new EnsEMBL::Web::Document::Panel::SpreadSheet(
        'code'    => "info$self->{flag}",
        'caption' => '', 
        'object'  => $self->{object},
    );
    $panel2b->add_components( qw(features
      EnsEMBL::Web::Component::Feature::spreadsheet_featureTable));

    $self->initialize_zmenu_javascript;
    $self->{page}->content->add_panel($panel2a);
    $self->{page}->content->add_panel($panel2b);
  }
  else {
    # Step 1 - initial page display
    my $panel1 =  new EnsEMBL::Web::Document::Panel::Image( 
        'code'    => "info$self->{flag}",
        'caption' => 'FeatureView',
        'object'  => $self->{object},
    );
    $panel1->add_components(qw(select EnsEMBL::Web::Component::Feature::select_feature));
    $panel1->add_form( $self->{page}, qw(select_feature  EnsEMBL::Web::Component::Feature::select_feature_form) );
    $self->{page}->content->add_panel($panel1);
  }
}

#---------------------------------------------------------------------------

sub context_menu {
  my $self = shift;
  my $obj      = $self->{object};
  my $species = $self->{object}->species;
  
  my $flag     = "";
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

  my $feature_types = [
        {'text'=>"Gene", 'href'=>"/$species/featureview?type=Gene", 'raw'=>1},
        {'text'=>"AffyProbe", 'href'=>"/$species/featureview?type=AffyProbe", 'raw'=>1},
        {'text'=>"Sequence Feature", 'href'=>"/$species/featureview?type=DnaAlignFeature", 'raw'=>1},
        {'text'=>"Protein Feature", 'href'=>"/$species/featureview?type=ProteinAlignFeature", 'raw'=>1},
        {'text'=>"Regulatory Factor", 'href'=>"/$species/featureview?type=RegulatoryFactor", 'raw'=>1},
    ];

  if ($species eq 'Homo_sapiens') {
        unshift (@$feature_types,  {'text'=>"OMIM Disease", 'href'=>"/$species/featureview?type=Disease", 'raw'=>1});
  }

  $self->add_entry( $flag, 'text' => "Select another feature to display",
                                  'href' => "/@{[$obj->species]}/featureview?$config", 'options' => $feature_types );
  $self->add_entry( $flag, 'text' => "Display your own features on a karyotype",
                                  'href' => "/@{[$obj->species]}/karyoview" );
}

1;
