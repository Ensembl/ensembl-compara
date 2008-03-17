package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );


sub user_data {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UserData';
  my $start         = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'start' ));

  ## File upload/link section of wizard
  my $start_logic   = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'start_logic'));
  my $distribution  = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'distribution'));
  my $file_guide    = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'file_guide'));
  my $file_logic    = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'file_logic'));
  my $file_details  = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'file_details'));
  my $file_upload   = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'file_upload'));
  my $url_data      = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'url_data'));
  my $file_feedback = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'file_feedback'));
  my $user_record   = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'user_record'));

  ## DAS section of wizard
  my $das_servers   = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'das_servers'));
  my $das_sources   = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'das_sources'));

  my $conf_tracks   = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'conf_tracks'));
  my $finish        = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'finish'));

  ## LINK PAGE NODES TOGETHER
  $wizard->add_connection(( from => $start,   to => $start_logic));

  ## DAS
  $wizard->add_connection(( from => $das_servers,    to => $das_sources));
  $wizard->add_connection(( from => $das_servers,    to => $das_servers));
  $wizard->add_connection(( from => $das_sources,    to => $conf_tracks));
  $wizard->add_connection(( from => $das_sources,    to => $finish));

  ## File upload
  $wizard->add_connection(( from => $distribution,   to => $file_guide));
  $wizard->add_connection(( from => $file_guide,     to => $file_logic));
  $wizard->add_connection(( from => $file_details,   to => $file_upload));
  $wizard->add_connection(( from => $file_upload,    to => $file_feedback));
  $wizard->add_connection(( from => $file_feedback,  to => $conf_tracks));
  $wizard->add_connection(( from => $file_feedback,  to => $finish));

  ## User record

  ## Universal end-point!
  $wizard->add_connection(( from => $conf_tracks,    to => $finish));

}

sub wizard_menu {
  my $self = shift;
  #my $object = $self->{object};

  $self->{page}->menu->delete_block( 'ac_mini');
  $self->{page}->menu->delete_block( 'archive');

}

1;
