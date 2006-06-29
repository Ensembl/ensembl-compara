package EnsEMBL::Web::Component::ArchiveStableId;

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham <webmaster@sanger.ac.uk>

=cut

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";
use POSIX qw(floor ceil);
use CGI qw(escapeHTML);

# General info table #########################################################


=head2 version_info

 Arg1,2      : panel, data object
 Description : static paragraph of info text
 Output      : two col table
 Return type : 1

=cut


sub version_info {
   my ($panel, $object) = @_;
  $panel->print(qq(<p>Ensembl Gene, Transcript and Exon versions are distinct from 
database versions.  The versions increment when there is a sequence change to a Gene, Transcript or Exon respectively (considering exons only for genes and transcripts). </p>));
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


=head2 remapped

 Arg1,2      : panel, data object
 Description : adds the assembly, database and release corresponding to the last mapping of the archive ID
 Output      : two col table
 Return type : 1

=cut

sub remapped {
  my($panel, $object) = @_;
  my $label  = 'Last remapped';

  my $assembly = $object->assembly;
  my $html .= "Assembly: $assembly<br />Database: ".$object->db_name;
  $html .= "<br />Release: ".$object->release;

  $panel->add_row( $label, $html );
  return 1;
}

=head2 status

 Arg1,2      : panel, data object
 Description : whether the ID is current, removed, replaced,
               if it is removed and there are successors, ID of these are shown
 Output      : two col table
 Return type : 1

=cut

sub status {
  my($panel, $object) = @_;
  my $id = $object->stable_id.".".$object->version;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);

  my $status;
  my $current_obj = $object->get_current_object($object->type);


  if (!$current_obj) {
    $status = "<b>This ID has been removed from Ensembl</b>";
    my @successors = @{ $object->successors || []};
    my $url = qq(<a href="idhistoryview?$param=%s">%s</a>);
    my $verb = scalar @successors > 1 ? "and split into " : "and replaced by ";
    if ($successors[0] && $successors[0]->stable_id eq $object->stable_id) {
      $verb = "but existed as";
    }
    my @successor_text = map {
      my $succ_id = $_->stable_id.".".$_->version;
      sprintf ($url, $succ_id, $succ_id).
	" in release ".$_->release; } @successors;
    $status .= " <b>$verb</b><br />".
      join " and <br />", @successor_text if @successors;
  }
  elsif ($current_obj->version eq $object->version) {
    $status = "Current release ".$object->species_defs->ENSEMBL_VERSION;
    my $current_link = _archive_link($object, $id, $param, $id);
    $status .= " $current_link";
  }
  else  {
    my $current = $object->stable_id . ".". $current_obj->version;
    my $name = _current_link($object->stable_id, $param, $current);
    $status = "<b>Current version of $id is $name</b><br />";
  }
  $panel->add_row( "Status", $status );
  return 1 if $status =~/^Current/;
}

sub archive {
  my ($panel, $object) = @_;
  my $id = $object->stable_id.".".$object->version;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);

  my ($history, $releases) = _get_history($object);

  my $current_obj = $object->get_current_object($object->type);
  if ($current_obj && $current_obj->version eq $object->version) {
    $panel->add_row("Archive", "This version is current");
  }
  else {
    my @archive_releases;
    if ($history) {
      for  (my $i =0; $i < scalar @$releases; $i++) {
	foreach my $a ( @{ $history->{ $releases->[$i] } }  ) {
	  my $history_id = $a->stable_id.".".$a->version;
	  next unless $history_id eq $id;
	  push @archive_releases,  $releases->[$i], $releases->[$i+1]+1;
	  last;
	}
      }
    }

    my $text;
    if (scalar @archive_releases > 1) {
    my $archive_first = _archive_link($object, $id, $param, "Archive <img src='/img/ensemblicon.gif'/>", $archive_releases[-1]) || " (no archive)";
    my $archive_last = _archive_link($object, $id, $param, "Archive <img src='/img/ensemblicon.gif'/>", $archive_releases[0]) || " (no archive)";

    $text = "$id was in release $archive_releases[-1] $archive_first to $archive_releases[0] $archive_last";
  }
    else {
      $text = "No archive available for $id";
    }
    $panel->add_row("Archive", $text);
  }
  return 1;
}

=head2 associated_ids

 Arg1,2      : panel, data object
 Description : adds the associated gene/transcript/peptide (and seq)
 Output      : two col table
 Return type : 1

=cut

sub associated_ids {
  my($panel, $object) = @_;
  my $type = $object->type;

  my ($id_type, $id_type2);
  if ($type eq 'Gene') {
    ($id_type, $id_type2) = ("transcript", "peptide");
  }
  elsif ($type eq 'Transcript') {
    ($id_type, $id_type2) = ("gene", "peptide");
  }
  elsif ($type eq 'Translation') {
    ($id_type, $id_type2) = ("gene", "transcript");
  }
  else {
    warn "Error:  Unknown type $type in ID history view";
  }

  my $url = qq( <a href="idhistoryview?%s=%s">%s</a>);
  my %ids = map { $_->stable_id => $_; } @{ $object->$id_type || [] };

  foreach (keys %ids) {
    my $html;
    $html .= "<p>".ucfirst($id_type). sprintf ($url, $id_type, $_, $_). "</p>";

    my %ids2 = map { $_->stable_id => $_; } @{ $object->$id_type2 || [] };
    foreach (keys %ids2) {
      $html .= "<p>".ucfirst($id_type2). sprintf ($url, $id_type2, $_, $_);
      if ($id_type2 eq 'peptide') {
	my $peptide_obj = $ids2{$_};
	my $seq = $peptide_obj->get_peptide;
	if ($seq) {
	  $seq =~ s#(.{1,60})#$1<br />#g;
	  $html .= "<br /><kbd>$seq</kbd>";
	}
	else {
	  $html .= qq( (sequence same as <a href="protview?peptide=$_">current release</a>));
	}
      }
      $html .= "</p>";
    }
    $panel->add_row( "Associated $id_type, $id_type2 in archive", $html);
  }
  return 1;
}


=head2 _get_history

 Arg1        : data object
 Description : gets history and order of releases for object
 Output      : hashref, arrayref
 Return type : hashref, arrayref

=cut

sub _get_history {
  my ($object) = @_;
  my $history;
  foreach my $arch_id ( @{ $object->history} ) {
    push @{ $history->{$arch_id->release} }, $arch_id;
  }
  return unless keys %$history;
  my @releases = (sort { $b <=> $a } keys %$history);
  return ($history, \@releases);
}




=head2 history

 Arg1,2      : panel, data object
 Description : adds the history tree for the archive ID
 Output      : spreadsheet table
 Return type : 1

=cut


sub history {
  my($panel, $object) = @_;
  my ($history, $release_ref) = _get_history($object);
  return unless $history;

  $panel->add_columns(
    { 'key' => 'Release',  },
    { 'key' => 'Assembly',  },
    { 'key' => 'Database', title=> 'Last database' },
		     );

  my %columns;
  my $type = $object->type;
  my $param = $type eq 'Translation' ? "peptide" : lc($type);
  my $id_focus = $object->stable_id.".".$object->version;


  # loop over releases and print results

  my @releases = @$release_ref;
  for (my $i =0; $i <= $#releases; $i++) {
    my $row;
    if ( $releases[$i]-$releases[$i+1] == 1) {
      $row->{Release} = $releases[$i];
    }
    elsif ($releases[$i] eq $releases[-1]) {
      $row->{Release} = $releases[$i];
    }
    else {
      my $start = $releases[$i+1] +1;
      $row->{Release} = "$start-$releases[$i]";
    }

    $row->{Database} = $history->{$releases[$i]}->[0]->db_name;
    $row->{Assembly} = $history->{$releases[$i]}->[0]->assembly;

    my $first_id = $history->{$releases[$i]}->[0]->stable_id;
    if ($i == 0) {
      my $current_obj = $object->get_current_object($type, $first_id);
      if ($current_obj && $current_obj->version eq $object->release) {
	$row->{Release} .= "-". $object->species_defs->ENSEMBL_VERSION;
      }
    }


    # loop over archive ids
    foreach my $a (sort {$a->stable_id cmp $b->stable_id} @{ $history->{$releases[$i]} }) {
      my $id = $a->stable_id.".".$a->version;
      $panel->add_columns(  { 'key' => $a->stable_id, 
			      'title' => $type.": ".$a->stable_id} ) unless $columns{$a->stable_id};
      $columns{$a->stable_id}++;

      # Link to archive of first appearance
      my $first = $releases[$i+1]+1;
      $first = 26 if $first < 26 && $releases[$i] > $object->species_defs->EARLIEST_ARCHIVE;

      my $archive = _archive_link($object, $id, $param, "<img src='/img/ensemblicon.gif'/>",  $first, $a->version );
      my $display_id = $id eq $id_focus ? "<b>$id</b>" : $id;
      $row->{$a->stable_id} = qq(<a href="idhistoryview?$param).qq(=$id">$display_id</a> $archive);
    }
    $panel->add_row( $row );
  }
  return 1;
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
  my ($object, $name, $type, $id, $release, $version) = @_;
  $release ||= $object->release;
  $version ||= $object->version;
  return unless $release >= $object->species_defs->EARLIEST_ARCHIVE;
  my $url;
  my $current_obj = $object->get_current_object($type, $name);
  if ($current_obj && $current_obj->version eq $version) {
    $url = "/";
  }
  else {
    my %archive_sites;
    map { $archive_sites{ $_->{release_id} } = $_->{short_date} }@{ $object->species_defs->RELEASE_INFO };
    $url = "http://$archive_sites{$release}.archive.ensembl.org/";
    $url =~ s/ //;
  }

  $url .=  $ENV{'ENSEMBL_SPECIES'}."/";
  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  }
  elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  $id = qq(<a title="$view" href="$url$view?$type=$name">$id</a>);
  return $id;
}


=head2 _current_link

 Arg 1       : name within first <a> tag -for URL
 Arg 2       : type (e.g. "peptide", "gene", "transcript")
 Arg 3       : display text between <a> HERE </a> tags
 Description : adds the type and stable ID of the archive ID
 Return type : html

=cut


sub _current_link {
  my ($name, $type, $display) = @_;
  my $url =  "/".$ENV{'ENSEMBL_SPECIES'}."/";
  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  }
  elsif ($type eq 'transcript') {
    $view = 'transview';
  }
  return qq(<a title="Archive site" href="$url$view?$type=$name">$display</a>);
}


1;


