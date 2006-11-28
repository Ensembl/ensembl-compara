package EnsEMBL::Web::DBSQL::UserAdaptor;

use Class::Std;
use EnsEMBL::Web::User;
use strict;

{
  my %DBAdaptor_of   :ATTR( :name<db_adaptor>   );
  my %SpeciesDefs_of :ATTR( :name<species_defs> );

  sub get_user_from_cookie {
    my( $self, $arg_ref ) = @_;
    $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});
    return EnsEMBL::Web::User->new({
      'adpator' => $self,
      'cookie'  => $arg_ref->{'cookie'},
      'user_id' => $arg_ref->{'cookie'}->get_value
    });
  }
}

1;
