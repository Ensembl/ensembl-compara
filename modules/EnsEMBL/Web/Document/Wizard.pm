package EnsEMBL::Web::Document::Wizard;

use strict;
use warnings;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::Wizard;
use Apache2::Const qw(REDIRECT);
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{

sub simple_wizard {
  ## TO DO: implement access restrictions
  my ($type, $menu, $access) = @_;
  my $self = __PACKAGE__->new( 'doctype' => 'Popup', 'objecttype' => $type );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    $self->wizard( EnsEMBL::Web::Wizard->new({'cgi' => $self->factory->input}) );
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, $menu );
    }

    $self->factory->fix_session;
    $self->process_node(${$self->dataObjects}[0]);
  }
}

sub wizard {
### a
  my ($self, $wizard) = @_;
  if ($wizard) {
    $self->{'wizard'} = $wizard;
  }
  return $self->{'wizard'};
}

sub process_node {
  my ($self, $object) = @_;
  if ($self->wizard->current_node && $self->wizard->current_node->type eq 'logic') {
    my %parameter = %{$self->wizard->redirect_current_node};

    ## unpack returned parameters into a URL
    my $URL = '/common/'.$object->script.'?';
    foreach my $param_name (keys %parameter) {
      ## assemble rest of url for non-exit redirects
      if (ref($parameter{$param_name}) eq 'ARRAY') {
        foreach my $param_value (@{$parameter{$param_name}}) {
          $URL .= $param_name.'='.$param_value.';';
        }
      }
      else {
        $URL .= $param_name.'='.$parameter{$param_name}.';';
      }
    }
    $URL =~ s/;$//; 
    my $r = $self->page->renderer->{'r'};

    ## do redirect
    $r->headers_out->add( "Location" => $URL );
    $r->err_headers_out->add( "Location" => $URL );
    $r->status( Apache2::Const::REDIRECT );
  }
  else {
    my $content;
    if ($object->param('error_message')) {
      $content = $self->wizard->render_error_message;
    }
    else {
      $content = $self->wizard->render_current_node;
    }
    $self->page->content->add_panel(new EnsEMBL::Web::Document::Panel(
              'content' => $content,
    ));
    $self->render;
  }
}



}

1;
