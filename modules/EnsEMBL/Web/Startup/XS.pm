=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Startup::XS;

use strict;
use warnings;

use FindBin;
use Config;

use JSON qw(from_json);

use Exporter 'import';
our @EXPORT_OK = qw(using_xs fake_if_missing);

my %using;

sub load_exs {
  my ($exs) = @_;

  eval {
    my $module = $exs->{'module'};
    my $path = "$module.pm";
    $path =~ s!::!/!g;
    require $path;
    $path->import();
    if($exs->{'test'}) {
      no strict;
      my $test = $exs->{'test'};
      $test =~ /^(.*)::(.*?)$/;
      my ($root,$rest) = ($1,$2);
      die "Test $root/$rest failed"
        unless exists ${"${root}::"}{"${rest}::"};
    }
    $using{$exs->{'module'}} = 1;
  };
  if($using{$exs->{'module'}}) {
    return "$exs->{'name'}: $exs->{'purpose'}";
  } else {
    use_if_exists($exs->{'module'});
    die "Load failed: $@";
  }
}

sub fake_if_missing {
  eval "package $_[0]; 1;";
}

sub using_xs { return $using{$_[0]}; }

sub bootstrap_begin {
  my @found;

  my $root = "$FindBin::Bin/../xs";
  my $libroot = "$root/inst/lib/perl5";
  my $arch = $Config{'archname'};
  my $version = $Config{'version'};
  my @dirs = ("","/$version","/$version/auto",
              "/$version/$arch","/$version/$arch/auto");
  @dirs = map { ("$libroot$_","$libroot/site_perl$_") } @dirs;
  unshift @INC,@dirs;
  foreach my $exs (split(/\n/,qx(find $libroot $root/external -name \\*.exs 2>/dev/null))) {
    eval {
      local $/ = undef;
      open(EXS,$exs) || die;
      push @found,load_exs(from_json(<EXS>)); 
      close EXS;
    };
  }
  return \@found;
}

1;
