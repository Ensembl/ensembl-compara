use strict;

my $root  = shift;
my $dir   = "$root/utils/static_content/doxygen";
my $html  = "$root/htdocs/info/docs/Doxygen";
my @apis  = scalar @ARGV ? @ARGV : qw(core hive compara analysis external functgenomics pipeline variation);

unshift @INC, "$root/conf", $root;
require SiteDefs;

my %config_by_api = (
  core => {
    PROJECT_NAME    => 'Ensembl',
    INPUT           => "$root/ensembl/modules/",
    EXCLUDE         => "$root/modules/t $root/ensembl/misc-scripts/",
    STRIP_FROM_PATH => "$root/ensembl/modules/",
    TAGFILES        => '',
  },
  compara => {
    STRIP_FROM_PATH => "$root/ensembl-compara/modules/",
    TAGFILES        => "ensembl.tag=../core-api/ \ \nhive.tag=../hive-api/",
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
my @docbuilds;

foreach my $api (@apis) {
  my %config = map { $_ => exists $config_by_api{$api}{$_} ? $config_by_api{$api}{$_} : sprintf($config_template{$_}, /PROJECT_(NAME|BRIEF)/ ? ucfirst $api : $api) } keys %config_template;
  my $output = $template;
  
  foreach my $key (keys %config) {
    $output =~ s/^($key\s+=)/$1 $config{$key}/m if $config{$key};
  }
  
  open FH, ">$dir/${api}_docbuild" or die "Couldn't open ${api}_docbuild for writing";
  print FH $output;
  close FH;
  
  system("
    cd $dir
    export PERL5LIB=\${PERL5LIB}:\${PWD}/lib/site_perl/5.8.8/
    export PATH=\${PWD}/bin/:\${PATH}
    doxygen ${api}_docbuild 2> ${api}_error.log
  ");
  
  #unlink "$dir/${api}_docbuild";
}

