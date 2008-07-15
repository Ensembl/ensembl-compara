package EnsEMBL::Web::UserConfigAdaptor;

use strict;
use Bio::EnsEMBL::ColourMap;

##
## Adaptor producing web user config modules.
##

sub new {
  my( $class, $site, $user_db, $r, $ext_url, $species_defs ) = @_;
  my $self  = {
    'colourmap'  => new Bio::EnsEMBL::ColourMap( $species_defs ),
    'exturl'     => $ext_url,
    'user_db'    => $user_db || undef,
    'r'          => $r       || undef,
    'site'       => $site,
    'species_defs' => $species_defs,
  };
  bless $self, $class;
  return $self;
}

sub getUserConfig {
  my $self = shift;
  my $type = shift;
  my $classname = '';
## If a site is degined in the configuration look for
## an the user congig object in the namespace EnsEMBL::Web::UserConfig::{$site}::{$type}
## Otherwise fall back on the module EnsEMBL::Web::UserConfig::{$type} 
  if ($type eq 'contigview') { # since there is no contigview config use contigviewbottom 
	$type = 'contigviewbottom';
    }
  if( $self->{'site'} ) {
    $classname = "EnsEMBL::Web::UserConfig::$self->{'site'}::$type";
    eval "require $classname";
  }
  if($@ || !$self->{'site'}) {
    my $classname_old = $classname;
    $classname = "EnsEMBL::Web::UserConfig::$type";
    eval "require $classname";
## If the module can't be required throw and error and return undef;
    if($@) {
      warn(qq(UserConfigAdaptor failed to require $classname_old OR $classname: $@\n));
      return undef;
    }
  }
## Import the module
  $classname->import();
  my $config; 
  eval { $config = $classname->new( $self, @_ ); };
  $config->{'exturl'} = $self->{'exturl'};
  if( $@ || !$config ) { warn(qq(UserConfigAdaptor failed to create new $classname: $@\n)); }
## Return the respectiv config.
  return $config;
}

1;
