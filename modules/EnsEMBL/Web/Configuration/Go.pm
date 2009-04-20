package EnsEMBL::Web::Configuration::Go;

use strict;

use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );

# function to configure go view

sub goview {
  my $self   = shift;
  my $obj    = $self->{'object'};
  my $panel;

  if ($self->{object}->param('display')) {
    ## Panel 2 - view after clicking on gene link
    if( $panel = $self->new_panel( 'Information',
        'code'    => "info#", 'caption' => 'GO/Gene-mapping Report' ) ) {
        $panel->add_components(qw(
            accession     EnsEMBL::Web::Component::Go::accession
            search        EnsEMBL::Web::Component::Go::search
            karyotype     EnsEMBL::Web::Component::Go::show_karyotype
            family        EnsEMBL::Web::Component::Go::family
            ));
        ## Add the forms here so we can include JS validation in the page
        $panel->add_form( $self->{page}, qw(search     EnsEMBL::Web::Component::Go::search_form) );
    }
     $self->initialize_zmenu_javascript;
     $self->add_panel( $panel );
  } else {
    ## Panel 1 - initial/search view
    if( $panel = $self->new_panel( 'Information',
        'code'    => "info#", 'caption' => 'GO Search' ) ) {
        $panel->add_components(qw(
            accession     EnsEMBL::Web::Component::Go::accession
            database      EnsEMBL::Web::Component::Go::database
            search        EnsEMBL::Web::Component::Go::search
            tree          EnsEMBL::Web::Component::Go::tree
            ));
        ## Add the forms here so we can include JS validation in the page
        $panel->add_form( $self->{page}, qw(search     EnsEMBL::Web::Component::Go::search_form) );
    }
    $self->add_panel( $panel );
  }
}

sub context_menu {
}

1;
