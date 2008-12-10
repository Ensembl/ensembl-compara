package EnsEMBL::Web::TmpFile;

## EnsEMBL::Web::TmpFile - base module to work with temporary files:
## e.g. save them to the tmp storage using driver(s) - either disk or memcached
## see EnsEMBL::Web::TmpFile::* and EnsEMBL::Web::TmpFile::Drivers::* for more info

use strict;
use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::Root;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Compress::Zlib;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::TmpFile::Driver::Disk;
use EnsEMBL::Web::TmpFile::Driver::Memcached;

use base qw(Class::Accessor EnsEMBL::Web::Root);

__PACKAGE__->mk_accessors(qw(
  species_defs prefix extension content_type path_format format
  compress file_root URL_root drivers
));

__PACKAGE__->mk_ro_accessors(qw(full_path URL));

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $self = {
    species_defs => $species_defs,
    prefix       => undef,
    filename     => undef,
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
    drivers      => $args{drivers}
                    ? ( (ref($args{drivers}) eq 'ARRAY') ? $args{drivers} : [ $args{drivers} ] )
                    : [ 
                        EnsEMBL::Web::TmpFile::Driver::Memcached->new,
                        EnsEMBL::Web::TmpFile::Driver::Disk->new
                      ],
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


## Get/Set filename
## -> list of drivers to set - optional
## <- returns list of available drivers 
sub filename {
  my $self = shift;

  if (my $filename = shift) {
    $self->{filename}  = $filename;

    ## SET extension
    $self->{filename} .= ".$self->{extension}"
      if $self->{extension} && $self->{filename} !~ /\.$self->{extension}$/;

    ## SET RO accessors
    $self->{URL}       = "$self->{URL_root}/$self->{filename}";
    $self->{full_path} = "$self->{file_root}/$self->{filename}";
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
  my ($self, $string) = @_;
  $self->content($self->content . $string);
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
      if $driver
      && $driver->save(
            $self->full_path,
            $content,
            $params,
         );    
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
      if $driver
      && $driver->exists($self->full_path);
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
      if $driver
      && $driver->delete($self->full_path);
  }

  return 0; 
}

## Retrieves file contents
sub retrieve {
  my $self     = shift;
  my $filename = shift;
  my $params   = shift || {};

  $self->filename($filename)
    if $filename;

  for my $driver ($self->drivers) {

      if ($driver && (my $result = $driver->get($self->full_path, $params))) {
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

=head1 Ensembl::Web::File::Text

=head2 SYNOPSIS

Simple caching and retrieval of uploaded text files.

Caching:

  my $tmpfilename = $cgi->tmpFileName($filename);
  my $cache = new EnsEMBL::Web::File::Data($species_defs);
  $cache->set_cache_filename('tmp',$tmpfilename);
  $cache->save($tmpfilename);
  my $cachename = $cache->filename;

Retrieval:

  my $cache = new EnsEMBL::Web::File::Data($species_defs);
  $data = $cache->retrieve($cachename);


=head2 DESCRIPTION

Some wizards, e.g. Karyoview, need to be able to able to upload a file at one step and then use it at a later point in the wizard process. Unfortunately CGI throws away temporary files when a script exits, so the upload needs to be cached elsewhere.

Note: this module is designed to handle only simple text-based genomic files such as GTF format.

=head2 METHOD

=head3 B<new>

Description: Simple constructor method

=head3 B<set_cache_filename>

Assigns a random output directory in the Ensembl tmp directory - at the moment, the CGI-assigned tmp filename is retained.
 
=head3 B<filename>

Retrieves the path assigned by set_cache_filename
 
=head3 B<save>

Reads the text file in and writes it out to the assigned location
 
=head3 B<retrieve>

Reads the cached file and returns it as a string
 
=head2 BUGS AND LIMITATIONS

=head3 Bugs

None known

=head3 Limitations

Currently assumes that CGI.pm stores its temporary files in /usr/tmp

=head2 AUTHOR

Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org

=head2 COPYRIGHT

See http://www.ensembl.org/info/about/code_licence.html

=cut

1;
