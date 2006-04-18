package EnsEMBL::Web::Object::DAS;

use strict;
use warnings;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }

sub Obj { 
  return $_[0]{'data'}{'_object'}[0]->Obj; 
}

sub Locations { return @{$_[0]{data}{_object}}; }

sub FeatureTypes { 
  my $self = shift;
  push @{$self->{'data'}{'_feature_types'}}, @_ if @_;
  return $self->{'data'}{'_feature_types'};
}

1;
