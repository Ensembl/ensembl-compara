package EnsEMBL::Web::Configuration;

use strict;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);
use POSIX qw(floor ceil);

sub new {
  my( $class, $page, $object, $flag ) = @_;
  my $self = {
    'page'   => $page,
    'object' => $object,
    'flag '  => $flag || '',
    'cl'     => {}
  };
  bless $self, $class;
  return $self;
}

sub update_configs_from_parameter {
  my( $self, $parameter_name, @userconfigs ) = @_;
  my $val = $self->{object}->param( $parameter_name );
  my $rst = $self->{object}->param( 'reset' );
  return unless $val || $rst;
  my $wsc = $self->{object}->get_scriptconfig();
  if( $wsc ) {
    $wsc->reset() if $rst;
    $wsc->update_config_from_parameter( $val ) if $val;
  }
  foreach my $selfig_name ( @userconfigs ) {
    my $wuc = $self->{object}->get_userconfig( $selfig_name );
    if( $wuc ) {
      $wuc->reset() if $rst;
      $wuc->update_config_from_parameter( $val ) if $val;
    }
  }
}

sub add_panel { $_[0]{page}->content->add_panel( $_[1] ); }
sub set_title { $_[0]{page}->set_title( $_[1] ); }
sub add_form  { my($self,$panel,@T)=@_; $panel->add_form( $self->{page}, @T ); }

sub add_wizard { 
  my ($self, $wizard) = @_;
  $self->{wizard} = $wizard; 
}

sub add_block { 
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->add_block( $flag, @_ );
}

sub delete_block { 
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->delete_block( $flag, @_ );
}

sub add_entry { 
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->add_entry( $flag, @_ );
}

sub new_panel {
  my( $self, $panel_type, %params ) = @_;
  my $module_name = "EnsEMBL::Web::Document::Panel";
     $module_name.= "::$panel_type" if $panel_type;
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;
  if( $panel_type && !$self->dynamic_use( $module_name ) ) {
    my $error = $self->dynamic_use_failure( $module_name );
    my $message = "^Can't locate EnsEMBL/Web/Document/Panel/$panel_type\.pm in";
    if( $error =~ m:$message: ) {
      $error = qq(<p>Unrecognised panel type "<b>$panel_type</b>");
    } else {
      $error = sprintf( "<p>Unable to compile <strong>$module_name</strong></p><pre>%s</pre>",
                $self->_format_error( $error ) );
    }
    $self->{page}->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'object'  => $self->{'object'},
        'code'    => "error_$params{'code'}",
        'caption' => "Panel compilation error",
        'content' => $error
      )
    );
    return undef;
  }
  no strict 'refs';
  my $panel;
  eval {
    $panel = $module_name->new( 'object' => $self->{'object'}, %params );
  };
  return $panel unless $@;
  my $error = "<pre>".$self->_format_error($@)."</pre>";
  $self->{page}->content->add_panel(
    new EnsEMBL::Web::Document::Panel(
      'object'  => $self->{'object'},
      'code'    => "error_$params{'code'}",
      'caption' => "Panel runtime error",
      'content' => "<p>Unable to compile <strong>$module_name</strong></p>$error"
    )
  );
  return undef;
}

sub mapview_possible {
  my( $self, $chr ) = @_;
  my %chrs = map { $_,1 } @{$self->{object}->species_defs->ENSEMBL_CHROMOSOMES||[]};
  return $chrs{$chr};
}

sub initialize_ddmenu_javascript {
  my $self = shift;
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  $self->{page}->javascript->add_source( '/js/dd_menus_32.js' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub initialize_zmenu_javascript {
  my $self = shift;
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  $self->{page}->javascript->add_source( '/js/zmenu_32.js' );
  $self->{page}->javascript_div->add_div( 'jstooldiv', { 'style' => 'z-index: 200; position: absolute; visibility: hidden' } , '' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub initialize_zmenu_javascript_new {
  my $self = shift;
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  foreach( qw(dd_menus_32.js new_contigview_support.js new_drag_imagemap.js new_old_zmenu.js new_zmenu.js new_support.js) ) {
    $self->{page}->javascript->add_source( "/js/$_" );
  }
  $self->{page}->javascript_div->add_div( 'jstooldiv', { 'style' => 'z-index: 200; position: absolute; visibility: hidden' } , '' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub context_location {
  my $self = shift;
  my $obj = $self->{object};
  return unless $obj->can( 'location_string' );
  my $species = $obj->species;
  my( $q_string, $header ) = $obj->location_string;
  $header = "@{[$obj->seq_region_type_and_name]}<br />@{[$obj->thousandify(floor($obj->seq_region_start))]}";
  if( floor($obj->seq_region_start) != ceil($obj->seq_region_end) ) {
    $header .= " - @{[$obj->thousandify(ceil($obj->seq_region_end))]}";
  }
  my $flag = "location$self->{flag}";
  return if $self->{page}->menu->block($flag);
  my $no_sequence = $obj->species_defs->NO_SEQUENCE;
  if( $q_string ) {
    my $flag = "location$self->{flag}";
    $self->add_block( $flag, 'bulletted', $header, 'raw'=>1 ); ##RAW HTML!
    $header =~ s/<br \/>/ /;
    if( $self->mapview_possible( $obj->seq_region_name ) ) {
      $self->add_entry( $flag, 'text' => "View of @{[$obj->seq_region_type_and_name]}",
       'href' => "/$species/mapview?chr=".$obj->seq_region_name,
       'title' => 'MapView - show chromosome summary' );
    }
    unless( $no_sequence ) {
      $self->add_entry( $flag, 'text' => 'Graphical view',
        'href'=> "/$species/contigview?l=$q_string",
        'title'=> "ContigView - detailed sequence display of $header" );
    }
    $self->add_entry( $flag, 'text' => 'Graphical overview',
      'href'=> "/$species/cytoview?l=$q_string",
      'title' => "CytoView - sequence overview of $header" );
    unless( $no_sequence ) {
      $self->add_entry( $flag, 'text' => 'Export information about region',
        'title' => "ExportView - export information about $header",
        'href' => "/$species/exportview?l=$q_string"
      );
      $self->add_entry( $flag, 'text' => 'Export sequence as FASTA',
        'title' => "ExportView - export sequence of $header as FASTA",
        'href' => "/$species/exportview?l=$q_string;format=fasta;action=format"
      );
      $self->add_entry( $flag, 'text' => 'Export EMBL file',
        'title' => "ExportView - export sequence of $header as EMBL",
        'href' => "/$species/exportview?l=$q_string;format=embl;action=format"
      );
    }
   unless ( $obj->species_defs->ENSEMBL_NOMART) {
      if( $obj->species_defs->multidb('ENSEMBL_MART_ENSEMBL') && !$obj->species_defs->ENSEMBL_NOMART ) {
        $self->add_entry( $flag, 'icon' => '/img/biomarticon.gif' , 'text' => 'Export Gene info in region',
          'title' => "BioMart - export Gene information in $header",
          'href' => "/$species/martlink?l=$q_string;type=gene_region" );
      }
      if( $obj->species_defs->multidb( 'ENSEMBL_MART_SNP' ) ) {
        $self->add_entry( $flag, 'icon' => '/img/biomarticon.gif' , 'text' => 'Export SNP info in region',
          'title' => "BioMart - export SNP information in $header",
          'href' => "/$species/martlink?l=$q_string;type=snp_region" ) if $obj->species_defs->databases->{'ENSEMBL_VARIATION'};
      }
      if( $obj->species_defs->multidb( 'ENSEMBL_MART_VEGA' ) ) {
        $self->add_entry( $flag,  'icon' => '/img/biomarticon.gif' , 'text' => 'Export Vega info in region',
          'title' => "BioMart - export Vega gene features in $header",
          'href' => "/$species/martlink?l=$q_string;type=vega_region" ) if $obj->species_defs->databases->{'ENSEMBL_VEGA'};
      }
    }
  }
}

sub context_user {
  ## This menu only appears on user pages, e.g. account management, db admin
  ## Menus for general dynamic pages are in Document::Configure::common_menu_items

  my $self = shift;
  my $obj = $self->{object};

  ## this menu clashes with mini one on non-account pages, so remove it
  $self->delete_block('ac_mini');

  ## Is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER'};

  if ($user_id) {
    my $flag = 'user';
    $self->add_block( $flag, 'bulleted', "My Account" );


    $self->add_entry( $flag, 'text' => "Account summary",
                                    'href' => "/common/user_login?node=accountview" );
    $self->add_entry( $flag, 'text' => "Update my details",
                                    'href' => "/common/user_update" );
    $self->add_entry( $flag, 'text' => "Change my password",
                                    'href' => "/common/user_pw_change" );
    $self->add_entry( $flag, 'text' => "Manage my bookmarks",
                                    'href' => "/common/user_manage_bkmarks" );
    $self->add_entry( $flag, 'text' => "Log out",
                                    'href' => "/common/user_logout" );

    ## get user status
    my $help_access = $obj->get_user_privilege($user_id, 'help');
    my $news_access = $obj->get_user_privilege($user_id, 'news');

    $flag = 'help';
    if ($help_access) {
      $self->add_block( $flag, 'bulleted', "Helpdesk Admin" );
      $self->add_entry( $flag, 'text' => "Add Help Item",
                                    'href' => "/common/help_add" );
      $self->add_entry( $flag, 'text' => "Edit Help Item",
                                    'href' => "/common/help_edit" );
      $self->add_entry( $flag, 'text' => "Build Help Article",
                                    'href' => "/common/help_article" );
    }

    $flag = 'news';
    if ($news_access) {
      $self->add_block( $flag, 'bulleted', "News DB Admin" );
      $self->add_entry( $flag, 'text' => "Add News",
                                    'href' => "/common/news_add" );
      $self->add_entry( $flag, 'text' => "Edit News",
                                    'href' => "/common/news_edit" );
      $self->add_entry( $flag, 'text' => "Add old news",
                                    'href' => "/common/news_add_old" );
      $self->add_entry( $flag, 'text' => "Edit old news",
                                    'href' => "/common/news_edit_old" );
    }
  }
  else {
    my $flag = 'ac_full';
    $self->add_block( $flag, 'bulleted', "My Account" );
    
    $self->add_entry( $flag, 'text' => "Login",
                                  'href' => "/common/user_login" );
    $self->add_entry( $flag, 'text' => "Register",
                                  'href' => "/common/user_register" );
    $self->add_entry( $flag, 'text' => "Lost Password",
                                  'href' => "/common/user_pw_lost" );
    $self->add_entry( $flag, 'text' => "About User Accounts",
                                    'href' => "/info/about/accounts.html" );
  }

}


sub wizard_panel {
  my ($self, $caption) = @_;
  my $object = $self->{object};
  my $wizard = $self->{wizard};
  my $node = $wizard->current_node($object);

  ## determine object type
  my @module_bits = split('::', ref($wizard));
  my $type = $module_bits[-1];

  ## check for a node-specific title
  my $title = $wizard->node_value($node, 'title');
  $caption = $title if $title;

  ## call the relevant configuration method
  if ($wizard->isa_page($node)) { ## create panel(s)
    if ($object->param('feedback')) { ## check for error messages
      my $message = $wizard->get_message($object->param('feedback'));
      $self->wizard_feedback($message, $object->param('feedback'), $object->param('error'));
    }
    ## create generic panel
    if (my $panel = $self->new_panel('Image',
        'code'    => "info$self->{flag}",
        'caption' => $caption,
        'object'  => $self->{object},
        'wizard'  => $self->{wizard})
    ) {
      my $method = $type.'::'.$node;
      $panel->add_components($node, 'EnsEMBL::Web::Component::'.$method);
      if ($wizard->isa_form($node)) {
        $panel->add_form($self->{page}, $node, 'EnsEMBL::Web::Wizard::'.$method);
      }
      $self->{page}->content->add_panel($panel);
    }

  }

}

sub wizard_feedback {
  my ($self, $feedback, $error) = @_;
  my $caption;

  if ($error > 0) {
    $feedback = '<span class="red"><strong>'.$feedback.'</strong></span>';
    $caption = 'Error';
  }

  $self->{page}->content->add_panel(
    new EnsEMBL::Web::Document::Panel(
      'object'  => $self->{'object'},
      'code'    => "",
      'caption' => $caption,
      'content' => qq(<p>$feedback</p>),
    )
  );

}

1;

__END__
                                                                                
=head1 EnsEMBL::Web::Configuration
                                                                                
=head2 SYNOPSIS

Children of this base class are called from the EnsEMBL::Web::Document::WebPage object, according to parameters passed in from the controller script. There are two ways of configuring the object:

1) A simple view 'myview' uses a generic WebPage method and only needs to define its data object type, thus

    EnsEMBL::Web::Document::WebPage::simple_with_redirect( 'Gene' );

2) A more complex view (e.g. one that uses a form to collect additional user configuration settings) needs to call the configure method and pass more parameters, thus   

    foreach my $object( @{$webpage->dataObjects} ) {
        $webpage->configure( $object, 'myview', 'context_menu');
    }
    $webpage->render(); 

=head2 DESCRIPTION
                                                                                
This class consists of methods for configuring views to display [module] data. There are two types of method in a Configuration module, views and context menus, and every Configuration module should contain at least one example of each. 

'View' methods create the main content of a typical Ensembl dynamic page. Each creates one or more EnsEMBL::Web::Panel objects and adds one or more components to each panel.

'Context menu' methods create a menu of links to content related to that in the view. A generic menu method may be shared between similar views, or each view can have its own custom menu.

                                                                                
=head2 METHODS

All methods take an EnsEMBL::Web::Configuration::[module] object as their only argument (having already been instantiated by the WebPage object)
                                                                                
=head3 B<method_name>
                                                                                
Description:

[only include next two if different from standard]    
                                                                                
Arguments:     
                                                                                
Returns:  

=head3 B<Accessor methods>      

=over 4

=item B<method_name>          Sets/returns a hash of doodah values

=item B<another_method>       Returns a reference to an array of Whatsits

=back

=head2 BUGS AND LIMITATIONS
                                                                                
None known at present.
                                                                                                                                                              
=head2 AUTHOR
                                                                                
James Smith, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut



