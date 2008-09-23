use DBI;
use strict;
package EnsEMBL::Web::IndexSupport;

sub new {
  my( $class, $path_to_ini, $text_out_dir, $species, $db_flag ) = @_;
  ## requires (1) path to conf to be set
  ##          (2) path to text files to be set
  ##          (3) species to be set
  my %short_codes =  qw(
    am Apis_mellifera          
    ag Anopheles_gambiae
    ce Caenorhabditis_elegans
    cf Canis_familiaris
    ci Ciona_intestinalis
    dr Danio_rerio
    dm Drosophila_melanogaster
    fr Fugu_rubripes  
    gg Gallus_gallus
    hs Homo_sapiens
    mm Mus_musculus
    pt Pan_troglodytes
    rn Rattus_norvegicus 
    sc Saccharomyces_cerevisiae
    tn Tetraodon_nigroviridis
    xt Xenopus_tropicalis
  );
  $species = $short_codes{$species}||$species;
  my $self = {
    'path_to_ini' => $path_to_ini,
    'directory'   => "$text_out_dir/$species",
    'species'     => $species,
    'short_codes' => \%short_codes,
  };
  bless($self, $class);
  if($path_to_ini) {
    if( $self->parse() ) {
      return undef;
    } else {
      $self->connect( $db_flag );
    }
  }
  return $self;
}

sub short_codes { return $_[0]->{'short_codes'};  }

sub parse {
  my $self = shift;
  my $dbs;
  my $vals;
  print STDERR "Parsing ini files...\n" if $self->{'debug'};
  foreach my $conf_code ( 'DEFAULTS', 'MULTI', $self->{'species'} ) {
    foreach my $path (@{ $self->{'path_to_ini'} }) {
      my $conf = $path.'/'.$conf_code.'.ini';
      print STDERR "$conf\n" if $self->{'debug'};
      open I,$conf;
      my $flag = 0;
      while(<I>) {
        if( /^\[databases\]/ ) {
          $flag = 1;
        } elsif( /^\[/ ) {
          $flag = 0;
        } elsif(/^\s*([_A-Z0-9]+)\s*=\s*([_A-Z0-9]+)/i   ) {
          if($flag == 1) {
            $dbs->{$1} = $2;
          } else {
            $vals->{$1} = $2;
          }
        }
      }
      close I;
    }
  }
  $self->{'dbs'} = $dbs;
  $self->{'vals'} = $vals;
  return 0; 
}

sub debug {
  my $self = shift;
  $self->{'debug'} = shift;
}

sub species {
  my $self = shift;
  return $self->{'species'};
}

sub db {
  my ($self, $name) = @_;
  return $self->{'dbs'}{$name};
}

# get a database handler
sub dbh {
    my $self = shift;
    return $self->{'dbh'};
}

sub do_query{
  my $self = shift;
  print "$_[0];\n\n" if $self->{'debug'}==1 ; #&& $_[0]!~/update/;
  my $R = $self->{'dbh'}->do( @_ );
  print "=====MYSQL QUERY: $R\n" if $self->{'debug'};
}

sub selectall_arrayref {
  my $self = shift;
  print "$_[0];\n\n" if $self->{'debug'}==1;
  return $self->{'dbh'}->selectall_arrayref( @_ );
}

sub selectrow_array {
  my $self = shift;
  print "$_[0];\n\n" if $self->{'debug'}==1;
  return $self->{'dbh'}->selectrow_array( @_ );
}

sub prepare {
  my $self = shift;
  print "$_[0];\n\n" if $self->{'debug'}==1;
  return $self->{'dbh'}->prepare(@_);
}

sub connect {
  my $self = shift;
  my $admin = shift;
  my $connection_string = join '',
     "DBI:mysql:", $self->{'dbs'}{'DATABASE_CORE'},         ';host=',
                   $self->{'vals'}{'DATABASE_HOST'},      ';port=',
                   $self->{'vals'}{'DATABASE_HOST_PORT'} ;
  print STDERR "\nConnecting to DB...\n" if $self->{'debug'}; 
  print STDERR $connection_string . "\n" if $self->{'debug'};
  $self->{'dbh'} = DBI->connect(
    $connection_string,
    $self->{'vals'}{ $admin eq 'write' ? 'DATABASE_WRITE_USER' : 'DATABASE_DBUSER' },
    $self->{'vals'}{ $admin eq 'write' ? 'DATABASE_WRITE_PASS' : 'DATABASE_COREPASS' },
  );
}

sub disconnect {
  my $self = shift;
  $self->{'dbh'}->disconnect;
  $self->{'dbh'}=undef;
}

1;
