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
  organisation => 'text',
  status       => 'tinytext',
);

__PACKAGE__->add_has_many(
  bookmarks      => 'EnsEMBL::Web::Data::Record::Bookmark',
  configurations => 'EnsEMBL::Web::Data::Record::Configuration',
  annotations    => 'EnsEMBL::Web::Data::Record::Annotation',
  dases          => 'EnsEMBL::Web::Data::Record::DAS',
  newsfilters    => 'EnsEMBL::Web::Data::Record::NewsFilter',
  infoboxes      => 'EnsEMBL::Web::Data::Record::Infobox',
  opentabs       => 'EnsEMBL::Web::Data::Record::Opentab',
  sortables      => 'EnsEMBL::Web::Data::Record::Sortable',
  mixers         => 'EnsEMBL::Web::Data::Record::Mixer',
  drawers        => 'EnsEMBL::Web::Data::Record::Drawer',
  currentconfigs => 'EnsEMBL::Web::Data::Record::CurrentConfig',
  specieslists   => 'EnsEMBL::Web::Data::Record::SpeciesList',
);

__PACKAGE__->has_many(_groups => ['EnsEMBL::Web::Data::Membership' => 'webgroup']);

sub groups {
  return grep { $_->status eq 'active' } shift->_groups(@_);
}

sub find_administratable_groups {
  my $self = shift;
  ## TODO: Not sure if this will work  
  my @admin_groups = (
    $self->groups(level => 'administrator'),
    $self->groups(level => 'superuser'),
  );

  return @admin_groups;
}

sub is_administrator_of {
  my ($self, $group) = @_; 

  return grep {$group->id eq $_->id} $self->find_administratable_groups;
}

sub is_member_of {
  my ($self, $group) = @_; 

  return grep {$group->id eq $_->id} $self->groups;
}

1;
