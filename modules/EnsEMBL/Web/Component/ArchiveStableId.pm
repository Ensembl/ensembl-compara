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

=head2 name

 Arg1        : panel
 Arg2        : data object
 Example     : $panel1->add_rows(qw(name   EnsEMBL::Web::Component::SNP::name) );
 Description : adds a label and the variation name, source to the panel
 Return type : 1

=cut

sub name {
  my($panel, $object) = @_;
  my $label  = 'Stable ID';
  my $id = $object->stable_id.".".$object->version;
  $panel->add_row( $label, $object->type.": $id" );
  return 1;
}


sub remapped {
  my($panel, $object) = @_;
  my $label  = 'Last remapped';

  my $assembly = $object->assembly;
  my $html .= "Assembly: $assembly<br />Database: ".$object->db_name;
  $html .= "<br />Release: ".$object->release;

  $panel->add_row( $label, $html );
  return 1;
}


sub status {
  my($panel, $object) = @_;
  my $id = $object->stable_id.".".$object->version;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);

  my $status;
  my $current_obj = $object->get_current_object($object->type);
  my $archive = _archive_link($object, $id, $param, "Archive <img src='/img/ensemblicon.gif'/>");

  if (!$current_obj) {
    $status = "<b>This ID has been removed from Ensembl</b>";
    my $successors = $object->successors;
    my $url = qq(<a href="idhistoryview?$param=%s">%s</a>);
    foreach ( @{$object->successors || []} ) {
      $status .= "<br />and replaced by ";
      $status .= sprintf ($url, $_->stable_id, $_->stable_id);
      $status .= " in release ".$_->release;
    }
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

  if ($archive) {
    $panel->add_row("Archive", "$archive (release ".$object->release.")");
  }
  else {
    $panel->add_row("Archive", "No archive for release ".$object->release." available.");
  }
  return 1;
}

sub associated_ids {
  my($panel, $object) = @_;
  my $type = $object->type;
  my $url = qq(<a href="idhistoryview?%s=%s">%s</a>);

  # Genes
  unless ($type eq 'Gene') {
    my $label1 = 'Archived genes';

    my %gene_ids = map { $_->stable_id => $_; } @{ $object->genes || [] };
    if (keys %gene_ids) {
      my $html1;
      foreach (keys %gene_ids) {
	$html1 .= "<p>". sprintf ($url, "gene", $_, $_);
	$html1 .= "</p>";
      }
      $panel->add_row( $label1, $html1);
    }
  }

  # Transcripts
  unless ($type eq 'Transcript') {
    my $label2  = 'Archived transcripts';
    my %ids = map { $_->stable_id => $_; } @{ $object->transcript || [] };
    if (keys %ids) {
      my $html;
      foreach (keys %ids) {
	$html .="<p>".sprintf ($url,"transcript",$_, $_)."</p>";
      }
      $panel->add_row( $label2, $html);
    }
  }
  return 1 if $type eq 'Translation';

  # Peptides
  my $label3  = 'Archived peptides';
  my %pep_ids = map { $_->stable_id => $_; } @{ $object->peptide || [] };
  if (keys %pep_ids) {
    my $html;
    foreach ( keys %pep_ids) {
      $html .= "<p>".sprintf ($url, "peptide", $_, $_)."<br /><kbd>";
      my $peptide_obj = $pep_ids{$_};
      my $seq = $peptide_obj->get_peptide;
      $seq =~ s#(.{1,60})#$1<br />#g;
      $html .= "$seq</kbd></p>";
    }
    $panel->add_row( $label3, $html);
  }
  return 1;
}


sub history {
  my($panel, $object) = @_;
  my $history;
  foreach my $arch_id ( @{ $object->history} ) {
    push @{ $history->{$arch_id->release} }, $arch_id;
  }
  return unless keys %$history;

  $panel->add_columns(
    { 'key' => 'Release',  },
    { 'key' => 'Assembly',  },
    { 'key' => 'Database', title=> 'Last database' },
		     );

  my %columns;
  my $type = $object->type;
  my $param = $type eq 'Translation' ? "peptide" : lc($type);
  my $id_focus = $object->stable_id.".".$object->version;

  my @releases = (sort { $b <=> $a } keys %$history);
  # loop over releases and print results

  for (my $i =0; $i <= $#releases; $i++) {
    my $row;
    if ( $releases[$i]-$releases[$i+1] == 1) {
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
      my $archive = _archive_link($object, $id, $param, "<img src='/img/ensemblicon.gif'/>",  $releases[$i]);

      my $display_id = $id eq $id_focus ? "<b>$id</b>" : $id;
      $row->{$a->stable_id} = qq(<a href="idhistoryview?$param).qq(=$id">$display_id</a> $archive);
    }
    $panel->add_row( $row );
  }
  return 1;
}

sub _archive_link {
  my ($object, $name, $type, $id, $release) = @_;
  $release ||= $object->release;
  return unless $release > 24;
  my $url;
  my $current_obj = $object->get_current_object($type);

  if ($current_obj && $current_obj->version eq $object->version) {
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
  $id = qq(<a title="Archive site" href="$url$view?$type=$name">$id</a>);
  return $id;
}

sub _current_link {
  my ($name, $type, $display) = @_;
  my $url =  "/".$ENV{'ENSEMBL_SPECIES'}."/";
  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  }
  return qq(<a title="Archive site" href="$url$view?$type=$name">$display</a>);
}


1;

      # get successors (for tagging)
      #my $predecessor = join("<br />", map { $_->stable_id.".".$_->version }  @{ $a->get_all_predecessors });
      #$html .= "<td>$predecessor</td>";

