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
  my $wsc = $self->{object}->get_scriptconfig();
  foreach my $config_name ( @userconfigs ) {
    $self->{'object'}->attach_image_config( $self->{'object'}->script, $config_name );
    $self->{'object'}->user_config_hash( $config_name );
  }
  return unless $val || $rst;
  if( $wsc ) {
    $wsc->reset() if $rst;
    $wsc->update_config_from_parameter( $val ) if $val;
  }
  foreach my $config_name ( @userconfigs ) {
warn "$config_name...";
    my $wuc = $self->{'object'}->user_config_hash( $config_name );
#    my $wuc = $self->{'object'}->get_userconfig( $config_name );
    if( $wuc ) {
      $wuc->reset() if $rst;
      $wuc->update_config_from_parameter( $val ) if $val;
      $self->{object}->get_session->_temp_store( $self->{object}->script, $config_name );
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
  #foreach( qw(dd_menus_32.js new_contigview_support.js new_drag_imagemap.js new_old_zmenu.js new_zmenu.js new_support.js prototype.js ajax_zmenu.js) ) {
  foreach( qw(dd_menus_32.js new_contigview_support.js new_drag_imagemap.js new_old_zmenu.js new_zmenu.js new_support.js prototype.js) ) {
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

sub wizard_panel {
  ### Wrapper to automatically create panels for a wizard
  ### Makes the assumption that
  ### 1. The node contains a single component with the same name as the node
  ### 2. If the wizard is in a plugin, the component methods are in the same plugin
  my ($self, $caption) = @_;
  my $object = $self->{object};
  my $wizard = $self->{wizard};
  my $node = $wizard->current_node($object);
  my $namespace = $wizard->namespace;

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
        'code'    => "wizard",
        'caption' => $caption,
        'object'  => $self->{object},
        'wizard'  => $self->{wizard})
    ) {
      my $method = $type.'::'.$node;
      $panel->add_components($node, $namespace.'::Component::'.$method);
      if ($wizard->isa_form($node)) {
        $panel->add_form($self->{page}, $node, $namespace.'::Wizard::'.$method);
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

