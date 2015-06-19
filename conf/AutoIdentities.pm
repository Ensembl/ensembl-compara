use Sys::Hostname;

use SiteDefs;

$SiteDefs::ENSEMBL_IDENTITIES = [
  # Standard UNIX path
  sub {
    my $host = Sys::Hostname::hostname;
    my @path = split(m!/!,$SiteDefs::ENSEMBL_SERVERROOT);
    my @out;
    foreach my $host (('',Sys::Hostname::hostname)) {
      push @out,(map {"unix:$host:".join('/',@path[0..$_])} (1..$#path));
    }
    return \@out;
  },
];

1;
