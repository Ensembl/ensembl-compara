package EnsEMBL::Web::Component::Account;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component);

sub edit_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Edit' if !$text;
  return sprintf qq(<a class="modal_link" href="/Account/%s/Edit?id=%s">%s</a>), $module, $id, $text;
} 

sub delete_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Delete' if !$text;
  return sprintf qq(<a class="modal_link" href="/Account/%s/Delete?id=%s">%s</a>), $module, $id, $text;
} 


sub share_link {
  my ($self, $call, $id) = @_;
  return sprintf qq(<a class="modal_link" href="/Account/SelectGroup?id=%s;type=%s">Share</a>), $id, $call;
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

