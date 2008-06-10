package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Object;
use EnsEMBL::Web::RegObj;
                                                                                   
our @ISA = qw(EnsEMBL::Web::Object);


## Currently just a placeholder object for wizard steps where the data type is as yet unknown

sub data        : lvalue { $_[0]->{'_data'}; }
sub data_type   : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption           {
  my $self = shift;
  return 'Custom Data';
}

sub short_caption {
  my $self = shift;
  return 'Data Management';
}

sub counts {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $counts = {};
  return $counts;
}


1;
