package EnsEMBL::Web::TmpFile;

## EnsEMBL::Web::TmpFile - base module to work with temporary files:
## e.g. save them to the tmp storage using driver(s) - either disk or memcached
## see EnsEMBL::Web::TmpFile::* and EnsEMBL::Web::TmpFile::Drivers::* for more info

use strict;
use IO::String;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::TmpFile::Driver::Disk;
use EnsEMBL::Web::TmpFile::Driver::Memcached;

use base qw(Class::Accessor EnsEMBL::Web::Root);

use overload (
  '*{}'  => '_glob',
  'bool' => '_bool',
);

__PACKAGE__->mk_accessors(qw(species_defs content_type format compress drivers exptime));
__PACKAGE__->mk_ro_accessors(qw(full_path prefix extension file_root path_format URL_root URL shortname token));

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $drivers = delete $args{drivers}
                 || [ 
                      EnsEMBL::Web::TmpFile::Driver::Memcached->new,
                      EnsEMBL::Web::TmpFile::Driver::Disk->new
                    ];
  my $self = {
    species_defs => $species_defs,
    prefix       => undef,
    filename     => undef,
    shortname    => undef,
    extension    => undef,
    content_type => undef,
    content      => '',
    path_format  => 'XXX/X/X/XXXXXXXXXXXXXXX',
    full_path    => '',
    compress     => 0,
    file_root    => $species_defs->ENSEMBL_TMP_DIR,
    URL_root     => $species_defs->ENSEMBL_TMP_URL,
    md5          => '',
    URL          => '',
    drivers      => (ref($drivers) eq 'ARRAY') ? $drivers : [ $drivers ],
    %args,    
  };
  
  bless $self, $class;

  if ($args{filename}) {
    $self->filename($args{filename});
  } else {
    $self->make_up_filename;
  }

  return $self;
}

sub _glob {
  my $self = shift;
  $self->{_glob} ||= IO::String->new($self->{content});
  return $self->{_glob};
}

sub _bool {
  shift;
}

## Get/Set filename
## -> list of drivers to set - optional
## <- returns list of available drivers 
sub filename {
  my $self = shift;

  if (my $filename = shift) {
    my $extension = $self->{extension};
    my $prefix    = $self->{prefix};
    my $file_root = $self->{file_root};
    my $URL_root  = $self->{URL_root};

    ## SET extension
    if ($extension) {
      $filename =~ s/\.\w{1,4}$//g;
      $filename .= ".$extension";
    }

    ## Fix file root
    $file_root .= "/$prefix"
      if $prefix && $file_root !~ m!/$prefix$!;

    ## Fix URL root
    $URL_root .= "/$prefix"
      if $prefix && $URL_root !~ m!/$prefix$!;

    ## Split filename if full path given
    if ($filename =~ m!^$file_root/(.*)!) {
      $filename   = $1;
    }

    $self->{full_path} = "$file_root/$filename";
    $self->{URL}       = "$URL_root/$filename";
    $self->{filename}  = $filename;

    $self->{shortname} = $filename;
    $self->{shortname} =~ s!^.*/([^/]+)$!$1!g;
  }
  
  return $self->{filename};
}


## Creates unique random filename and fixes it's path
## -> $filename /string, optional/
## <- always true
sub make_up_filename {
  my $self = shift;
  my $filename = shift || $self->{'token'} || $self->ticket;
  $self->{'cache'} = 0;
  $self->{'token'} = $filename;
  $self->filename($self->templatize( $filename, $self->{path_format} ));
}


## Get/Set drivers
## -> list of drivers to set - optional
## <- returns list of available drivers 
sub drivers { 
  my $self    = shift;
  $self->{drivers} = [ @_ ] if @_;
  return @{ $self->{drivers} };
}


## Read-only
## Returns md5 checksum of the file content
sub md5 { 
  my $self = shift;

  $self->{md5} ||= md5_hex($self->content);
  return $self->{md5};
}


## Prints to our file
## -> $string /string, mandatory/, prints to our
## (adds string to content and saves)
## <- returns true on success (could die in some cases on failure, depends on driver)
sub print {
  my $self = shift;
  $self->content(join('', $self->content, @_));
  return $self->save;
}


## Saves our file content /$self->content/ to the storage via driver(s)
## -> $content /string, optional/ if specified, replaces $self->content with it and saves
## -> $pararms /hashref, optional/ if specified, uses them for the driver
## uses some default params $pararms if no $pararms given (e.g. 'compress')
## <- returns true on success (could die in some cases on failure, depends on driver)
sub save {
  my $self    = shift;
  my $content = $self->content(shift);
  my $params  = shift || {};
  
  foreach my $driver ($self->drivers) {
    return 1 
      if $driver && $driver->save($self);    
  }

  return 0; 
}

## Sets the content if passed and returns it
sub content {
  my $self    = shift;

  if (@_ && defined $_[0]) {
    $self->{'content'} = $_[0];
  } else {
    $self->retrieve unless $self->{'content'};
  }

  return $self->{'content'};
}

## Checks if the file exists
sub exists {
  my $self = shift;

  $self->filename($_[0])
    if $_[0];

  for my $driver ($self->drivers) {
    return 1
      if $driver && $driver->exists($self);
  }

  return 0; 
}

## Deletes the file exists
sub delete {
  my $self = shift;

  $self->filename($_[0])
    if $_[0];

  for my $driver ($self->drivers) {
    return 1
      if $driver && $driver->delete($self);
  }

  return 0; 
}

## Retrieves file contents
sub retrieve {
  my $self     = shift;
  my $filename = shift;

  $self->filename($filename)
    if $filename;

  for my $driver ($self->drivers) {

      if ($driver && (my $result = $driver->get($self))) {
        if (ref($result) eq 'HASH') {
          $self->{$_} = $result->{$_} for keys %$result;
          return $self->{'content'};
        } else {
          $self->{'content'} = $result;
          return $self->{'content'};
        }
        
      }
  }

  return undef; 
}

1;