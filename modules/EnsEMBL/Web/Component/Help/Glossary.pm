package EnsEMBL::Web::Component::Help::Glossary;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub || EnsEMBL::Web::Hub->new;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $table   = $self->new_twocol({'striped' => 1});
  my $words   = ($hub->param('id') ? $adaptor->fetch_help_by_ids([ $hub->param('id') ]) : $adaptor->fetch_glossary) || [];

  $table->add_row(
    $_->{'word'} . ( $_->{'expanded'} ? " ($_->{'expanded'})" : '' ),
    $_->{'meaning'}
  ) for @$words;

  return sprintf '<h2>Glossary</h2>%s', $table->render;
}

1;
