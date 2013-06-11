package EnsEMBL::Web::Tools::FileHandler;

use strict;
use warnings;

use FileHandle;
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT = qw(file_get_contents file_put_contents);

sub file_get_contents {
  ## Reads a file from memory location
  ## @param File location
  ## @return List of lines of files
  my $file_handle = get_file_handle(shift, 'r');
  my @lines       = $file_handle->getlines;
  $file_handle->close;
  return @lines;
}

sub file_put_contents {
  ## Write the content the file
  ## Creates a new file if not existing one
  ## Overrites any existing content if file existing
  ## @param  File location
  ## @params List of text to be written
  my $file_handle = get_file_handle(shift, 'w');

  $file_handle->print(@_);
  $file_handle->close;
}

sub get_file_handle {
  ## Gets a file handle object and open the given file
  ## Private method not exported
  my ($file, $arg) = @_;

  throw exception('FileNotFound', "File $file could not be found") unless $arg eq 'w' || -e $file && !-d $file;
  my $file_handle = FileHandle->new;
  $file_handle->open($file, $arg);
  return $file_handle;
}

1;
