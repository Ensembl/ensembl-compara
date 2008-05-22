package EnsEMBL::Web::Data::Membership;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('group_member');
__PACKAGE__->set_primary_key('group_member_id');

__PACKAGE__->add_queriable_fields(
  webgroup_id   => 'int',
  user_id       => 'int',
  level         => "enum('member','administrator','superuser')",
  member_status => "enum('active','inactive','pending','barred')",
);

__PACKAGE__->has_a(webgroup => 'EnsEMBL::Web::Data::Group');
__PACKAGE__->tie_a(user     => 'EnsEMBL::Web::Data::User');



###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub invalidate_cache {
  my $self = shift;
  $self->cache->delete_by_tags('user['.$self->user_id.']');
  $self->cache->delete_by_tags('group['.$self->webgroup_id.']');
}

1;