# USAGE: perl utils/static_content/doxygen/build.pl [--dir root directory of server] [--apis comma-separated list of apis]

use strict;

use Cwd;
use Getopt::Long;

Getopt::Long::Configure('bundling');

my $root = getcwd();
my @apis;

my $flag = GetOptions(
  'dir=s',  \$root,
  'apis=s', \@apis,
);

my $dir   = "$root/utils/static_content/doxygen";
my $html  = "$root/htdocs/info/docs/Doxygen";
my $edocs = $apis[0] eq 'edocs' || !scalar @apis;

@apis = split /,/, join ',', @apis;
@apis = qw(core hive compara analysis external functgenomics pipeline variation) unless scalar @apis; # core and hive must always be first in order to generate links

unshift @INC, "$root/conf", $root;
require SiteDefs;

if ($apis[0] ne 'edocs') {
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
      TAGFILES        => "ensembl.tag=../core-api/ \\ \n                         hive.tag=../hive-api/",
    },
    external => {
      STRIP_FROM_PATH => "$root/ensembl-external/modules/Bio/",
    },
    functgenomics => {
      PROJECT_NAME     => '"Ensembl FuncGen"',
      PROJECT_BRIEF    => '"EnsEMBL FuncGen API reference"',
      OUTPUT_DIRECTORY => "$html/funcgen-api",
      STRIP_FROM_PATH  => "$root/ensembl-functgenomics/modules/Bio/",
    },
  );

  my %config_template = (
    PROJECT_NUMBER    => $SiteDefs::VERSION,
    PROJECT_NAME      => '"Ensembl %s"',
    PROJECT_BRIEF     => '"EnsEMBL %s API reference"',
    OUTPUT_DIRECTORY  => "$html/%s-api",
    STRIP_FROM_PATH   => "$root/ensembl-%s/modules/Bio/EnsEMBL/",
    INPUT             => "$root/ensembl-%s/modules/",
    EXCLUDE           => '',
    TAGFILES          => 'ensembl.tag=../core-api/',
    GENERATE_TAGFILE  => '%s.tag',
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
    my $api_dir = 'ensembl' . ($api eq 'core' ? '' : "-$api");
    system("cd $root; cvs co $api_dir") unless -e "$root/$api_dir";
    
    # Run doxygen
    system("
      cd $dir
      export PERL5LIB=\${PERL5LIB}:\${PWD}/lib/site_perl/5.8.8/
      export PATH=\${PWD}/bin:\${PATH}
      doxygen ${api}_docbuild 2> ${api}_error.log
    ");
  }

  print "Finished building Doxygen documentation.\n";
}

if ($edocs) {
  # generate e! docs:
  system(qq{
    echo "Generating e! docs";
    rm -rf $root/htdocs/info/docs/webcode/edoc
    perl $root/utils/edoc/update_docs.pl
    echo "Copying temp files to live directory"
    cp -r $root/utils/edoc/temp htdocs/info/docs/webcode/edoc
    echo "Clearing up e! docs temp files";
    rm -rf $root/utils/edoc/temp
  });

  print "Finished building e! docs\n";
}
