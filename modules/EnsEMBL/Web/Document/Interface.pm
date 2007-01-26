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
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::DBSQL::InterfaceAdaptor;
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
      'access' => $parameter->{'access'}
    ));

  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    ## check script access - default is to allow, so unrestricted pages don't break
    my $permitted = $self->{'access'} ? $self->check_access($self->{'access'}) : 1;
    if ($permitted) {
      foreach my $object( @{$self->dataObjects} ) {
        $self->configure( $object, 'interface_menu');
      }
      $self->factory->fix_session;
    }
    else {
      my $URL = '/common/access_denied';
      $self->redirect($URL);
    }
  }
  return $self;
}

sub process {
  ### Performs a built-in action if available, or displays an error page.
  my ($self, $interface) = @_;
  my $object = $self->dataObjects->[0];
  my $action = $object->param('dataview');

  my $config_module_name = 'EnsEMBL::Web::Configuration::Interface';
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

sub adaptors {
  ### Instantiates an InterfaceAdaptor object, given a database adaptor name and table name,
  ### plus a UserAdaptor if needed
  my ($self, $db_adaptor, $table) = @_;
  my $data_db = $ENSEMBL_WEB_REGISTRY->$db_adaptor;
  my $data_adaptor = EnsEMBL::Web::DBSQL::InterfaceAdaptor->new((
                                          handle => $data_db,
                                          table  => $table
                                        ));
  my $user_adaptor;
  if ($db_adaptor eq 'userAdaptor') {
    $user_adaptor = $data_adaptor;
  }
  else {
    my $user_db = $ENSEMBL_WEB_REGISTRY->userAdaptor;
    $user_adaptor = EnsEMBL::Web::DBSQL::UserAdaptor->new((
                                          handle => $user_db,
                                          table  => 'user'
                                        ));
  }
  return [$data_adaptor, $user_adaptor];
}

}

1;
