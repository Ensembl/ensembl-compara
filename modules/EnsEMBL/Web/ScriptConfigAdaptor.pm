package EnsEMBL::Web::ScriptConfigAdaptor;

use strict;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::ScriptConfig;

our @ISA = qw(EnsEMBL::Web::Root);

##
## Adaptor producing web user config modules.
##

sub new {
  my( $class, $path, $user_db, $r ) = @_;
  my @path  = reverse @{$path||[]};
  unshift @path, 'EnsEMBL::Web';
  my $self  = {
    'path'     => \@path,
    'user_db'  => $user_db || undef,
    'r'        => $r       || undef
  };
  bless $self, $class;
  return $self;
}

sub getScriptConfig {
  my $self = shift;
  my $type = shift;
  my $classname = '';
## If a site is degined in the configuration look for
## an the user congig object in the namespace EnsEMBL::Web::UserConfig::{$site}::{$type}
## Otherwise fall back on the module EnsEMBL::Web::UserConfig::{$type} 

  my $script_config = new EnsEMBL::Web::ScriptConfig( $type, $self );
  
  foreach my $root ( @{$self->{'path'}} ) {
    my $classname = $root."::ScriptConfig::$type";
    unless( $self->dynamic_use( $classname ) ) {
## If the module can't be required throw and error and return undef;
      (my $message = "Can't locate $classname\.pm in" ) =~ s/::/\//g;
      my $error = $self->dynamic_use_failure($classname);
      warn qq(ScriptConfigAdaptor failed to require $classname:\n  $error) unless $error=~m:$message:;
      next;
    }
    my $method_name = $classname."::init";
    eval {
      no strict 'refs';
      &$method_name( $script_config );
    };
    if( $@ ) {
      my $message = "Undefined subroutine &$method_name called";
      if( $@ =~ /$message/ ) {
        warn qq(ScriptConfigAdaptor: init not defined in $classname\n);
      } else {
        warn qq(ScriptConfigAdaptor init call on $classname failed:\n$@); 
      }
    }
  }
  $script_config->load unless $self->{'no_load'};
  return $script_config;  
}

1;
