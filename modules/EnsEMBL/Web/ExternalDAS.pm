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
    $self->{'configs'}{$key} = $self->{'proxiable'}->user_config_hash( $value );
  }
}

sub add_das_source {
  my( $self, $href ) = @_;

  $self->amend_source( {
    'enable'     => $href->{enable},
    'mapping'    => $href->{mapping},
    'select'     => $href->{select},
    'on'         => 'on',
    'name'       => $href->{name},
    'color'      => $href->{color},           
    'col'        => $href->{col},           
    'help'       => $href->{help},           
    'mapping'    => $href->{mapping},           
    'active'     => $href->{active},           
    'URL'        => $href->{url},
    'dsn'        => $href->{dsn},
    'linktext'   => $href->{linktext},
    'linkurl'    => $href->{linkurl},
    'caption'    => $href->{caption},
    'label'      => $href->{label},
    'url'        => $href->{url},
    'protocol'   => $href->{protocol},
    'domain'     => $href->{domain},
    'type'       => $href->{type},
    'labelflag'  => $href->{labelflag},
    'strand'     => $href->{strand},
    'group'      => $href->{group},
    'depth'      => $href->{depth},
    'stylesheet' => $href->{stylesheet},
    'score'      => $href->{score},
    'fg_merge'   => $href->{fg_merge},
    'fg_data'    => $href->{fg_data},
    'fg_grades'  => $href->{fg_grades},
    'fg_max'     => $href->{fg_max},
    'fg_min'     => $href->{fg_min},
    'species'    => $self->{'proxiable'}->species,
  } );

  my $key     = $href->{name};
  my @configs = @{$href->{enable}};
  foreach my $cname (@configs) {
    next if $cname eq 'geneview';
    my $config = $self->{'configs'}->{$cname};
    next unless $config;
      
    $config->set( "managed_extdas_$key", "on",          'on',                                                                               1);
    $config->set( "managed_extdas_$key", "dep",         defined($href->{depth}) ? $href->{depth}      : $self->{'defaults'}{'DEPTH'},       1);
    $config->set( "managed_extdas_$key", "group",       $href->{group}          ? $href->{group}      : $self->{'defaults'}{'GROUP'},       1);
    $config->set( "managed_extdas_$key", "str",         $href->{strand}         ? $href->{strand}     : $self->{'defaults'}{'STRAND'},      1);
    $config->set( "managed_extdas_$key", "stylesheet",  $href->{stylesheet}     ? $href->{stylesheet} : $self->{'defaults'}{'STYLESHEET'},  1);
    $config->set( "managed_extdas_$key", "score",       $href->{score}          ? $href->{score}      : $self->{'defaults'}{'SCORE'},       1);
    $config->set( "managed_extdas_$key", "fg_merge",    $href->{fg_merge}       ? $href->{fg_merge}   : $self->{'defaults'}{'FG_MERGE'},    1);
    $config->set( "managed_extdas_$key", "fg_grades",   $href->{fg_grades}      ? $href->{fg_grades}  : $self->{'defaults'}{'FG_GRADES'},   1);
    $config->set( "managed_extdas_$key", "fg_data",     $href->{fg_data}        ? $href->{fg_data}    : $self->{'defaults'}{'FG_DATA'},     1);
    $config->set( "managed_extdas_$key", "fg_min",      $href->{fg_min}         ? $href->{fg_min}     : $self->{'defaults'}{'FG_MIN'},      1);
    $config->set( "managed_extdas_$key", "fg_max",      $href->{fg_max}         ? $href->{fg_max}     : $self->{'defaults'}{'FG_MAX'},      1);
    $config->set( "managed_extdas_$key", "lflag",       $href->{labelflag}      ? $href->{labelflag}  : $self->{'defaults'}{'LABELFLAG'},   1);
    $config->set( "managed_extdas_$key", "manager",     'das',                                                                              1);
    $config->set( "managed_extdas_$key", "col",         $href->{col} || $href->{color} ,                                                    1);
    $config->set( "managed_extdas_$key", "enable",      $href->{enable} ,                                                                   1);
    $config->set( "managed_extdas_$key", "mapping",     $href->{mapping} ,                                                                  1);
#   $config->set( "managed_extdas_$key", "help",        $href->{help} || '',                                                                1);
    $config->set( "managed_extdas_$key", "linktext",    $href->{linktext} || '',                                                            1);
    $config->set( "managed_extdas_$key", "linkurl",     $href->{linkurl} || '',                                                             1);
##3 we need to store the configuration...
    $config->save;
  }

  $self->save_sources();
}

sub amend_source {
  my( $self, $hashref ) = @_;
#  my $key = join('/', $hashref->{'url'}, $hashref->{'dsn'}, $hashref->{'type'});
  my $key = $hashref->{'name'};
  $self->{'data'}->{ $key } = $hashref;
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
    foreach my $hashref ( $session->get_das() ) {
      $self->{'data'}{$hashref->{'key'}} = $hashref;
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
