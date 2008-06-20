package EnsEMBL::Web::Data::User;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('user');
__PACKAGE__->set_primary_key('user_id');

__PACKAGE__->add_queriable_fields(
  name         => 'tinytext',
  email        => 'tinytext',
  salt         => 'tinytext',
  password     => 'tinytext',
  organisation => 'tinytext',
  status       => 'tinytext',
);

__PACKAGE__->add_has_many(
  bookmarks      => 'EnsEMBL::Web::Data::Record::Bookmark',
  configurations => 'EnsEMBL::Web::Data::Record::Configuration',
  annotations    => 'EnsEMBL::Web::Data::Record::Annotation',
  dases          => 'EnsEMBL::Web::Data::Record::DAS',
  newsfilters    => 'EnsEMBL::Web::Data::Record::NewsFilter',
  sortables      => 'EnsEMBL::Web::Data::Record::Sortable',
  mixers         => 'EnsEMBL::Web::Data::Record::Mixer',
  currentconfigs => 'EnsEMBL::Web::Data::Record::CurrentConfig',
  specieslists   => 'EnsEMBL::Web::Data::Record::SpeciesList',
);

__PACKAGE__->has_many(_groups => ['EnsEMBL::Web::Data::Membership' => 'webgroup']);

sub groups {
  my $self = shift;

  return grep { $_->status eq 'active' } $self->_groups(@_);
}

sub find_administratable_groups {
  my $self = shift;

  my @admin_groups = (
    $self->groups(level => 'administrator'),
    $self->groups(level => 'superuser'),
  );

  return @admin_groups;
}

sub find_nonadmin_groups {
  my $self = shift;
  return $self->groups(level => 'member');
}

sub is_administrator_of {
  my ($self, $group) = @_; 

  return grep {$group->id eq $_->id} $self->find_administratable_groups;
}

sub is_member_of {
  my ($self, $group) = @_; 

  return grep {$group->id eq $_->id} $self->groups;
}



###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub invalidate_cache {
  my $self = shift;
  $self->SUPER::invalidate_cache('user['.$self->id.']');
}

sub propagate_cache_tags {
  my $self = shift;
  $self->SUPER::propagate_cache_tags('user['.$self->id.']')
    if ref $self;
}

1;
