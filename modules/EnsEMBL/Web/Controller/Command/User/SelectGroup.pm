package EnsEMBL::Web::Controller::Command::User::SelectGroup;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Record;
use Data::Dumper;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my ($records_accessor) = grep { $_ eq $user->plural($cgi->param('type')) }
                            keys %{ $user->get_has_many };
                            
  my ($user_record) = grep { $_->id == $cgi->param('id') } @{ $user->$records_accessor };
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->user_id});
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
  my $self = shift;
 
    my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'User/SelectGroup',
    'objecttype' => 'User',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'select_group' );
    }
    $webpage->action();
  }
 
}

}

1;
