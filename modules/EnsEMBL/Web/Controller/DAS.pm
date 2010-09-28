# $Id$

package EnsEMBL::Web::Controller::DAS;

### Prints the dynamically created components. Loaded either via AJAX (if available) or parallel HTTP requests.

use strict;

use EnsEMBL::Web::Configuration::DAS;
use EnsEMBL::Web::Document::Page::Dynamic;

use base qw(EnsEMBL::Web::Controller::Component);

sub page_type     { return 'Dynamic';          }
sub renderer_type { return 'Apache';           }
sub request       { return $_[0]->hub->script; }

sub page {
  my $self = shift;
  
  return $self->{'page'} ||= new EnsEMBL::Web::Document::Page::Dynamic({
    input        => $self->input,
    hub          => $self->hub, 
    species_defs => $self->species_defs, 
    renderer     => $self->renderer, 
    outputtype   => 'DAS'
  });
}

sub configure {
  my $self          = shift;
  my $request       = $self->request;
  my $configuration = new EnsEMBL::Web::Configuration::DAS($self->page, $self->hub, $self->builder);
  
  if ($configuration->can($request)) {
    $configuration->$request();
  } else {
    $self->add_error('Fatal error - bad request', "Function '$request' is not implemented");
  }
}

1;
