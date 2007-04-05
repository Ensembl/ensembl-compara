package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Object;
                                                                                   
@EnsEMBL::Web::Object::UserData::ISA = qw(EnsEMBL::Web::Object);


## Currently just a placeholder object for wizard steps where the data type is as yet unknown

sub data        : lvalue { $_[0]->{'_data'}; }
sub data_type   : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

1;
