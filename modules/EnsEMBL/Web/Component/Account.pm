package EnsEMBL::Web::Component::Account;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Form;

use CGI;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);

sub edit_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Edit' if !$text;
  return sprintf(qq(<a class="modal_link" href="/Account/%s/Edit?id=%s;_referer=%s;x_requested_with=%s">%s</a>), 
          $module, $id, CGI::escape($self->object->param('_referer')), 
          CGI::escape($self->object->param('x_requested_with')), $text);
} 

sub delete_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Delete' if !$text;
  return sprintf(qq(<a class="modal_link" href="/Account/%s/Delete?id=%s;_referer=%s;x_requested_with=%s">%s</a>), 
          $module, $id, CGI::escape($self->object->param('_referer')), 
          CGI::escape($self->object->param('x_requested_with')), $text);
} 


sub share_link {
  my ($self, $call, $id) = @_;
  return sprintf(qq(<a class="modal_link" href="/Account/SelectGroup?id=%s;type=%s;_referer=%s;x_requested_with=%s">Share</a>), 
          $id, $call, CGI::escape($self->object->param('_referer')), CGI::escape($self->object->param('x_requested_with')) );
} 

sub dedupe {
### Removes objects from a list, using a hash of values to filter on and 
### the name of a method that retrieves a corresponding value from the object
  my ($self, $list, $compare, $method) = @_;
  my $ok = [];
  foreach my $obj (@$list) {
    push @$ok, $obj unless $compare->{$obj->$method};
  } 
  return $ok;
}

1;

