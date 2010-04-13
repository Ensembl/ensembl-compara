package EnsEMBL::Web::Document::HTML;

use strict;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my ($default_params, $extra_params) = @_;

  my $home_url = '/';
  my $img_url = '/i/';
  my $hub = $default_params->{'_hub'};
  if ($hub) {
    $home_url ||= $hub->species_defs->ENSEMBL_WEB_ROOT;
    $img_url  ||= $hub->species_defs->ENSEMBL_IMAGE_ROOT;
  }

  my $self = { 
    _renderer => undef, 
    _home_url => $home_url,
    _img_url  => $img_url,,
    %$default_params,
  };
  if ($extra_params) {
    while (my($k,$v) = each (%$extra_params)) {
      $self->{$k} = $v;
    }
  }
  
  bless $self, $class;
  
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }
sub home_url :lvalue { $_[0]->{'_home_url'}; }
sub img_url  :lvalue { $_[0]->{'_img_url'};  }

sub species_defs  { return $_[0]->{'species_defs'}; }
sub hub           { return $_[0]->{'_hub'}; }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

1;
