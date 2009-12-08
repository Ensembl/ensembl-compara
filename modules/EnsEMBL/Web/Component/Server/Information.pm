package EnsEMBL::Web::Component::Server::Information;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Server);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $table = new EnsEMBL::Web::Document::HTML::TwoCol;
  $table->add_row( 'Admin', 
    sprintf( '<p><a href="mailto:%s">%s</a></p>',
      $object->species_defs->ENSEMBL_SERVERADMIN,
      $object->species_defs->ENSEMBL_SERVERADMIN
    ),1
  );
##-- Ensembl API version
  $table->add_row( 'Ensembl API', $object->species_defs->ENSEMBL_VERSION );
  $table->add_row( 'Webserver', $ENV{'SERVER_SOFTWARE'} );
##-- Perl version
  my $perl_v = $];
  my $major = int($perl_v);
  my $minor = int(($perl_v-$major)*1000);
  my $sub   = int(($perl_v-$major-$minor/1000)*1e6);
  $table->add_row( 'Perl version', sprintf('%d.%d.%d',$major,$minor,$sub) );
##-- MySQL versions...
  my $sth = $object->database( 'core' )->dbc->prepare("show variables like 'version_comment'");
  $sth->execute();
  my($X,$db) = $sth->fetchrow_array();
  $sth->finish;
  $sth = $object->database( 'core' )->dbc->prepare("select version()");
  $sth->execute;
  my( $version ) = $sth->fetchrow_array;
  $sth->finish;
  $version = $1 if $version =~ /(\d+\.\d+\.\d+)/;
  $table->add_row( 'Database', "$db (version $version)" );
  return $table->render;
}

1;    


