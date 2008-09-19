package EnsEMBL::Web::Component::ArchiveStableId;

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham <webmaster@sanger.ac.uk>

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);


# General info table #########################################################

=head2 version_info

 Arg1,2      : panel, data object
 Description : static paragraph of info text
 Output      : two col table
 Return type : 1

=cut


sub version_info {
  my ($panel, $object) = @_;

  $panel->print(qq(
    <p>Ensembl stable ID versions of Genes, Transcripts, Translations and Exons
    are distinct from database versions. The rules for version increments are:
    </p>
    <ul>
      <li>Exon: if exon sequence changed</li>
      <li>Transcript: if spliced exon sequence changed</li>
      <li>Translation: if transcript changed</li>
      <li>Gene: if any of its transcript changed</li>
    </ul>
    <p>Ensembl predictions may merge over time. When this happens one
    or more identifiers are retired. The retired IDs are shown on this
    page.</p>
  ));

 return 1;
}


=head2 name

 Arg1,2      : panel, data object
 Description : adds the type and stable ID of the archive ID
 Output      : two col table
 Return type : 1

=cut

sub name {
  my($panel, $object) = @_;
  my $label  = 'Stable ID';
  my $id = $object->stable_id.".".$object->version;
  $panel->add_row( $label, $object->type.": $id" );
  return 1;
}


=head2 status

 Arg1,2      : panel, data object
 Description : whether the ID is current, old version, or retired
 Output      : two col table
 Return type : 1

=cut

sub status {
  my ($panel, $object) = @_;
  
  my $status;

  if ($object->is_current) {
    # this *is* the current version of this stable ID
    $status = "<b>Current</b>";
  } elsif ($object->current_version) {
    # there is a current version of this stable ID
    $status = "<b>Old version</b>";
  } else {
    # this stable ID no longer exists
    $status = "<b>Retired</b> (see below for possible successors)";
  }

  $panel->add_row("Status", $status);
  return 1 if $status =~/^Current/;
}


=head2 latest_version

 Arg1,2      : panel, data object
 Description : Prints information about the latest incarnation of this stable
               ID (version, release, assembly, dbname) and links to current or
               archive display (geneview, transview, protview).
 Output      : two col table
 Return type : 1

=cut

sub latest_version {
  my ($panel, $object) = @_;
  
  my $latest = $object->get_latest_incarnation;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);
  my $id = $latest->stable_id.".".$latest->version;

  my $html = _archive_link($object, $latest, $latest->stable_id, $param, $id);
  $html .= "<br />\n";
  $html .= "Release: ".$latest->release;
  $html .= " (current)" if ($object->is_current);
  $html .= "<br />\n";
  $html .= "Assembly: ".$latest->assembly."<br />\n";
  $html .= "Database: ".$latest->db_name."<br />";

  $panel->add_row("Latest version", $html);
  return 1;
}


=head2 associated_ids

 Arg1,2      : panel, data object
 Description : adds the associated gene/transcript/peptide (and seq)
 Output      : spreadsheet
 Return type : 1

=cut

sub associated_ids {
  my ($panel, $object) = @_;

  my @associated = @{ $object->get_all_associated_archived };
  return 0 unless (@associated);
  
  my @sorted = sort { $a->[0]->release <=> $b->[0]->release ||
                      $a->[0]->stable_id cmp $b->[0]->stable_id } @associated;

  my $last_release;
  my $last_gsi;

  $panel->add_option('triangular', 1);
  $panel->add_columns(
    { 'key' => 'release', 'align' => 'left', 'title' => 'Release' },
    { 'key' => 'gene', 'align' => 'left', 'title' => 'Gene' },
    { 'key' => 'transcript', 'align' => 'left', 'title' => 'Transcript' },
    { 'key' => 'translation', 'align' => 'left', 'title' => 'Translation' },
  );
  
  while (my $r = shift(@sorted)) {

    my ($release, $gsi, $tsi, $tlsi, $pep_seq);

    # release
    if ($r->[0]->release == $last_release) {
      $release = undef;
    } else {
      $release = $r->[0]->release;
    }

    # gene
    if ($r->[0]->stable_id eq $last_gsi) {
      $gsi = undef;
    } else {
      $gsi = _idhistoryview_link('gene', $r->[0]->stable_id);
    }

    # transcript
    $tsi = _idhistoryview_link('transcript', $r->[1]->stable_id);

    # translation
    if ($r->[2]) {
      $tlsi = _idhistoryview_link('peptide', $r->[2]->stable_id);
      $tlsi .= '<br />'._get_formatted_pep_seq($r->[3], $r->[2]->stable_id);
    } else {
      $tlsi = 'none';
    }

    $panel->add_row({
      'release' => $release,
      'gene' => $gsi,
      'transcript' => $tsi,
      'translation' => $tlsi,
    });

    $last_release = $r->[0]->release;
    $last_gsi = $r->[0]->stable_id;
  }

  return 1;
}


sub _get_formatted_pep_seq {
  my $seq = shift;
  my $stable_id = shift;

  my $html;

  if ($seq) {
    $seq =~ s#(.{1,60})#$1<br />#g;
    $html = "<kbd>$seq</kbd>";
  }

  return $html;
}


sub tree {
  my ($panel, $object) = @_;
  
  my $name = $object->stable_id .".". $object->version;
  my $label = "ID History Map";
  
  my $historytree = $object->history;
  unless (defined $historytree) {
    $panel->add_row($label, qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>));
    return 1;
  }  
  
  my $size = scalar(@{ $historytree->get_release_display_names });
  if ($size < 2) {
    $panel->add_row($label, qq(<p style="text-align:center"><b>There is no history for $name stored in the database.</b></p>));
    return 1;
  }

  if ($panel->is_asynchronous('tree')) {
    
    my $json = "{ components: [ 'EnsEMBL::Web::Component::ArchiveStableId::tree'], fragment: {stable_id: '" . $object->stable_id . "." . $object->version . "', species: '" . $object->species . "'} }";
    my $html = "<div id='component_0' class='info'>Loading history tree...</div><div class='fragment'>$json</div>";
    $panel->add_row($label ." <img src='/img/ajax-loader.gif' width='16' height='16' alt='(loading)' id='loading' />", $html);
  
  } else { 
    
    my $tree = _create_idhistory_tree($object, $historytree,$panel);
    my $T = $tree->render;
    if ($historytree->is_incomplete) {
      $T = qq(<p>Too many related stable IDs found to draw complete tree - tree shown is only partial.</p>) . $T;
    }
  
    $panel->add_row($label, $T);
    
  }
  
  return 1;
}


sub _create_idhistory_tree {
  my ($object, $tree,$panel) = @_;
  
  my $wuc = $object->image_config_hash('idhistoryview');
  $wuc->container_width($object->param('image_width') || 900);
  $wuc->set_width($object->param('image_width'));
  $wuc->set('_settings', 'LINK', _flip_URL($object));
  $wuc->{_object} = $object;
  
  my $image = $object->new_image($tree, $wuc, [$object->stable_id]);
  $image->image_type = 'idhistorytree';
  $image->image_name = $object->param('image_width').'-'.$object->stable_id;
  $image->imagemap = 'yes';
  
  return $image;
}

 
sub _flip_URL {
  my ($object) = @_;
  
  my $temp = $object->type;
  my $type = $temp eq 'Translation' ? "peptide" : lc($temp);
  
  return sprintf('%s=%s', $type, $object->stable_id .".". $object->version);
}


sub _idhistoryview_link {
  my ($type, $stable_id) = @_;
  return undef unless ($stable_id);
  my $fmt = qq(<a href="idhistoryview?%s=%s">%s</a>);
  return sprintf($fmt, $type, $stable_id, $stable_id);
}


=head2 _archive_link
 Arg 1       : data object
 Arg 2       : param to view for URL (within first <a> tag)
 Arg 3       : type of object  (e.g. "gene", "transcript" or "peptide")
 Arg 4       : id - the display text (within <a>HERE</a> tags)
 Description : creates an archive link from the ID if archive is available
               if the ID is current, it creates a link to the page on curr Ens
 Return type : html

=cut

sub _archive_link {
  my ($object, $latest, $name, $type, $display_label, $release, $version) = @_;

  $release ||= $latest->release;
  $version ||= $latest->version;
  
  # no archive for old release, return un-linked display_label
  return $display_label if ($release < $object->species_defs->EARLIEST_ARCHIVE);
  
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


1;

