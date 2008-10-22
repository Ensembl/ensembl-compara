package EnsEMBL::Web::Configuration::DAS;
# This configures the DAS server component of the website

use strict;
use EnsEMBL::Web::Configuration;
our @ISA = qw( EnsEMBL::Web::Configuration);

sub _get_valid_action {
  my $self = shift;
  my $action = shift;
  my $func   = shift;
  return $func ? "$action/$func" : "action";
}

sub stylesheet {
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASSTYLE');
  my $component = "EnsEMBL::Web::Component::DAS::Annotation";
  if( my $das_panel = $self->new_panel( '', 'code' => 'das', ) ) {
    $das_panel->add_components("das_features", $component.'::stylesheet');
    $self->add_panel( $das_panel );
  }
}

sub features {
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASGFF');
#  my $component = $ENV{ENSEMBL_DAS_TYPE} eq 'reference' ?
#    'EnsEMBL::Web::Component::DAS::Reference' : "EnsEMBL::Web::Component::DAS::Annotation";
  if( my $das_panel = $self->new_panel( '', 'code' => 'das',  ) ) {
    $das_panel->add_components("das_features", 'EnsEMBL::Web::Component::DAS::features');
    $self->add_panel( $das_panel );
  }
}

sub types{
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASTYPES');
  my $component = "EnsEMBL::Web::Component::DAS";
  if( my $das_panel = $self->new_panel( '', 'code' => 'das', ) ) {
    $das_panel->add_components("das_features", $component.'::types');
    $self->add_panel( $das_panel );
  }
}

# Only applicable to a reference server

sub entry_points {
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASEP');
  my $component = 'EnsEMBL::Web::Component::DAS::Reference';
  if( my $das_panel = $self->new_panel( '', 'code' => 'das', ) ) {
    $das_panel->add_components("das_features", $component.'::entry_points');
    $self->add_panel( $das_panel );
  }
}


# Only applicable to a reference server

sub dna {
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASDNA');
  my $component = 'EnsEMBL::Web::Component::DAS::Reference';
  if( my $das_panel = $self->new_panel( '','code' => 'das', ) ) {
    $das_panel->add_components("das_features", $component.'::dna');
    $self->add_panel( $das_panel );
  }
}

sub sequence {
  my $self = shift;
  my $page = $self->{'page'};
  $page->set_doc_type('XML', 'DASSEQUENCE');
  my $component = 'EnsEMBL::Web::Component::DAS::Reference';
  if( my $das_panel = $self->new_panel( '', 'code' => 'das', ) ) {
    $das_panel->add_components("das_features", $component.'::sequence');
    $self->add_panel( $das_panel );
  }
}

1;
