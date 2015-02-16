=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tools::DHTMLmerge;

use strict;
use warnings;

use EnsEMBL::Web::Utils::FileSystem qw(list_dir_contents);
use EnsEMBL::Web::Exceptions;

sub get_filegroups {
  ## Gets a datastructure of lists of grouped files for the given type that are served to the frontend
  ## Override this method in plugins to add any extra files that are not present in the default 'components' folder (they can grouped using the group key to serve them on-demand)
  ## @param SpeciesDefs object
  ## @param css or js
  ## @return List of hashrefs as accepted by constructor of EnsEMBL::Web::Tools::DHTMLmerge::FileGroup
  my ($species_defs, $type) = @_;

  return {
    'group_name'  => 'components',
    'files'       => get_files_from_dir($species_defs, $type, 'components'),
    'condition'   => sub { 1 },
    'ordered'     => 0
  };
}

sub merge_all {
  ## This merges all CSS and JS files and saves the combined and minified ones on the disk
  ## Call this at startup
  ## @param EnsEMBL::Web::SpeciesDefs object
  my $species_defs  = shift;
  my $configs       = {};

  try {
    foreach my $type (qw(js css)) {
      push @{$configs->{$type}}, map { EnsEMBL::Web::Tools::DHTMLmerge::FileGroup->new($species_defs, $type, $_) } get_filegroups($species_defs, $type);
    }

    $species_defs->set_config('ENSEMBL_JSCSS_FILES', $configs);
    $species_defs->store;
  } catch {
    warn $_;
    throw $_;
  };
}

sub get_files_from_dir {
  ## Recursively gets all the files from all the directories (from inside all the HTDOCS dirs) with the given name
  ## @param SpeciesDefs object
  ## @param Type of files (css or js)
  ## @param Dir name to be checked in all HTDOCS dir
  ## @return Arrayref of absolute file names
  my ($species_defs, $type, $dir) = @_;

  my @files;

  foreach my $htdocs_dir (grep { !m/biomart/ && -d "$_/$dir" } reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS || []}) {
    push @files, map "$htdocs_dir/$dir/$_", grep m/\.$type$/, @{list_dir_contents("$htdocs_dir/$dir", {'recursive' => 1})};
  }

  return \@files;
}

###################################################
### Private packages to handle the js/css files ###
###################################################

package EnsEMBL::Web::Tools::DHTMLmerge::FileGroup;

use strict;
use warnings;

use B::Deparse;
use Digest::MD5 qw(md5_hex);
use CSS::Minifier;
use JavaScript::Minifier;

use EnsEMBL::Web::Utils::FileHandler qw(file_put_contents file_get_contents);
use EnsEMBL::Web::Utils::FileSystem qw(create_path);

sub new {
  ## @constructor
  ## @param SpeciesDefs object
  ## @param Type of the files in the group
  ## @param Hashref with follwing keys:
  ##  - group_name: Name of the group
  ##  - files: List of files
  ##  - condition: Reference to a subroutine that gets called with hub as an argument to decide whether to serve this group to the frontend along with the request or not
  ##  - ordered: Boolean if set true, the given order of files will be maintained, otherwise the files will be reordered according to the name but giving precedence to the already minified files
  my ($class, $species_defs, $type, $params) = @_;

  my @htdocs_dirs = reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS || []};

  # get the url paths for the files and keep only one file per url path
  my %files;
  my $order = $params->{'ordered'} ? 0 : undef;
  foreach my $abs_path (@{$params->{'files'}}) {

    my ($url_path, $plugin_order) = map { $abs_path =~ m/^$htdocs_dirs[$_](.+)$/ ? ($1, $_) : () } 0..$#htdocs_dirs; # there will only be one match

    $files{$url_path} = {
      'order'         => $files{$url_path} && $files{$url_path}{'order'} // (defined $order ? $order++ : undef), # if overwriting a file, keep the order as the original one
      'absolute_path' => $abs_path,
      'url_path'      => $url_path,
      'plugin_order'  => $files{$url_path} && $files{$url_path}{'plugin_order'} // $plugin_order, # if overwriting a file, keep the plugin order as the original one
    };
  }

  # sort the files according to original order if asked for, or give priority to the .min.js or .min.css among the files with same prefix if files are not sorted already
  my $sort_files = $params->{'ordered'}
    ? sub { $a->{'plugin_order'} <=> $b->{'plugin_order'} || $a->{'order'} <=> $b->{'order'} }
    : sub {
      my $x = { 'a' => $a, 'b' => $b };

      for (qw(a b)) {
        $x->{$_}{'url_path'} =~ /^(.*)\/(([0-9]{2})_[^\/]+)$/;
        $x->{$_} = { 'd' => $1, 'f' => $2, 'n' => $3, 'u' => $x->{$_}{'url_path'}, 'p' => $x->{$_}{'plugin_order'} };
      }

      defined $x->{a}{d} && $x->{a}{d} eq $x->{b}{d} && $x->{a}{n} == $x->{b}{n} && ($x->{a}{f} =~ /\.min\./ xor $x->{b}{f} =~ /\.min\./)
        ? $x->{a}{f} =~ /\.min\./ ? -1 : 1
        : $x->{a}{p} <=> $x->{b}{p} || $x->{a}{u} cmp $x->{b}{u}
      ;
    };

  my $self = bless {
    'group_name'  => $params->{'group_name'},
    'files'       => [ map EnsEMBL::Web::Tools::DHTMLmerge::File->new($_), sort $sort_files values %files ],
    'condition'   => $params->{'condition'} && ref $params->{'condition'} eq 'CODE' ? B::Deparse->new->coderef2text($params->{'condition'}) : undef
  }, $class;

  warn "Merging $self->{'group_name'} $type files\n";
  $self->{'minified_url_path'} = _merge_files($species_defs, $type, $self->{'files'});

  return $self;
}

sub name {
  ## @return Name of the group
  return shift->{'group_name'};
}

sub files {
  ## @return Arrayref of all the file objects
  return shift->{'files'};
}

sub minified_url_path {
  ## @return URL path minified file name for this group
  return shift->{'minified_url_path'};
}

sub condition {
  ## Tells whether the files from this group are required by the page or not
  ## @param EnsEMBL::Web::Hub object
  ## @return 1/0
  my ($self, $hub) = @_;

  if ($self->{'condition'}) {
    my $condition = eval "sub $self->{'condition'}";
    return $condition->($hub) ? 1 : 0;
  }

  return 1;
}

sub _merge_files {
  ## @private
  my ($species_defs, $type, $files) = @_;

  my @contents;
  my $combined = '';

  # combine the files together to run the least possible number of minification processes
  foreach my $file (@$files) {
    my $key     = $file->needs_minification ? 'not_minified' : 'minified';
    my $content = $file->get_contents($species_defs, $type);
    $combined  .= $content;

    push @contents, {$key => ''} unless @contents && exists $contents[-1]->{$key}; # add a new entry to the array if last one doesn't contain the required key
    $contents[-1]->{$key} .= "$content\n";
  }

  my $filename  = md5_hex($combined);
  my $url_path  = sprintf '%s/%s.%s', $species_defs->ENSEMBL_MINIFIED_FILES_PATH, $filename, $type;
  my $abs_path  = sprintf '%s%s', $species_defs->ENSEMBL_DOCROOT, $url_path;

  # create and save the minified file if it doesn't already exist there
  file_put_contents($abs_path, map { $_->{'minified'} // ($_->{'not_minified'} ? _minify_content($species_defs, $type, $abs_path, $_->{'not_minified'}) : '') } @contents) unless -e $abs_path;

  return $url_path;
}

sub _minify_content {
  ## @private
  my ($species_defs, $type, $abs_path, $content) = @_;
  my $compression_dir = sprintf '%s/utils/compression/', $species_defs->ENSEMBL_WEBROOT;
  my $tmp_filename    = "$abs_path.tmp";
  my $abs_path_dir    = $abs_path =~ s/\/[^\/]+$//r;

  # create the dir if it doesn't already exist
  create_path($abs_path_dir) unless -d $abs_path_dir;

  if ($type eq 'js') { # wrap javascript for extra compression
    $content = sprintf '(function($,window,document,undefined){%s})(jQuery,this,document)', $content;
  }

  # save a temporary file needed for running compression jar
  file_put_contents($tmp_filename, $content);

  my $jar = $type eq 'js'
    ? join ' ', $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/compiler.jar", '--js', $tmp_filename, '--compilation_level', 'SIMPLE_OPTIMIZATIONS', '--warning_level', 'QUIET'
    : join ' ', $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/yuicompressor-2.4.7.jar", '--type', 'css', $tmp_filename;

  my $compressed = `$jar`;
     $compressed = $type eq 'js' ? JavaScript::Minifier::minify('input' => $compressed) : CSS::Minifier::minify('input' => $compressed);

  # not needed anymore
  unlink $tmp_filename;

  return $compressed;
}

package EnsEMBL::Web::Tools::DHTMLmerge::File;

use strict;
use warnings;

use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

sub new {
  ## @constructor
  ## @param Hashref with follwing keys:
  ##  - absolute_path: Absolute path to the file
  ##  - url_path: Path using which the file can be retrieved via URL
  my ($class, $self) = @_;
  return bless $self, $class;
}

sub absolute_path {
  ## @return Absolute path of the file
  return shift->{'absolute_path'};
}

sub url_path {
  ## @return URL path for the file
  return shift->{'url_path'};
}

sub needs_minification {
  ## Tell whether the file is already minified or not
  return shift->{'absolute_path'} =~ /\.min\.[^\/]+$/ ? 0 : 1;
}

sub get_contents {
  ## Gets the actual contents of the file
  ## @param Reference to SpeciesDefs object
  ## @param Type of the file (css or js)
  ## @return File contents (string)
  my ($self, $species_defs, $type) = @_;
  my $content = join '', file_get_contents($self->{'absolute_path'});

  # For css file, convert style placeholders to actual colours
  if ($type eq 'css') {
    my $sequence_markup = $species_defs->colour('sequence_markup') || {}; # Add sequence markup colours to ENSEMBL_STYLE - they are used in CSS. This smells a lot like a hack.
    my %colours         = (%{$species_defs->ENSEMBL_STYLE || {}}, map { $_ => $sequence_markup->{$_}{'default'} } keys %$sequence_markup);
       $colours{$_}     =~ s/^([0-9A-F]{6})$/#$1/i for keys %colours;
       $content         =~ s/\[\[(\w+)\]\]/$colours{$1}||"\/* ARG MISSING DEFINITION $1 *\/"/eg; 
  }

  return $content;
}

1;
