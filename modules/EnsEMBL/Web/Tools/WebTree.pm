=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tools::WebTree;

### Reads the static content directory tree(s) and creates a data structure
### used to provide automated navigation

use strict;

sub read_tree {
###
### Recursive function which descends into a directory and creates
### a tree of htdocs static pages with a multi-level hashref:
###  {
###    _path  => '/...',              # web path
###    _nav   => 'navigation info',   # from meta tags
###    _rel   => 'related content',   # from meta tags
###    _title => 'title',             # from title tag
###    _index => '0',                 # order index, from meta tag
###    _show  => '',                  # does it have a real index.html or a placeholder?
###    file1  => {nav => '...', title => '...', index => '...'},
###    file2  => {nav => '...', title => '...', index => '...'},
###    ...,
###    dir1  => { ..same structure as parent.. },
###    dir2  => { ..same structure as parent.. },
###    ...,
###  }
###
### N.B. A directory can be omitted by putting 'NO INDEX' as the value
### of the navigation meta tag

  my(
    $branch,    ## hashref to be populated, branch of the tree
                ## by default its { path => '/path/..' }
    $doc_root,  ## this could be different because of the plugins
    $parent,    ## this is link to parent in case we need to delete ourselves
  ) = @_;

  my $path = $branch->{_path};

  return unless -r "$doc_root$path";

  ## Get the list of files for directory of the current path.
  opendir(DIR, $doc_root . $path) || die "Can't open $doc_root$path";
  my @files = grep { /^[^\.]/ && $_ ne 'CVS' } readdir(DIR);
  closedir(DIR);
  unless (@files) {
    delete $parent->{$branch->{'_name'}};
    return;
  }

  ## separate directories from other files
  my ($html_files, $sub_dirs) = sortnames(\@files, $doc_root . $path);
  ## Remove if this is a "storage" directory only
  if (!@$html_files && !@$sub_dirs) {
    delete $parent->{$branch->{'_name'}};
    return;
  }

  my ($title, $nav, $rel, $index);
  ## Check if we want to do this directory at all
  my $include = 1; 
  $branch->{'_show'} = 'y' unless $branch->{'_show'} eq 'n';
  foreach my $filename (@$html_files) {
    $branch->{'_related'} = $rel; 
    if( $filename eq 'index.html' || $filename eq 'index.none' ) {
      my ($title, $nav, $rel, $order, $index) = get_info( $doc_root . $path . $filename );
      $branch->{'_show'} = 'n' if $filename eq 'index.none';
      $branch->{'_show'} = 'y' if $filename eq 'index.html';
      if ($index =~ /NO FOLLOW/) {
        $branch->{_title} = $title;
        $branch->{_nav}   = $nav;
        $branch->{_order} = $order;
        $branch->{_index} = $index;
        $branch->{_no_follow} = 1;
      } elsif ($index =~ /NO INDEX/) {
        $include = 0;
      }
      last;
    }
  }
  if (!$include) {
    delete $parent->{$branch->{'_name'}};
    return;
  }

  ## Read files and populate the branch
  foreach my $filename (@$html_files) {
    my $full_path = "$doc_root$path$filename";
    my ($title, $nav, $rel, $order, $index) = get_info( $full_path );

    if ($filename eq 'index.html' || $filename eq 'index.none' ) {
      ## add the directory path and index title to array
      $branch->{_title} = $title;
      $branch->{_nav}   = $nav;
      $branch->{_rel}   = $rel;
      $branch->{_order} = $order;
      $branch->{_index} = $index;
      $branch->{_nolink} = 1 if $filename eq 'index.none';
    }
    else {
      if ($index =~ /DELETE/) {
	delete $parent->{$branch->{'_name'}}->{$filename};
	next;
      }

      unless ($index =~ /NO INDEX/ || $branch->{'_no_follow'}) {
        $branch->{$filename}->{_title} = $title;
        $branch->{$filename}->{_nav}   = $nav;
        $branch->{$filename}->{_order} = $order;
        $branch->{$filename}->{_index} = $index;
      }
    }
  }

  ## Descend into directories recursively
  return if $branch->{'_no_follow'};
  foreach my $dirname (@$sub_dirs) {
    ## omit CVS directories and directories beginning with . or _
    next if $dirname eq 'CVS' || $dirname =~ /^\./ || $dirname =~ /^_/ 
        || $dirname eq 'private' || $dirname eq 'ssi';
    $branch->{$dirname}->{_path} = "$path$dirname/";
    $branch->{$dirname}->{_name} = $dirname;
    read_tree( $branch->{$dirname}, $doc_root, $branch );
  }
}

sub read_species_dirs {
### A simpler version of read_tree, which only looks in species home directories
### for HTML files
  my ($branch, $docroot, $species_list, $parent) = @_;

  ## Look for species directories only
  foreach my $species (@$species_list) {
    opendir(DIR, $docroot . '/' . $species) or next;
    my @files = grep { /^[^\.]/ && $_ ne 'CVS' } readdir(DIR);
    closedir(DIR);

    ## separate directories from other files
    my ($html_files, $sub_dirs) = sortnames(\@files, $docroot.'/'.$species);
    my ($title, $nav, $index);

    ## Read files and populate the branch
    foreach my $filename (@$html_files) {
      my $full_path = "$docroot/$species/$filename";
      my ($title, $nav, $order, $index) = get_info( $full_path );

      unless ($index =~ /NO INDEX/) {
        $branch->{$species}{$filename}->{_title} = $title;
        $branch->{$species}{$filename}->{_nav}   = $nav;
        $branch->{$species}{$filename}->{_order} = $order;
        $branch->{$species}{$filename}->{_index} = $index;
      }
    }
  }


}

sub sortnames {
### Does a case-insensitive sort of a list of file names
### and separates them into two lists - directories and non-directories
  my( $namelist, $full_path) = @_;
  my @sorted = sort {lc $a cmp lc $b} @$namelist;

  my (@file_list, @dir_list);

  foreach my $item (@sorted) {
    if (-d $full_path.$item) {
      push (@dir_list, $item);
    }
    elsif ($item =~ /\.(html|none)$/) {
      push (@file_list, $item);
    }
  }

  return (\@file_list, \@dir_list);
}

sub get_info {
### Parses an HTML file and returns info for navigation and indexing
  my( $file ) = @_;

  open IN, "< $file" || die("Can't open input file $file :(\n");
  my @contents = <IN>;
  close IN;
  my $title   = get_title(\@contents);
  my $nav     = get_meta_navigation(\@contents);
  my $rel     = get_meta_related(\@contents);
  my $order   = get_meta_order(\@contents);
  my $index   = get_meta_index(\@contents);
  $title = get_first_header(\@contents) unless $title;
  $nav   = $title                       unless $nav;
  $order = 100                          unless $order; ## Unordered pages go at the end!

  return ($title, $nav, $rel, $order, $index);
}

sub get_title {
### Parses an HTML file and returns the contents of the <title> tag
  my( $contents ) = @_;
  my $title;

  foreach(@$contents) {
    if( m!<title.*?>(.*?)(?:</title>|$)!i) {
      $title = $1;
    } elsif( defined($title) && m!^(.*?)(?:</title>|$)!i) {
      $title .= $1;
    }
    last if m!</title!i;
  }

  $title =~ s/\s{2,}//g;
  return $title;
}

sub get_meta_navigation {
### Parses an HTML file and returns the contents of the navigation meta tag
  my( $contents ) = @_;
  my $nav;

  foreach(@$contents) {
    if (/<meta\s+name\s*=\s*"navigation"\s+content\s*=\s*"([^"]+)"\s*\/?>/ism) {
      $nav = $1;
    } elsif (/<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"navigation"\s*\/?>/ism) {
      $nav = $1;
    }
  }

  return $nav;
}

sub get_meta_related {
### Parses an HTML file and returns the contents of the 'related' meta tag
  my( $contents ) = @_;
  my $rel;

  foreach(@$contents) {
    if (/<meta\s+name\s*=\s*"related"\s+content\s*=\s*"([^"]+)"\s*\/?>/ism) {
      $rel = $1;
    } elsif (/<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"related"\s*\/?>/ism) {
      $rel = $1;
    }
  }

  return $rel;
}

sub get_meta_order {
### Parses an HTML file and returns the contents of the navigation meta tag
  my( $contents ) = @_;
  my $nav;

  foreach(@$contents) {
    if (/<meta\s+name\s*=\s*"order"\s+content\s*=\s*"([^"]+)"\s*\/?>/ism) {
      $nav = $1;
    } elsif (/<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"order"\s*\/?>/ism) {
      $nav = $1;
    }
  }

  return $nav;
}


sub get_meta_index {
### Parses an HTML file and returns the contents of the index meta tag
  my( $contents ) = @_;
  my $index;

  foreach(@$contents) {
    if (/<meta\s+name\s*=\s*"index"\s+content\s*=\s*"([^"]+)"\s*\/?>/ism) {
      $index = $1;
    } elsif (/<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"index"\s*\/?>/ism) {
      $index = $1;
    }
  }

  return $index;
}

sub get_first_header {
### Parses an HTML file and returns the contents of the first <h> tag (up to h3)
  my( $contents ) = @_;
  my $header;

  foreach(@$contents) {
    if (m!<h1.*?>(.*?)(?:</h1>|$)!i) {
      $header = $1;
      last;
    } elsif (m!<h2.*?>(.*?)(?:</h2>|$)!i) {
      $header = $1;
      last;
    }
    elsif (m!<h3.*?>(.*?)(?:</h3>|$)!i) {
      $header = $1;
      last;
    }
  }
  ## Fallback in case no <h> tags

#  unless ($header) {
#    if ($file =~ m!/(\w+)/index\.html!) {
#      $header = $1;
#    } elsif ($file =~ m!/(\w+)\.html!) {
#      $header = $1;
#    }
#  }

  $header =~ s/\s\s+/ /g;
  $header =~ s/^\s//;
  $header =~ s/\s$//;
  return $header;
}

1;
