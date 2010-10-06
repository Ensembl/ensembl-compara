# $Id$

package EnsEMBL::Web::Command;

### Parent module for "Command" steps, in a wizard-type process, which 
### munge data and redirect to a new page rather than rendering HTML

use strict;

use EnsEMBL::Web::Interface;

use base qw(EnsEMBL::Web::Root); 

sub new {
  my ($class, $data) = @_;
  my $self = {%$data};
  bless $self, $class;
  return $self;
}

sub object :lvalue { $_[0]->{'object'}; }
sub hub    :lvalue { $_[0]->{'hub'};    }
sub page   :lvalue { $_[0]->{'page'};   }
sub node   :lvalue { $_[0]->{'node'};   }
sub r              { return $_[0]->page->renderer->r; }

sub script_name {
  my $self = shift;
  my $object = $self->object;
  my $path = $object->species_path . '/' if $object->species =~ /_/;
  return $path . $object->type . '/' . $object->action;
}

sub ajax_redirect {
  my ($self, $url, $param, $anchor) = @_;
  $self->page->ajax_redirect($self->url($url, $param, $anchor));
}

sub interface {
  my $self = shift;
  $self->{'interface'} ||= new EnsEMBL::Web::Interface;
  return $self->{'interface'};
}

1;
