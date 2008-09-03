#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    webmaster@sanger.ac.uk
# Created:       2001
# Last Modified: $Date$ $Author$
#
package Sanger::Graphics::WebUserConfig;
use strict;
use warnings;
use Sanger::Graphics::ColourMap;
use Sanger::Graphics::TextHelper;
use base qw(Exporter);
use Data::Dumper;

#########
# 'general' settings contain defaults.
# 'user' settings are restored from cookie if available
# 'general' settings are overridden by 'user' settings
#

sub is_available_artefact {
  return 1;
}

sub new {
  my $class = shift;
  my $self = {
	      '_colourmap'  => Sanger::Graphics::ColourMap->new(),
	      '_texthelper' => Sanger::Graphics::TextHelper->new(),
	      'general'     => {},
	      'user'        => {},
	     };

  bless($self, $class);

  #########
  # init sets up defaults in $self->{'general'}
  #
  $self->init( @_ ) if($self->can('init'));

  return $self;
}

sub dump {
  my ($self) = @_;
  print STDERR Dumper($self);
}

sub script {
  my ($self) = @_;
  my @keys   = keys %{$self->{'general'}};
  return $keys[0];
}

#########
# return artefacts on scripts
#
sub subsections {
  my ($self) = @_;
  return @{$self->{'general'}->{$self->script}->{'_artefacts'}};
}

#########
# return a list of the available options for this set of artefacts
#
sub options {
  my ($self) = @_;
  my $script = $self->script();
  return @{$self->{'general'}->{$script}->{'_options'}};
}

#########
# return a hashref of settings (user XOR general) for artefacts on scripts
#
sub values {
  my ($self, $subsection) = @_;
  my $hashref;

  my $script = $self->script();
  return {} unless(defined $self->{'general'}->{$script});
  return {} unless(defined $self->{'general'}->{$script}->{$subsection});

  my $userref = $self->{'user'}->{$script}->{$subsection};
  my $genref  = $self->{'general'}->{$script}->{$subsection};

  for my $key (keys %{$genref}) {
    $hashref->{$key} = $userref->{$key} || $genref->{$key}; 
  }
  return $hashref;
}

sub canset {
  my ($self, $subsection, $key) = @_;
  my $script = $self->script();

  return 1 if(defined $self->{'general'}->{$script}->{$subsection}->{$key});
  return undef;
}

sub set {
  my ($self, $subsection, $key, $value) = @_;

  my $script = $self->script();
  return unless(defined $key && defined $script && defined $subsection);

  $self->{'user'}->{$script}->{$subsection} ||= {}; 

  if(!defined $self->{'general'}->{$script} ||
     !defined $self->{'general'}->{$script}->{$subsection} ||
     !defined $self->{'general'}->{$script}->{$subsection}->{$key}) {
    warn "---+"x20 . qq(\nSanger::Graphics::WebUserConfig::set: Missing section...\nCould not find $script->$subsection->$key field. Set a default value\n) . "---+"x20 . "\n";
    return;
  }

  $self->{'user'}->{$script}->{$subsection}->{$key} = $value;
}

sub get_parameter {
  my( $self, $key ) = @_;
  return $self->get( '_settings', $key );
}
sub set_parameter {
  my( $self, $key, $value ) = @_;
  return $self->set( '_settings', $key, $value );
}

sub get {
  my ($self, $subsection, $key) = @_;
  my $script = $self->script();

  return unless(defined $key && defined $script && defined $subsection);
  my $user_pref = undef;

  if(defined $self->{'user'}->{$script} &&
     defined $self->{'user'}->{$script}->{$subsection}) {
    $user_pref = $self->{'user'}->{$script}->{$subsection}->{$key};
  }
  return $user_pref if(defined $user_pref);

  return unless(defined $self->{'general'}->{$script});
  return unless(defined $self->{'general'}->{$script}->{$subsection});
  return unless(defined $self->{'general'}->{$script}->{$subsection}->{$key});

  return $self->{'general'}->{$script}->{$subsection}->{$key};
}

sub colourmap {
  my ($self) = @_;
  return $self->{'_colourmap'};
}

sub image_width {
  my ($self, $script) = @_;
  $script ||= $self->{'_script'};
  return $self->get_parameter( 'width');
}

sub image_height {
  my ($self, $height) = @_;
  $self->{'image_height'} = $height if(defined $height);
  return $self->{'image_height'};
}

sub bgcolor {
  my ($self, $script) = @_;
  $script ||= $self->{'_script'};
  return $self->get_parameter( 'bgcolor');
}

sub bgcolour {
  my ($self, $script) = @_;
  return $self->bgcolor($script);
}

sub texthelper {
  my ($self) = @_;
  return $self->{'_texthelper'};
}

sub scalex {
  my ($self, $val) = @_;
  if(defined $val) {
    $self->{'_scalex'} = $val;
    $self->{'_texthelper'}->scalex($val);
  }
  return $self->{'_scalex'};
}

sub container_width {
  my ($self, $val) = @_;
  if($val) {
    $self->{'_containerlength'} = $val;

    my $width = $self->image_width();
    $self->scalex($width/$val);
  }
  return $self->{'_containerlength'}||0;
}

sub transform {
  my ($self) = @_;
  return $self->{'transform'};
}

1;
