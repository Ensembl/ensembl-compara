package EnsEMBL::Web::TmpFile;

## EnsEMBL::Web::TmpFile - base module to work with temporary files:
## e.g. save them to the tmp storage using driver(s) - either disk or memcached
## see EnsEMBL::Web::TmpFile::* and EnsEMBL::Web::TmpFile::Drivers::* for more info

use strict;
use IO::String;
use Time::HiRes qw(gettimeofday);
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::TmpFile::Driver::Disk;
use EnsEMBL::Web::TmpFile::Driver::Memcached;

use base qw(Class::Accessor);

## We overload some methods here
## so that tmpfile object could be used as a filehandle
use overload (
  '*{}'  => '_glob',
  'bool' => '_bool',
);

sub _glob {
  my $self = shift;
  $self->{_glob} ||= IO::String->new($self->{content});
  return $self->{_glob};
}

sub _bool {
  shift;
}

sub token {

}
__PACKAGE__->mk_accessors(qw(species_defs compress drivers exptime URL));
__PACKAGE__->mk_ro_accessors(qw(full_path prefix extension tmp_dir path_pattern URL_root shortname token));

## new - tmp file constructor
## accepts either filename string
## or hash of parameters
## e.g.
## EnsEMBL::Web::TmpFile->new('[/global_path/ or local_path/]filename.txt');
## or
## EnsEMBL::Web::TmpFile->new(filename => 'file.txt', prefix => 'x_files', ...);
sub new {
  my $class = shift;
  my %args  = (@_ == 1) ? (filename => $_[0]) : @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $drivers      = delete $args{drivers}
                      || [ 
                           EnsEMBL::Web::TmpFile::Driver::Memcached->new,
                           EnsEMBL::Web::TmpFile::Driver::Disk->new
                         ];
  my $self = {
    species_defs => $species_defs,         
        
    filename     => undef, # you can specify filename explicitly (e.g. if you know the name of existing file you want to retrieve),
                           # random one will be made up otherwise
                           # if filename starts with a "/" it's treated as a full path
                           # so prefix and tmp_dir would be ignored in this case

    prefix       => undef, # used as a namespace to categorize tmp files,
                           # {tmp_dir}/{prefix} folder will be created for files stored on Disk

    compress     => 0,     # compress the content before putting into storage
                           # compress method depends on the driver
                           # it wont put .gz or .zip extension itself
                           # you must provide correct extension explicitly if you wish

    tmp_dir      => $species_defs->ENSEMBL_TMP_DIR, # path to tmp folder
    URL_root     => $species_defs->ENSEMBL_TMP_URL, # URL path to the file
    extension    => undef,                          # this will be put at the end of the filename if it doesn't have one
    path_pattern => 'XXX/X/X/XXXXXXXXXXXXXXX',      # used for random generation of the filename if it's not specified
                                                    # the purpose of that is to spread tmp files into many random folders
                                                    # to avoid having millions of files in one folder

    drivers      => (ref($drivers) eq 'ARRAY')      ## TmpFile::Drivers::* object, or arrayref of several ones,
                        ?   $drivers                ## [ ::Driver::Memcached, ::Driver::Disk ] by default
                        : [ $drivers ],

    %args,    
  };
  
  bless $self, $class;

  if ($args{filename}) {
    $self->fix_filename($args{filename});
  } else {
    $self->generate_filename;
  }

  return $self;
}


## Get/Set filename
## accepts string filename
## fixes filename, full_path, URL, etc. according to extension, 
## <- string filename
sub fix_filename {
  my $self = shift;

  if (my $filename = shift) {
    my $prefix    = $self->prefix;
    my $tmp_dir   = $self->tmp_dir;
    my $URL_root  = $self->URL_root;

    if (my $extension = $self->extension) {
      $extension =~ s/^\.//g;
      $filename  =~ s/(\.\w{0,4})?$/.$extension/;
      $self->{extension} = $extension;
    }

    if ($filename =~ m!^/!) {

      if ($filename =~ m!^$tmp_dir/(.*)$!) {
        $filename = $1;
      }

      $self->{tmp_dir}   = '';
      $self->{full_path} = $filename;
      $self->{URL}       = undef;
      
    } else {

      ## Fix file root
      $tmp_dir .= "/$prefix"
        if $prefix && $tmp_dir !~ m!/$prefix$!;
      
      ## Fix URL root
      $URL_root .= "/$prefix"
        if $prefix && $URL_root !~ m!/$prefix$!;

      ## Split filename if full path given
      if ($filename =~ m!^$tmp_dir/(.*)!) {
        $filename   = $1;
      }

      $self->{full_path} = "$tmp_dir/$filename";
      $self->{URL}       = "$URL_root/$filename";

    }

   ($self->{shortname}) = $filename =~ m!([^/]+)$!;
    $self->{filename}   = $filename;
  }
  
  return $self->{filename};
}

*filename = \&fix_filename;


## Creates unique random-ish filename
## have a look at EnsEMBL::Web::Tools::RandomString::ticket() if you curious about "random-ish"
## -> nothing
## <- always true
sub generate_filename {
  my $self     = shift;
  my $pattern  = $self->{path_pattern};
  my $ticket = EnsEMBL::Web::Tools::RandomString::ticket();
  
  ## Just to make sure :)
  $pattern =~ s!/+!/!g;
  $ticket  =~ s/[^\w]//g;
  
  my @P    = split(//, $pattern);
  my $fn   = '';
  foreach( split(//, $ticket) ) {
    $_ ||= '_';
    my $P = shift @P;
    if( $P eq '/') {
      $fn .='/';
      $P   = shift @P;
    }
    $fn .= $_;
  }
 
  $self->fix_filename($fn);
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
__END__

=head1 NAME

EnsEMBL::Web::TmpFile - parent module to work with ensembl tmp files

=head1 SYNOPSIS

  use EnsEMBL::Web::TmpFile;

  my $new_file = new EnsEMBL::Web::TmpFile(
    prefix => 'x_files'
  );
  
  print $new_file "some contencts...\n";
  
  $new_file->save;

  my $old_file = new EnsEMBL::Web::TmpFile(
    prefix   => 'x_files',
    filename => 'myfile.txt',
  );
  
  my $content = $old_file->retrieve;

  $old_file->delete;

=head1 DESCRIPTION

EnsEMBL::Web::TmpFile - parent module to work with temporary files in ensembl e.g. save/retrieve them using some tmp storage
see EnsEMBL::Web::TmpFile::Drivers::* modules for available types of storages

There are number of more specific EnsEMBL::Web::TmpFile::* modules for certain tmp file types

=head1 METHODS

=over 4

to be documented (see comments in the source code for now)

=item C<new>
=item C<md5>
=item C<print>
=item C<save>
=item C<content>
=item C<exists>
=item C<delete>
=item C<retrieve>

=head1 AUTHORS

Eugene Bragin <eb4@sanger.ac.uk>

=head1 SEE ALSO

L<EnsEMBL::Web::TmpFile::Text>, L<EnsEMBL::Web::TmpFile::Image>, L<EnsEMBL::Web::TmpFile::Tar>,
L<EnsEMBL::Web::TmpFile::Driver::Disk>, L<EnsEMBL::Web::TmpFile::Driver::Memcached>

=cut
