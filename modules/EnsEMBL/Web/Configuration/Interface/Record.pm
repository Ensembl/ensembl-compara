package EnsEMBL::Web::Configuration::Interface::Record;

### Sub-class to do user-specific interface functions

use strict;

use CGI;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Configuration::Interface;


our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  ### Saves changes to the record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  my ($primary_key) = $interface->data->primary_columns;

  my $id = $object->param($primary_key) || $object->param('id');

  if ($object->param('owner_type')) {
    #$interface->data->attach_owner($object->param('owner_type'));
  }
  
  $interface->cgi_populate($object);

  ## Add owner to new records
  ## N.B. Don't need this option for group records, as they are created via sharing
  unless ($id) {
    $interface->data->user_id($ENV{'ENSEMBL_USER_ID'});
  }

  ## Do any type-specific data-munging
  if ($interface->data->__type eq 'bookmark') {
    _bookmark($object, $interface);
  } elsif ($interface->data->__type eq 'configuration' && $object->param('rename') ne 'yes') {
    _configuration($object, $interface);
  }

  my $success = $interface->data->save;

  my $script = $interface->script_name;
  my $url;
  if ($success) {
    if ($object->param('owner_type') eq 'group') {
      #$interface->data->populate($id);
      $url = "/Account/Group?id=".$interface->data->webgroup_id;
    }
    else {
      $url = "/$script?dataview=success";
    }
  } else {
    $url = "/$script?dataview=failure";
  }
  
  if ($object->param('url')) {
    $url .= ';url='.CGI::escape($object->param('url'));
  }
  
  if ($object->param('mode')) {
    $url .= ';mode='.$object->param('mode');
  }
  $url .= ';_referer='.CGI::escape($object->param('_referer'));
  
  return $url;

}

sub delete {
  ### Deletes record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;

  my ($primary_key) = $interface->data->primary_columns;
  my $id = $object->param($primary_key) || $object->param('id');
  if ($object->param('owner_type')) {
    #$interface->data->attach_owner($object->param('owner_type'));
  }
  #$interface->data->populate($id);

  my $success = $interface->data->destroy;
  my $script = $interface->script_name;
  my $url;
  if ($success) {
    if ($object->param('owner_type') eq 'group') {
      #$interface->data->populate($id);
      $url = "/Account/Group?id=".$interface->data->webgroup_id;
    }
    else {
      $url = "/$script?dataview=success";
    }
    $url = "/$script?dataview=success";
  }
  return $url;
}


sub _bookmark {
  ## external links will fail unless they begin with http://
  my ($object, $interface) = @_;
  if ($interface->data->url && $interface->data->url !~ /^http/) {
    $interface->data->url('http://'.$interface->data->url);
  }
}

sub _configuration {
  ## Get current config settings from session
  my ($object, $interface) = @_;

  my $referer = $object->param('url');
  my $script = 'contigview';

  my ($ref_url, $ref_args) = split(/\?/, $referer);
  my @items = split(/\//, $ref_url);
  if ($#items == 4) {
    $script = pop @items;
  }

  my $session = $ENSEMBL_WEB_REGISTRY->get_session;
  $session->set_input($object->[1]->{_input});
  my $string = $session->get_view_config_as_string($script);
  $interface->data->viewconfig($string);
}

1;
