package EnsEMBL::Web::Document::HTML;

use strict;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  
  my $self = { 
    _renderer => undef, 
    _home_url => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT   || '/',
    _img_url  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_IMAGE_ROOT || '/i/',
    @_
  };
  
  bless $self, $class;
  
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }
sub home_url :lvalue { $_[0]->{'_home_url'}; }
sub img_url  :lvalue { $_[0]->{'_img_url'};  }
sub species_defs     { return $_[0]->{'species_defs'}; }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub render {
  my $self = shift;
  return $self->print($self->_content);
}

sub _content {}

1;
