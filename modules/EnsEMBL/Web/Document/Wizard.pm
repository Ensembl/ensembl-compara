package EnsEMBL::Web::Document::Wizard;

use strict;
use warnings;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::Commander;

our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{

sub simple_wizard {
  ## TO DO: implement access restrictions
  my ($type, $menu, $access) = @_;
  my $self = __PACKAGE__->new( 'objecttype' => $type, {'access'=>$access} );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    $self->commander(EnsEMBL::Web::Commander->new('cgi' => $self->factory->input));
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, $menu );
    }

    $self->factory->fix_session;
    $self->render_node;
  }
}

sub commander {
### a
  my ($self, $commander) = @_;
  if ($commander) {
    $self->{'commander'} = $commander;
  }
  return $self->{'commander'};
}

sub render_node {
  my $self = shift;

  $self->page->content->add_panel(new EnsEMBL::Web::Document::Panel(
              'content' => $self->commander->render_current_node($self->dataObjects->[0])
  ));
  $self->render;

}

}

1;
