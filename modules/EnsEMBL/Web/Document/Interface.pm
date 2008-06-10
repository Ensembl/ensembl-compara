package EnsEMBL::Web::Document::Interface;

### Module to create a standardized, quick'n'dirty interface to MySQL databases

### To use this module and its associated modules, you need the following:
### 1. A controller script, e.g. perl/common/my_database
### 2. In Configuration::[ObjectType], a method named 'interface_menu', with links to script
###    e.g. '/common/my_database?dataview=add'
###         '/common/my_database?dataview=select_to_edit'
###         '/common/my_database?dataview=select_to_delete'
### 3. An adaptor containing methods to insert and update (and optionally delete) the records 
###    to be manipulated, including setting user and timestamp fields where appropriate

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::RegObj;

use strict;
our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{

sub simple {
  ### Creates a new Proxy::Object, attempts to configure a suitable context menu 
  ### and does some access and error checking
  ### N.B. Doesn't render page - that is done after the interface is defined
  my ($type, $parameter) = @_;
  my $self = __PACKAGE__->new((
      'objecttype' => $type, 
      'interface' => undef,
    ));

  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    foreach my $object( @{$self->dataObjects} ) {
      my @args = ($object);
      if ($parameter->{'menu'}) {
        push @args, $parameter->{'menu'};
      }
      $self->configure(@args); ## Now uses own version, not parent's
    }
    $self->factory->fix_session;
  }
  return $self;
}

sub process {
  ### Performs a built-in action if available, or displays an error page.
  my ($self, $interface, $conf) = @_;
  my $object = $self->dataObjects->[0];
  my $action = $object->param('dataview') ? $object->param('dataview') : $interface->default_view;

  my $config_module_name = $conf ? $conf : 'EnsEMBL::Web::Configuration::Interface';
  if( $self->dynamic_use( $config_module_name ) ) {
    my $CONF = $config_module_name->new($self->page, $object);
    ## is this action defined in the Interface Configuration module?
    if ($CONF->can($action)) {
      if ($action =~ /delete/ && !$interface->permit_delete) {
        ## For safety reasons, default is to disallow records to be deleted
        $self->page->content->add_panel(
          new EnsEMBL::Web::Document::Panel(
            'caption' => 'Permission Denied',
            'content' => qq(
          <p>Users are not permitted to delete records of this type. To "mothball" a record, choose an Edit option from the sidebar and alter the record status.</p> )
            )
        );
        $self->render;
      }
      else {
        my $url;
        eval { $url = $CONF->$action($object, $interface) }; 
        if( $@ ) { # Catch any errors and display as an "interface runtime error"
          $self->page->content->add_panel(
            new EnsEMBL::Web::Document::Panel(
              'caption' => 'Interface runtime error',
              'content' => sprintf( qq(
          <p>Unable to execute action $action owing to the following error:</p>
          <pre>%s</pre>), $self->_format_error($@) )
            )
          );
        }
        if ($url) {
          $self->redirect($url);
        }
        else {
          $self->render;
        }
      }
    }
    else {
      ## Error for non-standard or unspecified actions
      $self->page->content->add_panel(
        new EnsEMBL::Web::Document::Panel(
          'caption' => 'Invalid action request',
          'content' => qq(
          <p>Action <b>$action</b> is not specified. Please request a valid action.</p>)
        )
      );
    $self->render;
    } 
  }
  else {
warn "Can't use module $config_module_name!";
  } 
}

=pod
sub configure {
### Copy of 'configure' method from old Document::WebPage, since it's been modified
### and no longer works with Interface code
  my( $self, $object, @functions ) = @_;
  my $objecttype;
  if (ref($object)) { ## Actual object
    $objecttype = $object->__objecttype;
  }
  elsif ($object =~ /^\w+$/) { ## String (type of E::W object)
    $objecttype = $object;
  }
  else {
    $objecttype = 'Static';
  }
  $objecttype = 'DAS' if ($objecttype =~ /^DAS::.+/);

  my $flag = 0;
  my @T = ('EnsEMBL::Web', '', @{$ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_PLUGINS});

  my $FUNCTIONS_CALLED = {};
  while( my ($module_root, $X) = splice( @T, 0, 2) ) {

   # Starting with the standard EnsEMBL module configure
    # the script....
    # Then loop through the plugins in order after that...
    # First work out what the module name is - to see if it
    # can be "used"
    $flag ++;
    my $config_module_name = $module_root."::Configuration::$objecttype";

    if( $self->dynamic_use( $config_module_name ) ) { ## Successfully used
      # If it has been successfully used then look for
      # the functions named in the script "configure" line
      # of the script.
      my $CONF = $config_module_name->new( $self->page, $object, $flag );
      $CONF->{commander} = $self->{commander};
      $CONF->{command} = $self->{command};
      foreach my $FN ( @functions ) {
        if( $CONF->can($FN) ) {
    # If this configuration module can perform this function do so...
          eval { $CONF->$FN(); };
          $self->{wizard} = $CONF->{wizard};
          if( $@ ) { # Catch any errors and display as a "configuration runtime error"
            $self->page->content->add_panel(
              new EnsEMBL::Web::Document::Panel(
               'caption' => 'Configuration module runtime error',
               'content' => sprintf( qq(
    <p>
      Unable to execute configuration $FN from configuration module <b>$config_module_name</b>
      due to the following error:
    </p>
    <pre>%s</pre>), $self->_format_error($@) )
                       )
             );
          } else {
            $FUNCTIONS_CALLED->{$FN} = 1;
          }
        }
      }
    } elsif( $self->dynamic_use_failure( $config_module_name ) !~ /^Can't locate/ ) {
                           # Handle "use" failures gracefully...
                           # Firstly skip Can't locate errors
                           # o/w display a "compile time" error message.
      $self->page->content->add_panel(
        new EnsEMBL::Web::Document::Panel(
         'caption' => 'Configuration module compilation error',
         'content' => sprintf( qq(
    <p>
      Unable to use Configuration module <b>$config_module_name</b> due to
      the following error:
    </p>
    <pre>%s</pre>), $self->_format_error( $self->dynamic_use_failure( $config_module_name )) )
        )
      );
    }
  }
  foreach my $FN ( @functions ) {
    unless( $FUNCTIONS_CALLED->{$FN} ) {
      if( $objecttype eq 'DAS' ) {
        $self->problem('Fatal', 'Bad request', 'Unimplemented');
      } else {
        warn "Can't do configuration function $FN on $objecttype objects, or an error occurred when excuting that function.";
      }
    }
  }
  $self->add_error_panels(); # Add error panels to end of display!!
  $self->_prof("Script configured ($objecttype)");
}
=cut

}

1;
