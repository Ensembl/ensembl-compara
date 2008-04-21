package EnsEMBL::Web::Data::Record;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

sub owner {
  my $class = shift;
  my $owner = lc(shift);
  no strict 'refs';
  
  if ($owner eq 'user') {
    $class->table($class->species_defs->ENSEMBL_USER_DATA_TABLE);
    $class->set_primary_key($class->species_defs->ENSEMBL_USER_DATA_TABLE.'_id');
    $class->has_a(user => 'EnsEMBL::Web::Data::User');
    *{ "$class\::record_type" } = sub { return 'user' };
  } elsif ($owner eq 'group') {
    $class->table($class->species_defs->ENSEMBL_GROUP_DATA_TABLE);
    $class->set_primary_key($class->species_defs->ENSEMBL_GROUP_DATA_TABLE.'_id');
    $class->has_a(webgroup => 'EnsEMBL::Web::Data::Group');
    *{ "$class\::record_type" } = sub { return 'group' };
  }
}

sub clone {
  my $self = shift;
  my %hash = map { $_ => $self->$_ } keys %{ $self->get_all_fields };
  delete $hash{user_id};
  return \%hash;
}

sub add_owner {
  my $class = shift;
  my $owner = shift;
  my $relation_class = $class .'::'. ucfirst($owner);
  
  my $package = "package $relation_class;
                use base qw($class);
                $relation_class->owner('$owner');
                1;";
  eval $package;
  die "Compilation error: $@" if $@;
  
  return $relation_class;
}

1;