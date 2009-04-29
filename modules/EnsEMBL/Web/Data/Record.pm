package EnsEMBL::Web::Data::Record;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

## Void call to create virtual 'data' container and propogate triggers
__PACKAGE__->add_fields;

###################################################################################################
##
## New constructor is a bit different for Record
## It's used to access existing Record when record type is not known
## Input parameter is hash:
## owner => 'user'/'group'/$user/$group
## id    => $id
##
###################################################################################################

sub new {
  my $class = shift; 

  return $class->SUPER::new(@_)
     unless $class eq 'EnsEMBL::Web::Data::Record';

  my %args  = @_;

  die "Owner & id is necessary for the $class"
    unless $args{owner} && $args{id};
  
  my $self = bless {}, $class;
  $self->owner($args{owner});
  return $self->retrieve($args{id});
}

###################################################################################################
##
## Record is always owned by someone (user or group so far)
## Below is some functions related to this matter
##
###################################################################################################

sub owner {
  my $class = shift;
  my $owner = shift;
  
  no strict 'refs';

  if ((ref $owner && $owner->isa('EnsEMBL::Web::Data::User')) || lc($owner) eq 'user') {
    $class->table($class->species_defs->ENSEMBL_USER_DATA_TABLE);
    $class->set_primary_key($class->species_defs->ENSEMBL_USER_DATA_TABLE.'_id');
    $class->has_a(user => 'EnsEMBL::Web::Data::User');
    *{ "$class\::owner" } = sub { shift->user(@_) };
    *{ "$class\::owner_type" } = sub { return 'user' };
  } elsif ((ref $owner && $owner->isa('EnsEMBL::Web::Data::Group')) || lc($owner) eq 'group') {
    $class->table($class->species_defs->ENSEMBL_GROUP_DATA_TABLE);
    $class->set_primary_key($class->species_defs->ENSEMBL_GROUP_DATA_TABLE.'_id');
    $class->has_a(webgroup => 'EnsEMBL::Web::Data::Group');
    *{ "$class\::owner_type" } = sub { return 'group' };
    *{ "$class\::group" }      = sub { shift->webgroup(@_) };
    *{ "$class\::owner" }      = sub { shift->group(@_) };
  }
}

sub add_owner {
  my $class = shift;
  my $owner = shift;
  my $relation_class = $class .'::'. ucfirst(lc($owner));
  
  my $package = "package $relation_class;
                use base qw($class);
                $relation_class->owner('$owner');
                1;";
  eval $package;
  die "Compilation error: $@" if $@;
  
  return $relation_class;
}

## hacky sub, used for making group records out of user ones
sub clone {
  my $self  = shift;

  my %hash  = map { $_ => $self->$_ } keys %{ $self->queriable_fields };
  delete $hash{user_id};

  my $clone = EnsEMBL::Web::Data::Record::Group->new(\%hash);
    
  return $clone;
}


###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub propagate_cache_tags {
  my $proto = shift;

  $proto->SUPER::propagate_cache_tags($proto->_type);
}


sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;

  my $owner_type = $self->owner_type;
  my $owner = $self->$owner_type;

  $self->SUPER::invalidate_cache($cache, "${owner_type}[$owner]", $self->type);
}

1;
