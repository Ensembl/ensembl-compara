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
  ### Creates a new Proxy::Object, configures context menus and does some error checking
  ### N.B. Doesn't render page - that is done after the interface is defined
  my ($object_type, $doc_type) = @_;
  my $self = __PACKAGE__->new((
      'objecttype' => $object_type, 
      'interface' => undef,
      'doctype'   => $doc_type
    ));
  $self->page->{'_modal_dialog_'} = $self->page->renderer->{'r'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure($object, 'global_context', 'local_context'); 
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
          $self->page->ajax_redirect($url);
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
          <p>Action <strong>$action</strong> is not specified. Please request a valid action.</p>)
        )
      );
    $self->render;
    } 
  }
  else {
    warn "Can't use module $config_module_name!";
  } 
}

}

1;
