=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Utils::FileSystem;

use strict;
use warnings;

use DirHandle;
use File::Path qw(make_path remove_tree);
use File::Copy;

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(create_path remove_directory remove_empty_path copy_dir_contents copy_files list_dir_contents);

sub create_path {
  ## Wrapper around make_path, throws an exception if things don't work as expected
  ## @param Path string
  ## @param (optional) Hashref as expected by File::Path::make_path() with an extra key 'no_exception' which if set true, will not throw any exception
  ## @return Arrayref of directories actually created during the call, undef for any problem (in case if 'no_exception' key is set)
  my ($path, $params) = @_;

  $params         ||= {};
  my $no_exception  = delete $params->{'no_exception'};
  my @directories   = make_path($path, { %$params, 'error' => \my $error });

  if (@$error) {
    return undef if $no_exception;
    throw exception('FileSystemException', sprintf qq(Could not create the given path '%s' due to following errors: \n%s), $path, displayable_error($error));
  }

  return \@directories;
}

sub remove_directory {
  ## Removes a directory and all it's contents
  ## @param Path string
  ## @param (optional) Hashref as expected by File::Path::remove_tree() with an extra key 'no_exception' which if set true, will not throw any exception
  ## @return The number of files successfully deleted, undef for any problem (in case if 'no_exception' key is set)
  my ($path, $params) = @_;

  $params         ||= {};
  my $no_exception  = delete $params->{'no_exception'};
  my $file_count    = remove_tree($path, { %$params, 'error' => \my $error});

  if (@$error) {
    return undef if $no_exception;
    throw exception('FileSystemException', sprintf qq(Could not remove the given directory '%s' due to following errors: \n%s), $path, displayable_error($error));
  }

  return $file_count;
}

sub remove_empty_path {
  ## Remvoes a directory and all the parent directories that become empty afterwards.
  ## @param Path string
  ## @param Hashref with following keys:
  ##  - remove_contents : Flag if on, will remove the contents of the given dir before removing parent dirs.
  ##  - exclude         : Array of folders name that should not be removed while going up the tree (names only, not paths - i.e. no slashes)
  ##  - no_exception    : Flag if on, will not throw any exception, but will return undef in case it fails anywhere
  ## @return 1 if all done successfully, undef for any problem
  my ($path, $params) = @_;

  $params     ||= {};
  my $exclude   = delete $params->{'exclude'};
  my %exclusion = map { $_ => 1 } @{$exclude || []};

  if (!$params->{'remove_contents'} || remove_directory($path, {'keep_root' => 1, 'no_exception' => delete $params->{'no_exception'} })) {
    my @path = split /\//, $path;
    pop @path while @path && !$exclusion{$path[-1]} && rmdir join('/', '', @path);
    return 1;
  }
}

sub copy_dir_contents {
  ## Copies contents of one directory to another
  ## Throws an exception if destination doesn't exist.
  ## @param Path string
  ## @param Hashref with following keys:
  ##  - create_path   : Flag if on, will try to create the destination path is already not there
  ##  - recursive     : (0/1/include_dirs) 1: will do a recursive copy, 0: will ignore sub directories completely (default), 'include_dirs': will make paths for immediate sub directories
  ##  - exclude       : Array of files/folders to be excluded (names only, not path)
  ##  - no_exception  : Flag if on, will not throw any exception, but will return undef in case it fails anywhere
  ## @return Arrayref of absolute path to files, folders copied/created (undef for any problem)
  my ($source_dir, $dest_dir, $params) = @_;

  $source_dir       =~ s/\/$//;
  $source_dir       =~ s/\/+/\//;
  $dest_dir         =~ s/\/$//;
  $dest_dir         =~ s/\/+/\//;
  $params         ||= {};

  my $no_exception  = delete $params->{'no_exception'};
  my $contents      = [];
  my %exclude       = map { $_ =~ s/\/$//r => 1 } @{$params->{'exclude'} || []};
  my $dir_contents  = list_dir_contents($source_dir, {'no_exception' => $no_exception}) or return undef;

  if (!-d $dest_dir) {
    if ($params->{'create_path'}) {
      push @$contents, @{ create_path($dest_dir) };
    } else {
      throw exception('FileSystemException', "Destination directory $dest_dir does not exist.") unless $no_exception;
      return undef;
    }
  }

  foreach my $content (@$dir_contents) {

    next if $content =~ /^\.+/ || $exclude{$content};

    try {
      if (-d "$source_dir/$content") {
        if ($params->{'recursive'}) {
          push @$contents, @{ create_path("$dest_dir/$content") };
          push @$contents, @{ copy_dir_contents("$source_dir/$content", "$dest_dir/$content", $params) } if $params->{'recursive'} ne 'include_dirs';
        }

      } else {
        throw exception('FileSystemException', "An error occoured while copying $source_dir/$content: $!") unless copy("$source_dir/$content", "$dest_dir/$content");
        push @$contents, "$dest_dir/$content";
      }
    } catch {

      # if an error occurred somewhere, rollback and throw the same exception
      -d $_ ? rmdir $_ : unlink $_ for reverse @$contents; # reverse to make sure parent directories are removed in the end
      throw $_ unless $no_exception;
      $contents = undef;
    };

    last unless $contents;
  }

  return $contents;
}

sub copy_files {
  ## Copies files according to the given hash map
  ## @param Hashref with keys as sources and values as corresponding destinations
  ## @param Hashref with a key 'no_exception', which if set true will not throw an exception if there's any problem copying.
  ## @return Arrayref of files copied if copy is successful or undef if it fail anywhere (only if 'no_exception' key is set true)
  my ($files, $params) = @_;

  $params ||= {};
  my @copied;

  for (keys %$files) {
    push @copied, $files->{$_};
    unless (copy($_, $files->{$_})) {
      unlink @copied; #rollback
      throw exception('FileSystemException', "An error occoured while copying $_: $!") unless $params->{'no_exception'};
      return;
    }
  }
  return \@copied;
}

sub list_dir_contents {
  ## Returns all the files and dir in a directory
  ## @param Dir path
  ## @param Hashref with keys
  ##  - hidden : if on, will return hidden files too (off by default)
  ##  - no_exception :  if set true will not throw an exception if there's any problem
  ##  - recursive: flag if on, will get all the files recursively going through each sub folder
  ##  - absolute_path: flag if on, will return the absolute path for the files/folders (off by default)
  ## @return Arrayref of files/dir, undef if dir not existing
  my ($dir, $params) = @_;

  $params ||= {};
  my $ls    = [];
  my $dh    = DirHandle->new($dir);
  my $abs   = delete $params->{'absolute_path'}; # delete param so it doesn't get passed to recursive calls

  if (!$dh) {
    throw exception('FileSystemException', "An error occoured while reading the directory $dir: $!") unless $params->{'no_exception'};
    return undef;
  }

  while (my $content = $dh->read) {

    next if !$params->{'hidden'} && $content =~ /^\.+/;
    push @$ls, $content;

    if ($params->{'recursive'} && -d "$dir/$content" && $content !~ /^\.+$/) {
      push @$ls, map {"$content/$_"} @{list_dir_contents("$dir/$content", $params)};
    }
  }

  $dh->close;

  @$ls = map "$dir/$_", @$ls if $abs;

  return $ls;
}

sub displayable_error {
  ## @private
  my $error = shift;
  return join "\n", map { join ': ', 'For ', keys %$_, values %$_ } @$error;
}

1;
