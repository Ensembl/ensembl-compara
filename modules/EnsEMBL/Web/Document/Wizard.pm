package EnsEMBL::Web::Document::Wizard;

use strict;
use warnings;

use EnsEMBL::Web::Wizard;
use Apache2::Const qw(REDIRECT);
use CGI qw(escape escapeHTML);
use Data::Dumper;

use base qw(EnsEMBL::Web::Document::WebPage);

{

sub simple_wizard {
  my ($type, $method, $command) = @_;
  my $self = __PACKAGE__->new('objecttype' => $type, doctype => 'Popup', 'command' => $command );
  $self->page->{'_modal_dialog_'} =
    $self->page->renderer->{'r'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest' ||
    $self->factory->param( 'x_requested_with' ) eq 'XMLHttpRequest';
warn "SETTING MODAL DIALOG TO ". $self->page->{'_modal_dialog_'};

  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    $self->wizard( EnsEMBL::Web::Wizard->new({'scriptname' => '/'.$command->action->script_name }));
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $method, 'global_context', 'local_context' );
    }
    $self->wizard->set_object($self->dataObjects->[0]);

    $self->factory->fix_session;
    $self->process_node;
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
  my $self = shift;
  if ($self->wizard->current_node && $self->wizard->current_node->type eq 'logic') {
    my %parameter = %{$self->wizard->update_parameters};

    ## unpack returned parameters into a URL
    my $URL = $self->wizard->get_scriptname.'?';
    foreach my $param_name (keys %parameter) {
      ## assemble rest of url for non-exit redirects
      if (ref($parameter{$param_name}) eq 'ARRAY') {
        foreach my $param_value (@{$parameter{$param_name}}) {
          $URL .= $param_name.'='.CGI::escape($param_value).';';
        }
      }
      else {
        $URL .= $param_name.'='.CGI::escape($parameter{$param_name}).';';
      }
    }
    $URL =~ s/;$//; 

## Is this in the iframe???
    my $r = $self->page->renderer->{'r'};
    if( $self->factory->param('uploadto' ) eq 'iframe' ) {
      CGI::header( -type=>"text/html",-charset=>'utf-8' );
      printf q(<html><head><script type="text/javascript">
  window.parent.__modal_dialog_link_open_2( '%s' ,'File uploaded' );
</script>
</head><body><p>UP</p></body></html>), CGI::escapeHTML($URL);
    } else {
      $self->page->ajax_redirect($URL);
    }
  } else {
    my $content = $self->wizard->render_current_node;
    $self->page->content->add_panel(new EnsEMBL::Web::Document::Panel(
              'content' => $content,
    ));
    $self->render;
  }
}



}

1;
