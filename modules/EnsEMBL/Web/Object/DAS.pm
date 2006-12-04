package EnsEMBL::Web::Object::DAS;

use strict;
use warnings;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  $self->real_species = $ENV{ENSEMBL_SPECIES};
  return $self; 
}

sub real_species       :lvalue { $_[0]->{'data'}{'real_species'}};

#sub Obj { 
#  return $_[0]{'data'}{'_object'}[0]->Obj; 
#}

sub Locations { return @{$_[0]{data}{_object}}; }

sub FeatureTypes { 
  my $self = shift;
  push @{$self->{'data'}{'_feature_types'}}, @_ if @_;
  return $self->{'data'}{'_feature_types'};
}

sub FeatureIDs { 
  my $self = shift;
  push @{$self->{'data'}{'_feature_ids'}}, @_ if @_;
  return $self->{'data'}{'_feature_ids'};
}

sub GroupIDs { 
  my $self = shift;
  push @{$self->{'data'}{'_group_ids'}}, @_ if @_;
  return $self->{'data'}{'_group_ids'};
}

sub Stylesheet {
  my $self = shift;
  return qq{
<STYLESHEET version="1.0">
</STYLESHEET>
};
}

sub EntryPoints {
  my ($self) = @_;
  my $collection;
  return $collection;
}

sub Types {
  my ($self) = @_;
  my $collection;
  return $collection;
}

1;
