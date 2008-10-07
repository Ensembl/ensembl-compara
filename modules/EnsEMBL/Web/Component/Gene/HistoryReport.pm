package EnsEMBL::Web::Component::Gene::HistoryReport;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return; 
}

sub content {
  my $self = shift;
  my $OBJ = $self->object;
  my $type = lc($OBJ->type);
  # retrieve archive object 
  my $object = $OBJ->get_archive_object();

  my $html = '';

  my $id = $object->stable_id.".".$object->version;
  my $status;
  if ($object->is_current) {
    # this *is* the current version of this stable ID
    $status = "Current";
  } elsif ($object->current_version) {
    # there is a current version of this stable ID
    $status = "Old version";
  } else {
    # this stable ID no longer exists
    $status = "Retired (see below for possible successors)";
  }

  my $latest = $object->get_latest_incarnation;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);
  $id = $latest->stable_id.".".$latest->version;
  my $version_html = $self->_archive_link($object, $OBJ, $latest, $latest->stable_id, $param, $id);
  $version_html .= "<br />\n";
  $version_html .= "Release: ".$latest->release;
  $version_html .= " (current)" if ($object->is_current);
  $version_html .= "<br />\n";
  $version_html .= "Assembly: ".$latest->assembly."<br />\n";
  $version_html .= "Database: ".$latest->db_name."<br />";
  

   $html .= qq(
    <dl class="summary">
      <dt>Stable ID</dt>
      <dd>$id</dd>
    </dl>
    <dl class="summary">
      <dt>Status</dt>
      <dd>$status</dd>  
    </dl>
    <dl class = "summary">
      <dt>Latest Version</dt>
      <dd>$version_html</dd> 
    </dl>);
         
  return $html;
}


sub _archive_link {
  my ($self, $object, $latest, $name, $type, $display_label, $release, $version ) = @_;

  $release ||= $latest->release;
  $version ||= $latest->version;

  # no archive for old release, return un-linked display_label
  return $display_label if ($release < $self->object->species_defs->EARLIEST_ARCHIVE);

  my $url;
  my $site_type;

  if ($latest->is_current) {

    $url = "/";
    $site_type = "current";

  } else {

    my %archive_sites = map { $_->{release_id} => $_->{short_date} }
      @{ $self->object->species_defs->RELEASE_INFO };

    $url = "http://$archive_sites{$release}.archive.ensembl.org/";
    $url =~ s/ //;
    $site_type = "archived";

  }

  $url .=  $ENV{'ENSEMBL_SPECIES'};

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my $html = qq(<a title="View in $site_type $view" href="$url/$view?$type=$name">$display_label</a>);
  return $html;
}

1;
