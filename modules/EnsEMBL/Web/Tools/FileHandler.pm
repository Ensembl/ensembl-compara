package EnsEMBL::Web::Tools::FileHandler;

use strict;
use warnings;

use FileHandle;
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_get_contents file_put_contents file_append_contents);

sub file_get_contents {
  ## Reads a file from memory location
  ## @param File location
  ## @return List of lines of files
  my $filename    = shift;

  throw exception('FileNotFound', "File $filename could not be found") if !-e $filename || -d $filename;

  my $file_handle = get_file_handle($filename, 'r');
  my @lines       = $file_handle->getlines;
  $file_handle->close;
  return @lines;
}

sub file_put_contents {
  ## Write the content to the file
  ## Creates a new file if not existing one
  ## Overrites any existing content if file existing
  ## @param  File location
  ## @params List of text to be written
  my $file_handle = get_file_handle(shift, 'w');

  $file_handle->print(@_);
  $file_handle->close;
}

sub file_append_contents {
  ## Appends the content to the file
  ## Creates a new file if not existing one
  ## @param  File location
  ## @params List of lines of text to be appended
  my $file_handle = get_file_handle(shift, 'a');

  $file_handle->print(@_);
  $file_handle->close;
}

sub get_file_handle {
  ## Gets a file handle object and open the given file
  ## Private method not exported
  my ($file, $arg) = @_;

  my $file_handle = FileHandle->new;
  $file_handle->open($file, $arg);
  return $file_handle;
}

1;
