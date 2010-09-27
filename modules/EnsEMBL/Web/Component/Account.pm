package EnsEMBL::Web::Component::Account;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component);

sub edit_link {
  my ($self, $module, $id, $text) = @_;
  $text ||= 'Edit';
  return qq{<a class="modal_link" href="/Account/$module/Edit?id=$id">$text</a>};
} 

sub delete_link {
  my ($self, $module, $id, $text, $class) = @_;
  $text ||= 'Delete';
  return qq{<a class="modal_link $class" href="/Account/$module/Delete?id=$id">$text</a>};
} 


sub share_link {
  my ($self, $call, $id) = @_;
  return qq{<a class="modal_link" href="/Account/SelectGroup?id=$id;type=$call">Share</a>};
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

