package EnsEMBL::Web::Tools::Misc;

use base qw(Exporter);
our @EXPORT = qw(pretty_date);
our @EXPORT_OK = qw(pretty_date);

sub pretty_date {
  my $timestamp = shift;
  my @date = localtime($timestamp);
  my @days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  return $days[$date[6]].' '.$date[3].' '.$months[$date[4]].', '.($date[5] + 1900);
}

1;