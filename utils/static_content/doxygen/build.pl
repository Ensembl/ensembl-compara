# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# USAGE: perl utils/static_content/doxygen/build.pl [--dir root directory of server] [--apis comma-separated list of apis]

use strict;

use Cwd;
use Getopt::Long;
use File::Basename;

Getopt::Long::Configure('bundling');

my $root = getcwd();
my @apis;

my $flag = GetOptions(
  'dir=s',  \$root,
  'apis=s', \@apis,
);

my $filter_dir = "$root/ensembl/misc-scripts/doxygen_filter/";

my $dir   = "$root/ensembl-webcode/utils/static_content/doxygen";
my $html  = "$root/public-plugins/docs/htdocs/info/docs/Doxygen";

@apis = split /,/, join ',', @apis;
@apis = qw(core compara analysis funcgen pipeline variation production metadata) unless scalar @apis; # core must always be first in order to generate links

unshift @INC, "$root/ensembl-webcode/conf", $root;
require SiteDefs; SiteDefs->import;

my %config_by_api = (
    core => {
      PROJECT_NAME     => 'Ensembl',
      INPUT            => "$root/ensembl/modules/",
      EXCLUDE          => "$root/modules/t $root/ensembl/misc-scripts/",
      STRIP_FROM_PATH  => "$root/ensembl/modules/",
      TAGFILES         => '',
      GENERATE_TAGFILE => 'ensembl.tag'
  },
  compara => {
      STRIP_FROM_PATH => "$root/ensembl-compara/modules/",
      TAGFILES        => "ensembl.tag=../core-api/ \\ \n",
  },
  funcgen => {
      PROJECT_NAME     => '"Ensembl FuncGen"',
      PROJECT_BRIEF    => '"EnsEMBL FuncGen API reference"',
      OUTPUT_DIRECTORY => "$html/funcgen-api",
      STRIP_FROM_PATH  => "$root/ensembl-funcgen/modules/Bio/",
  },
  production => {
      PROJECT_NAME     => '"Ensembl Production"',
      PROJECT_BRIEF    => '"EnsEMBL Production API reference"',
      TAFILES          => "ensembl.tag=../core-api/ \\ \n",
  },
  ensemblgenomes => {
      PROJECT_NAME     => '"Ensembl Genomes"',
      PROJECT_BRIEF    => '"EnsEMBL Genomes API reference"',
      INPUT            => "$root/ensemblgenomes-api/modules/",
      EXCLUDE          => "$root/ensemblgenomes-api/t $root/ensemblgenomes-api/misc-scripts",
      STRIP_FROM_PATH  => "$root/ensemblgenomes-api/modules/",
      TAGFILES         => '',
  },
  metadata => {
      PROJECT_NAME     => '"Ensembl Metadata"',
      PROJECT_BRIEF    => '"EnsEMBL Metadata API reference"',
  },
);

my %config_template = (
    PROJECT_NUMBER    => $SiteDefs::ENSEMBL_VERSION,
    PROJECT_NAME      => '"Ensembl %s"',
    PROJECT_BRIEF     => '"EnsEMBL %s API reference"',
    OUTPUT_DIRECTORY  => "$html/%s-api",
    STRIP_FROM_PATH   => "$root/ensembl-%s/modules/Bio/EnsEMBL/",
    INPUT             => "$root/ensembl-%s/modules/",
    EXCLUDE           => '',
    TAGFILES          => 'ensembl.tag=../core-api/',
    GENERATE_TAGFILE  => '%s.tag',
    INPUT_FILTER      => "$filter_dir/ensembldoxygenfilter.pl",
);

my $template = `cat $dir/docbuild_template`;

foreach my $api (@apis) {
  # Make the docbuild file from the template
  my %config = map { $_ => exists $config_by_api{$api}{$_} ? $config_by_api{$api}{$_} : sprintf($config_template{$_}, /PROJECT_(NAME|BRIEF)/ ? ucfirst $api : $api) } keys %config_template;
  my $output = $template;
    
  foreach my $key (keys %config) {
    $output =~ s/^($key\s+=)/$1 $config{$key}/m if $config{$key};
  }
    
  open FH, ">$dir/${api}_docbuild" or die "Couldn't open ${api}_docbuild for writing";
  print FH $output;
  close FH;
    
  # Check out the code if it doesn't exist
  my $api_dir = $config{API_DIR} || ('ensembl' . ($api eq 'core' ? '' : "-$api"));
  $api_dir = 'ensemblgenomes-api' if ($api eq 'ensemblgenomes');
   
  system("cd $root; git clone https://github.com/Ensembl/$api_dir") unless -e "$root/$api_dir";
    
  # Run doxygen
  system("
    cd $dir
    export PERL5LIB=\${PERL5LIB}:$filter_dir
    export PATH=\${PWD}/bin:\${PATH}
    doxygen ${api}_docbuild 2> ${api}_error.log
  ");
}

print "Finished building Doxygen documentation.\n";

