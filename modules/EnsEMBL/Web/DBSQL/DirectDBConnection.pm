package EnsEMBL::Web::DBSQL::DirectDBConnection;

use strict;
use warnings;

my %handles;

sub direct_connection {
  my ($class,$caller,$name,$host,$port,$user,$pass) = @_;
  no strict 'refs';
  *{$caller.'::db_Main'} = sub {
    require EnsEMBL::Web::Controller;
    use strict 'refs';
    my $dbh = $handles{$caller};
    return $dbh if (defined $dbh) and $dbh->ping;
    my $dsn = join(':','dbi','mysql',$name,$host,$port);
    $dbh = DBI->connect_cached($dsn,$user,$pass,
      {
        $caller->_default_attributes,
        RaiseError => 1,
        PrintError => 1,
        AutoCommit => 1,
      }
    ) || die "Can not connect to $dsn";
    EnsEMBL::Web::Controller->disconnect_on_request_finish($dbh);
    $handles{$caller} = $dbh;
    return $dbh;
  };
}

1;
