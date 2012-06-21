package EnsEMBL::Web::Component::Help::View;

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Help);

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);

  return $self->parse_help_html($_->{'content'}, $adaptor) for @{$adaptor->fetch_help_by_ids([$hub->param('id')]) || []};
}

1;