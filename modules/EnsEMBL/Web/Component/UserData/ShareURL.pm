package EnsEMBL::Web::Component::UserData::ShareURL;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Tools::Encryption qw(checksum);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Shareable URL';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my @shares = grep { $_ } ($self->object->param('share_id'));

  my $share_ref = join ';', (
    map { ($_ =~ /^\d+$/) ? "share_ref=000000$_-". checksum($_) : "share_ref=$_" } @shares
  );

  my $url = $self->object->species_defs->ENSEMBL_BASE_URL . $self->object->param('_referer');
  $url .= $self->object->param('_referer') =~ /\?/ ? ';' : '?';
  $url .= $share_ref;

  my $html = qq(<p class="space-below">To share this data, use the URL:</p>
<p class="space-below"><a href="$url">$url</a></p>
<p class="space-below">Please note that this link will expire after 72 hours.</p>
);
  
  return $html;
}

1;
