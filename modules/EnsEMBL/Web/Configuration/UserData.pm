package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );


sub user_data_wizard {
  my $self   = shift;
  my $object = $self->{'object'};

  my $commander = $self->commander;

  my $module = 'EnsEMBL::Web::Commander::Node::UserData';
  my $start         = $commander->create_node(( object => $object, module => $module, name => 'start' ));
  my $das_servers   = $commander->create_node(( object => $object, module => $module, name => 'das_servers'));
  my $das_sources   = $commander->create_node(( object => $object, module => $module, name => 'das_sources'));
  my $conf_tracks   = $commander->create_node(( object => $object, module => $module, name => 'conf_tracks'));
  my $file_info     = $commander->create_node(( object => $object, module => $module, name => 'file_info'));
  my $file_upload   = $commander->create_node(( object => $object, module => $module, name => 'file_upload'));
  my $file_feedback = $commander->create_node(( object => $object, module => $module, name => 'file_feedback'));
  my $user_record   = $commander->create_node(( object => $object, module => $module, name => 'user_record'));
  my $finish        = $commander->create_node(( object => $object, module => $module, name => 'finish'));

  ## Starting choices
  $commander->add_connection(( type => 'option', conditional => 'option', predicate => 'das', 
                              from => $start, to => $das_servers));
  $commander->add_connection(( type => 'option', conditional => 'option', predicate => 'file', 
                              from => $start, to => $file_info));
  $commander->add_connection(( type => 'option', conditional => 'option', predicate => 'user', 
                              from => $start, to => $user_record));
  ## DAS section
  $commander->add_connection(( type => 'link', from => $das_servers,    to => $das_sources));
  $commander->add_connection(( type => 'link', from => $das_servers,    to => $das_servers));
  $commander->add_connection(( type => 'link', from => $das_sources,    to => $conf_tracks));
  $commander->add_connection(( type => 'link', from => $das_sources,    to => $finish));
  $commander->add_connection(( type => 'option', conditional => 'filter', predicate => 'das', 
                              from => $das_servers, to => $das_servers));

  ## File upload
  $commander->add_connection(( type => 'option', conditional => 'option', predicate => '', 
                              from => $file_info, to => $file_upload));
  $commander->add_connection(( type => 'link', from => $file_upload,    to => $file_feedback));
  $commander->add_connection(( type => 'link', from => $file_feedback,  to => $conf_tracks));
  $commander->add_connection(( type => 'link', from => $file_feedback,  to => $finish));

  ## User record

  ## Universal end-point!
  $commander->add_connection(( type => 'link', from => $conf_tracks,    to => $finish));

}

sub wizard_menu {
  my $self = shift;
  #my $object = $self->{object};

  $self->{page}->menu->delete_block( 'ac_mini');
  $self->{page}->menu->delete_block( 'archive');

}

1;
