package EnsEMBL::Web::Commander::Connection::Option;

use EnsEMBL::Web::Commander::Connection;
use Class::Std;

our @ISA = qw(EnsEMBL::Web::Commander::Connection);

{

my %Predicate :ATTR(:set<predicate> :get<predicate>);
my %Conditional :ATTR(:set<conditional> :get<conditional>);

}


1;
