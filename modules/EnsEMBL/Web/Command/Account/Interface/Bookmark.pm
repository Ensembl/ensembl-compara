package EnsEMBL::Web::Command::Account::Interface::Bookmark;

use strict;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my $interface = $self->interface; ## Create interface object, which controls the forms
  my $referer   = $hub->referer;
  my $data;
  
  ## TODO: make new constructor accept 'record_type' parameter 
  if ($hub->param('record_type') && $hub->param('record_type') eq 'group') {
    $data = new EnsEMBL::Web::Data::Record::Bookmark::Group($hub->param('id'));
  } else {
    $data = new EnsEMBL::Web::Data::Record::Bookmark::User($hub->param('id'));
  }
  
  $interface->data($data);
  $interface->discover;

  ## Set url manually, because otherwise parameters get lost for some reason!
  my $url   = $hub->param('url');
  my $local = $hub->species_defs->ENSEMBL_BASE_URL;
  
  if ($url =~ /$local/) {
    my $r = $hub->param('r');
    $url  = $local . $referer->{'uri'};
    
    if ($r) {
      $url  =~ s/([\?;&]r=)[^;]+(;?)/$1$r$2/;
      $url .= ($url =~ /\?/ ? ';r=' : '?r=') . $r unless $url =~ /[\?;&]r=[^;&]+/;
    }
  }
  
  ## Customization
  $interface->caption({
    add  => 'Create bookmark', 
    edit => 'Edit bookmark'
  });
  
  $interface->permit_delete('yes');
  $interface->option_columns([ 'name', 'description', 'url' ]);
  $interface->modify_element('url',         { type => 'String', label => 'The URL of your bookmark', value => $url });
  $interface->modify_element('name',        { type => 'String', label => 'Bookmark name' });
  $interface->modify_element('description', { type => 'String', label => 'Short description' });
  $interface->modify_element('object',      { type => 'Hidden', value => $referer->{'ENSEMBL_TYPE'} });
  $interface->modify_element('shortname',   { type => 'Hidden' });
  $interface->modify_element('owner_type',  { type => 'Hidden' });
  $interface->modify_element('click',       { type => 'Hidden' });
  $interface->element_order([qw(name description url object shortname owner_type click)]);
  
  ## Render page or munge data, as appropriate
  return $interface->configure($self);
}

1;
