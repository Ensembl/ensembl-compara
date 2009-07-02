package EnsEMBL::Web::Command;

### Parent module for "Command" steps, in a wizard-type process, which 
### munge data and redirect to a new webpage rather than rendering HTML

use strict;
use warnings;
no warnings qw(uninitialized);

use CGI qw(escape);
use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Interface;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Root); 

{

my %Object       :ATTR(:get<object> :set<object> :init_arg<object>);
my %Webpage      :ATTR(:get<webpage> :set<webpage> :init_arg<webpage>);
my %Filters      :ATTR(:get<filters> :set<filters>);


sub object {
  my $self = shift;
  return $self->get_object;
}

sub webpage {
  my $self = shift;
  return $self->get_webpage;
}

sub filters {
### Override the parent method, because Root is not an inside-out object!
  my $self = shift;
  $self->set_filters(shift) if @_;
  return $self->get_filters;
}

sub script_name {
  my $self = shift;
  my $species = $self->object->species;
  my $path = $species . '/' if $species =~ /_/;
  return $path . $ENV{'ENSEMBL_TYPE'} . '/' . $ENV{'ENSEMBL_ACTION'};
}

sub ajax_redirect {
  my ($self, $url, $param) = @_;
  $self->webpage->page->ajax_redirect($self->url($url, $self->ajax_params($param)));
}

sub ajax_params {
  my ($self, $param) = @_;
  $param->{'_referer'} ||= $self->object->param('_referer') if $self->object->param('_referer');
  $param->{'_referer'} = CGI::escape($param->{'_referer'}) if $param->{'_referer'} =~ /\//;
  
  $param->{'x_requested_with'} ||= $self->object->param('x_requested_with') if $self->object->param('x_requested_with');
  return $param;
}


}

1;
