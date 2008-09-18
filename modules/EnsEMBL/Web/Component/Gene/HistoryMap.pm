package EnsEMBL::Web::Component::Gene::HistoryMap;

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
  return 'ID History Map';
}

sub content {
  my $self = shift;
  my $OBJ = $self->object;
  my $type = lc($OBJ->type);
  my $image;
  my $object = $OBJ->get_archive_object; 

  my $name = $object->stable_id .".". $object->version;
  my $historytree = $OBJ->history;

  unless (defined $historytree) {
    my $html =  qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>);
    return $html;
  }

  my $size = scalar(@{ $historytree->get_release_display_names });
  if ($size < 2) {
    my $html =  qq(<p style="text-align:center"><b>There is no history for $name stored in the database.</b></p>);
    return $html;
  }

  my $tree = _create_idhistory_tree($object, $historytree, $OBJ);
  my $T = $tree->render;
    if ($historytree->is_incomplete) {
      $T = qq(<p>Too many related stable IDs found to draw complete tree - tree shown is only partial.</p>) . $T;
    }


  return $T;
}


sub _archive_link {
  my ($object, $OBJ, $latest, $name, $type, $display_label, $release, $version ) = @_;

  $release ||= $latest->release;
  $version ||= $latest->version;
  
  #no archive for old release, return un-linked display_label
  return $display_label if ($release < $OBJ->species_defs->EARLIEST_ARCHIVE);

  my $url;
  my $site_type;

  if ($latest->is_current) {

    $url = "/";
    $site_type = "current";
 
  } else {

    my %archive_sites = map { $_->{release_id} => $_->{short_date} }
      @{ $object->species_defs->RELEASE_INFO };

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

sub _create_idhistory_tree {
  my ($object, $tree, $OBJ) = @_;

  my $wuc = $OBJ->image_config_hash('idhistoryview');
  $wuc->container_width($OBJ->param('image_width') || 900);
  $wuc->set_width($OBJ->param('image_width'));
  $wuc->set('_settings', 'LINK', _flip_URL($object));
  $wuc->{_object} = $object;

  my $image = $OBJ->new_image($tree, $wuc, [$object->stable_id], $OBJ );
  $image->image_type = 'idhistorytree';
  $image->image_name = $OBJ->param('image_width').'-'.$object->stable_id;
  $image->imagemap = 'yes';
  return $image;
}

sub _flip_URL {
  my ($object) = @_;
 
  my $temp = $object->type;
  my $type = $temp eq 'Translation' ? "peptide" : lc($temp);

  return sprintf('%s=%s', $type, $object->stable_id .".". $object->version);
}

1;
