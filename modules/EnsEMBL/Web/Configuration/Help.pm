package EnsEMBL::Web::Configuration::Help;

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub helpview {
  my $self = shift;
  my $object = $self->{object};
  $self->_configure_popup;
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  $self->set_title( "$sitetype Help" );

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      helpview          EnsEMBL::Web::Component::Help::helpview
    ));
    $self->add_panel( $panel );
  }
}

sub search {
  my $self = shift;
  my $object = $self->{object};
  $self->_configure_popup;
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  $self->set_title( "Search $sitetype Help" );

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      helpsearch          EnsEMBL::Web::Component::Help::helpsearch
    ));
    $self->add_form( $panel, qw(helpsearch     EnsEMBL::Web::Component::Help::helpsearch_form) );
    $self->add_panel( $panel );
  }
}

sub results {
  my $self = shift;
  my $object = $self->{object};
  $self->_configure_popup;
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  $self->set_title( "$sitetype Help" );

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      results          EnsEMBL::Web::Component::Help::results
    ));
    $self->add_panel( $panel );
  }
}

sub contact {
  my $self = shift;
  my $object = $self->{object};
  $self->_configure_popup;
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  $self->set_title( "Contact $sitetype HelpDesk" );

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Contact HelpDesk',

  )) {
    $panel->add_components(qw(
      contact          EnsEMBL::Web::Component::Help::contact
    ));
    $self->add_form( $panel, qw(contact     EnsEMBL::Web::Component::Help::contact_form) );
    $self->add_panel( $panel );
  }
}

sub thanks {
  my $self = shift;
  my $object = $self->{object};

  $self->set_title('Thank You for Contacting HelpDesk');

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      thanks          EnsEMBL::Web::Component::Help::thanks
    ));
    $self->add_panel( $panel );
  }
}



sub _configure_popup {
  my $self = shift;
  my $object = $self->{object};

  ## Configure masthead, left hand menu, etc.
  $self->{'page'}->close->style = 'help';
  $self->{'page'}->close->URL   = "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
  $self->{'page'}->close->kw    = $object->param('kw');
  $self->{'page'}->helplink->label  = 'Contact helpdesk';
  $self->{'page'}->helplink->action = 'form';
  $self->{'page'}->helplink->kw     = $object->param('kw');
  $self->{'page'}->helplink->ref    = $object->referer;
}

sub help_feedback {
  my $self = shift;
  my $object = $self->{object};

  $self->set_title('Feedback');

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      help_feedback          EnsEMBL::Web::Component::Help::help_feedback
    ));
    $self->add_panel( $panel );
  }
}

sub glossaryview {
  my $self = shift;
  my $object = $self->{object};

  $self->set_title('Ensembl Glossary');

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      glossary          EnsEMBL::Web::Component::Help::glossary
    ));
    $self->add_panel( $panel );
  }
}

sub Workshops_Online {
  my $self = shift;
  my $object = $self->{object};

  $self->set_title('Ensembl Workshops Online');

  my $panel_1 = $self->new_panel( 'Image',
      'code'    => "info$self->{flag}",
      'object'  => $self->{object},
  );
  my ($panel_2, $panel_3);

  if ($object->param('id')) {
      
    if ($panel_1) {
      $panel_1->add_components(qw(
        intro          EnsEMBL::Web::Component::Help::movie_intro
      ));
      $self->add_panel( $panel_1 );
    }

    if( $panel_2 = $self->new_panel( 'Image',
      'code'    => "info$self->{flag}",
      'object'  => $self->{object},
    )) {

      $self->{page}->javascript->add_source( "/js/flash.js" );
      ## stop the movie on page load
      $self->{page}->add_body_attr('onload', 'StopMovie();RewindMovie()');

      $panel_2->add_components(qw(
        embed_movie          EnsEMBL::Web::Component::Help::embed_movie
        control_movie        EnsEMBL::Web::Component::Help::control_movie
      ));
      $self->add_form( $panel_2, qw(control_movie     EnsEMBL::Web::Component::Help::control_movie_form));
      $self->add_panel( $panel_2 );
    }

    if( $panel_3 = $self->new_panel( 'Image',
      'code'    => "info$self->{flag}",
      'object'  => $self->{object},
    )) {
      $panel_3->add_components(qw(
        helpful              EnsEMBL::Web::Component::Help::helpful
      ));
      $self->add_form( $panel_3, qw(helpful           EnsEMBL::Web::Component::Help::helpful_form));
      $self->add_panel( $panel_3 );
    }

  }

  else {
      
    if ($panel_1) {
      $panel_1->caption('Ensembl Workshops Online');
      $panel_1->add_components(qw(
        intro          EnsEMBL::Web::Component::Help::movie_index_intro
      ));
      $self->add_panel( $panel_1 );
    }

    if( $panel_2 = $self->new_panel( 'SpreadSheet',
      'code'    => "info$self->{flag}",
      'object'  => $self->{object},
    )) {
      $panel_2->add_components(qw(
        movie_index          EnsEMBL::Web::Component::Help::movie_index
      ));
      $self->add_panel( $panel_2 );
    }

    if( my $panel_3 = $self->new_panel( 'Image',
      'code'    => "info$self->{flag}",
      'object'  => $self->{object},
    )) {
      $panel_3->add_components(qw(
        static         EnsEMBL::Web::Component::Help::static
      ));
      $self->add_panel( $panel_3 );
    }
  }
}


sub context_menu {
  my $self = shift;
  my $object = $self->{object};

  $self->{page}->menu->delete_block( 'ac_mini');
  $self->{page}->menu->delete_block( 'archive');


  $self->{'page'}->menu->add_block( '___', 'bulleted', 'Help with help!' );
  $self->{'page'}->menu->add_entry( '___', 'href' => $object->_help_URL( {'kw'=>'helpview'} ), 'text' => 'General' ) ;
  $self->{'page'}->menu->add_entry( '___', 'href' => '/common/help/search', 'text' => 'Full text search' );
  my $display_length = 34; #no of characters of the title that are to be displayed
  my $focus = $object->param('kw'); # get the current entry
  $focus =~ s/(.*)\#/$1/;

  my @result_array = @{ $object->index };
  foreach my $row ( @result_array ) {
    (my $name = $row->{'title'} ) =~ s/^(.{50})...+/\1.../;
    #if ($name =~ /^Ensembl/) {
    #  $name =~ s/^Ensembl //;
    #}

    $self->add_block( lc($row->{'category'}), 'bulleted', $row->{'category'} );
    my %hash= ( 'text' => $name );
       $hash{ 'title' } =  $row->{'title'} unless $name eq $row->{'title'};
    if( $row->{'keyword'} eq $focus ) {
      $hash{ 'text'  } =  "$name";
    } else {
      $hash{ 'href'  } =  $object->_help_URL( {'kw'=>$row->{'keyword'}} );
    }
    $self->add_entry( lc($row->{'category'}), %hash );
  }
}

sub helpdesk_menu {
  my $self = shift;
  my $object = $self->{object};

  $self->add_block( 'movies', 'bulleted', 'Helpdesk' );
    
  $self->add_entry( 'movies', 'text'=>'Browse Help Articles', 'href'=>'/default/helpview' );
  $self->add_entry( 'movies', 'text'=>'Animated Tutorials', 'href'=>'/common/Workshops_Online' );
}

sub interface_menu {
  my $self = shift;
  my $object = $self->{object};

  my $flag     = "helpdb";
  $self->{page}->menu->add_block( $flag, 'bulleted', "HelpDesk Database" );

  $self->{page}->menu->add_entry( $flag, 'text' => "Add a Help Article",
                                  'href' => "/common/help_db?dataview=add" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Edit a Help Article",
                                  'href' => "/common/help_db?dataview=select_to_edit" );

  $self->{page}->menu->add_entry( $flag, 'text' => "Add a Glossary Entry",
                                  'href' => "/common/glossary_db?dataview=add" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Edit a Glossary Entry",
                                  'href' => "/common/glossary_db?dataview=select_to_edit" );



}

1;
