#!/usr/local/bin/perl

package EnsEMBL::Web::ExternalDAS;
use strict;
use Data::Dumper;

sub new {
  my( $class, $proxiable ) = @_;
  my $self = { 
    'proxiable'  => $proxiable,
    'configs'  => {},
    'data'     => {},
    'defaults' => {
      'LABELFLAG'      => 'u',
      'STRAND'         => 'b',
      'DEPTH'          => '4',
      'GROUP'          => '1',
      'DEFAULT_COLOUR' => 'grey50',
      'STYLESHEET'     => 'Y',
      'SCORE'          => 'N',
      'FG_MERGE'       => 'A',
      'FG_GRADES'      => 20,
      'FG_DATA'        => 'O',
      'FG_MIN'         => 0,
      'FG_MAX'         => 100,
    },
  };
  bless($self,$class);
  $self->get_sources(); ## Get configurations...
  return $self;
}

sub getConfigs {
  my( $self, @Q ) = @_;
  while( my($key,$value) = splice(@Q,0,2) ) {
warn "JS5 DAS ... $key->$value ...";
    ($key,$value) = ('contigviewbottom','contigviewbottom') if $key eq 'contigview';
    $self->{'configs'}{$key} = $self->{'proxiable'}->image_config_hash( $value );
  }
}

sub add_das_source {
  my( $self, $hash_ref ) = @_;

  $self->amend_source( {
    'enable'     => $hash_ref->{enable},
    'mapping'    => $hash_ref->{mapping},
    'select'     => $hash_ref->{select},
    'on'         => 'on',
    'name'       => $hash_ref->{name},
    'color'      => $hash_ref->{color},           
    'col'        => $hash_ref->{col},           
    'help'       => $hash_ref->{help},           
    'mapping'    => $hash_ref->{mapping},           
    'active'     => $hash_ref->{active},           
    'URL'        => $hash_ref->{url},
    'dsn'        => $hash_ref->{dsn},
    'linktext'   => $hash_ref->{linktext},
    'linkurl'    => $hash_ref->{linkurl},
    'caption'    => $hash_ref->{caption},
    'label'      => $hash_ref->{label},
    'url'        => $hash_ref->{url},
    'protocol'   => $hash_ref->{protocol},
    'domain'     => $hash_ref->{domain},
    'type'       => $hash_ref->{type},
    'labelflag'  => $hash_ref->{labelflag},
    'strand'     => $hash_ref->{strand},
    'group'      => $hash_ref->{group},
    'depth'      => $hash_ref->{depth},
    'stylesheet' => $hash_ref->{stylesheet},
    'score'      => $hash_ref->{score},
    'fg_merge'   => $hash_ref->{fg_merge},
    'fg_data'    => $hash_ref->{fg_data},
    'fg_grades'  => $hash_ref->{fg_grades},
    'fg_max'     => $hash_ref->{fg_max},
    'fg_min'     => $hash_ref->{fg_min},
    'species'    => $self->{'proxiable'}->species,
  } );

  my $key     = $hash_ref->{name};
  my @configs = @{$hash_ref->{enable}};
  foreach my $cname (@configs) {
    next if $cname eq 'geneview';
    my $config = $self->{'configs'}->{$cname};
    next unless $config;
    my $def = $self->{'defaults'};  
    $config->set( "managed_extdas_$key", "on",          'on',                                                                  1);
    $config->set( "managed_extdas_$key", "dep",         defined($hash_ref->{depth}) ? $hash_ref->{depth}      : $def->{'DEPTH'},       1);
    $config->set( "managed_extdas_$key", "group",       $hash_ref->{group}          ? $hash_ref->{group}      : $def->{'GROUP'},       1);
    $config->set( "managed_extdas_$key", "str",         $hash_ref->{strand}         ? $hash_ref->{strand}     : $def->{'STRAND'},      1);
    $config->set( "managed_extdas_$key", "stylesheet",  $hash_ref->{stylesheet}     ? $hash_ref->{stylesheet} : $def->{'STYLESHEET'},  1);
    $config->set( "managed_extdas_$key", "score",       $hash_ref->{score}          ? $hash_ref->{score}      : $def->{'SCORE'},       1);
    $config->set( "managed_extdas_$key", "fg_merge",    $hash_ref->{fg_merge}       ? $hash_ref->{fg_merge}   : $def->{'FG_MERGE'},    1);
    $config->set( "managed_extdas_$key", "fg_grades",   $hash_ref->{fg_grades}      ? $hash_ref->{fg_grades}  : $def->{'FG_GRADES'},   1);
    $config->set( "managed_extdas_$key", "fg_data",     $hash_ref->{fg_data}        ? $hash_ref->{fg_data}    : $def->{'FG_DATA'},     1);
    $config->set( "managed_extdas_$key", "fg_min",      $hash_ref->{fg_min}         ? $hash_ref->{fg_min}     : $def->{'FG_MIN'},      1);
    $config->set( "managed_extdas_$key", "fg_max",      $hash_ref->{fg_max}         ? $hash_ref->{fg_max}     : $def->{'FG_MAX'},      1);
    $config->set( "managed_extdas_$key", "lflag",       $hash_ref->{labelflag}      ? $hash_ref->{labelflag}  : $def->{'LABELFLAG'},   1);
    $config->set( "managed_extdas_$key", "manager",     'das',                                                                 1);
    $config->set( "managed_extdas_$key", "col",         $hash_ref->{col} || $hash_ref->{color} ,                                       1);
    $config->set( "managed_extdas_$key", "enable",      $hash_ref->{enable} ,                                                      1);
    $config->set( "managed_extdas_$key", "mapping",     $hash_ref->{mapping} ,                                                     1);
#   $config->set( "managed_extdas_$key", "help",        $hash_ref->{help} || '',                                                   1);
    $config->set( "managed_extdas_$key", "linktext",    $hash_ref->{linktext} || '',                                               1);
    $config->set( "managed_extdas_$key", "linkurl",     $hash_ref->{linkurl} || '',                                                1);
##3 we need to store the configuration...
    $config->save;
  }

  $self->save_sources();
}

sub amend_source {
  my( $self, $hash_ref ) = @_;
#  my $key = join('/', $hash_ref->{'url'}, $hash_ref->{'dsn'}, $hash_ref->{'type'});
  my $key = $hash_ref->{'name'};
  $self->{'data'}->{ $key } = $hash_ref;
  return $key;
}

sub delete_das_source {
  my( $self, $key ) = @_;
  my $session = $self->{'proxiable'}->session;
  my $das_config = $session->get_das_config( $key );
  $das_config->delete();
  delete $self->{'data'}{$key};
  foreach my $config ( values %{$self->{'configs'}}) {
    $config->set( "managed_extdas_$key", "on", "off" , 1);
    $config->save;
  }
}

sub get_sources {
  my $self = shift;
  my $session = $self->{'proxiable'}->session;
  if( $session ) {
    foreach my $hash_ref ( $session->get_das() ) {
      $self->{'data'}{$hash_ref->{'key'}} = $hash_ref;
    }
  }
  return;
}

sub save_sources {
  my $self = shift;
  my $session = $self->{'proxiable'}->session;
  if( $session ) {
    foreach my $key ( %{ $self->{'data'}} ) {
      $session->save_das( $key , $self->{'data'}{$key} );
    }
  }
}

1;
