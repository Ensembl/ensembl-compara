package EnsEMBL::Web::Component::UserData::RegionReportOutput;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Region Report Output';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $html;
  warn ">>> OUTPUT";

  my $record = $hub->session->get_data('code' => $hub->param('code'));

  my $filename = $record->{'filename'};
  my $name     = $record->{'name'} || 'region_report';
  $name .= '.txt';
  my $tmpfile = new EnsEMBL::Web::TmpFile::Text(
      filename  => $record->{'filename'}, 
      prefix    => 'region_report', 
  );
  warn ">>> TMPFILE $tmpfile ($filename)";

  if ($tmpfile->exists) {
    my $data = $tmpfile->retrieve; 
    warn ">>> DATA $data";
    use Data::Dumper; warn Dumper($data);
    $html .= sprintf('<h3>Download: <a href="/%s/download?file=%s;prefix=region_report" class="popup">%s</a></h3>', $hub->species, $filename, $name, $name);
    $html .= qq(<pre>$data</pre>);
  }
  else {
    $html = qq(<p class="space-below">Sorry, your results file could not be retrieved from disk. Please try later.</p>);
  }

  return $html;
}

1;
