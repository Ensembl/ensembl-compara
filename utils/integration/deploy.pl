#!/localsw/perl-5.8.8/bin/perl

#use strict;
#use warnings;
use Data::Dumper;
use YAML qw(LoadFile);
use Mail::Mailer;
use Carp;

my ($stderr, $stdout);

sub execute {
  my $command = shift;
  my $ignore_failures = shift;
  print "$command\n";
  if (system($command) != 0 && !$ignore_failures) {
    execute('rm -f lock', 1);
    execute("rm -rf $checkout", 1);
    mail($?);
    die " FAILED: $?";
  }
}

sub mail {
  my $error = shift;
  my $mailer = new Mail::Mailer 'smtp', Server => 'localhost';
  $mailer->open({
    'To'      => 'eb4@sanger.ac.uk',
    'From'    => 'head@ensembl.org',
    'Subject' => "Failed to deploy head.ensembl.org: $error",
  });
  
  open LOG, 'deploy.out.log';
  my $body = "STDOUT: \n". join "\n", <LOG>;
  close LOG;
  
  open LOG, 'deploy.err.log';
  $body .= "\n\n\nSTDERR: \n". join "\n", <LOG>;
  close LOG;
  
  print $mailer $body;
  $mailer->close();
}

BEGIN {
  no strict 'refs';

  my $config;
  my $config_file = $ARGV[0] || './deploy.yml';
  print "Using: $config_file\n";
  if (-e $config_file) {
    $config = LoadFile($config_file);
  } else {
    croak "Error opening config file: $config_file\n $!";
  }  

  while (my ($key, $value) = each %$config) {
    *{ "main\::$key" } = \$value;
  }

  chdir $integration_path;

  close STDOUT;
  open  STDOUT, '>deploy.out.log' or die "Can't open STDOUT: $!";
  
  close STDERR;
  open  STDERR, '>deploy.err.log' or die "Can't open STDERR: $!";


#  push @INC, $integration_path . '/modules';
#  $SIG{INT} = \&CATCH;
}

my $run;

if (-e $checkout) {
  execute("cvs -n -q up -d $checkout > $integration_path/cvs.update");
  open (INPUT, "$integration_path/cvs.update") or die "$!";
  $run = 1 if grep {/^U/} <INPUT>;
  close INPUT;
} else {
  $run = 1;
}

unless ($run) {
  print "Everything is up to date - exiting.\n";
  execute('rm -f lock');
  exit;
}

print "Updates found - syncing server.\n";
execute("rm -rf $checkout");

if (-e 'lock') {
  print "Locked - exiting\n";
  execute('rm -f lock');
  exit;
} else {
  execute('touch lock');
}

execute('cvs -q -d :ext:'.$cvs_user.'@'.$cvs_server.':'.$cvs_root." co -d $checkout ensembl-website ensembl-api sanger-plugins > /dev/null");
execute("cp -f support/Plugins.test.pm $checkout/conf/Plugins.pm");

execute("ln -s $apache_src $checkout/apache2");
execute("ln -s $bioperl_live $checkout/bioperl-live");

mkdir "$checkout/img";
mkdir "$checkout/logs";
mkdir "$checkout/tmp";


execute("$checkout/ctrl_scripts/stop_server", 1);
sleep 8;
execute("$checkout/ctrl_scripts/start_server");
sleep 8;
execute("$checkout/ctrl_scripts/stop_server", 1);

execute("cp -f support/Plugins.pm $checkout/conf/");
execute("cp -rpf $checkout/* /ensemblweb/head/");

execute("/ensemblweb/head/ctrl_scripts/stop_server", 1);
sleep 8;
execute("/ensemblweb/head/ctrl_scripts/start_server");

execute("rm -f lock");

sub CATCH {
  my $sig = shift;
  print 'SIGINT caught - exiting';
  execute("rm -f lock");
  exit;
}
