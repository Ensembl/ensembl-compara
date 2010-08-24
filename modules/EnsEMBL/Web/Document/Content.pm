package EnsEMBL::Web::Document::Content;
use strict;

sub new {
  my $class = shift;
  
  my $self = {
    _renderer => undef,
    panels    => [],
    form      => ''
  };
  
  bless $self, $class;
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }
sub first    :lvalue { $_[0]->{'first'};     }
sub form     :lvalue { $_[0]->{'form'};      }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub add_panel {
  my ($self, $panel) = @_;
  push @{$self->{'panels'}}, $panel;
}

sub panel {
  my ($self, $code) = @_;
  
  foreach (@{$self->{'panels'}}) {
    return $_ if $code eq $_->{'code'};
  }
  
  return undef;
}

sub render {
  my $self = shift;
  my $func = "render_$self->{'format'}";
  
  foreach my $panel (@{$self->{'panels'}}) {
    next if $panel->{'code'} eq 'summary_panel';    
    next unless $panel->can($func);
    
    $panel->renderer = $self->renderer;
    $panel->$func;
  }
}

1;
