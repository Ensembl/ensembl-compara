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
database versions.  The versions increment when there is a sequence change to a Gene, Transcript or Exon respectively (considering exons only for genes and transcripts). Genes or Transcripts may merge over time. When this happens one identifier is retired.  The retired IDs are shown in the table. </p>));

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
  my $current_release = $object->species_defs->ENSEMBL_VERSION;


  if (!$current_obj) {
    $status = "<b>This ID has been removed from Ensembl</b>";
    my @successors = reverse @{ $object->successor_history || []};

    # Only display successors in current release
    if (@successors) {
      my $url = qq(<a href="idhistoryview?$param=%s">%s</a>);
      my @successor_text;
      my $most_recent = 0;

      foreach my $id (@successors) {
	last if $id->release < $most_recent;
	$most_recent = $id->release;

	my $succ_id = $id->stable_id.".".$id->version;
	my $current = $id->release == $current_release ? " (current release)":"";
	push @successor_text, sprintf ($url, $succ_id, $succ_id)." release ".$id->release.$current;
      }

      my $verb;
      if ( $successors[0]->stable_id eq $object->stable_id ) {
	$verb = "but exists as";
      }
      else {
	$verb = "and replaced by ";
      }
      $status .= " <b>$verb</b><br />".	join " and <br />", @successor_text if @successors;
    }
  }
  elsif ($current_obj->version eq $object->version) {
    $status = "Current release $current_release";
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
  my $id = $object->stable_id;
  my $version = $object->version;
  my $name = $id . "." . $version;
  my $param = $object->type eq 'Translation' ? 'peptide' : lc($object->type);
  my ($history, $releases) = _get_history($object);
  my @release = @$releases;
  my $firstr = $release[0];
  
  my $current_obj = $object->get_current_object($object->type);
  if ($current_obj && $current_obj->version eq $object->version) { 
	$panel->add_row("Archive", "This version is current");
  } else {
   my $text;
   if ($history) {
    my ($first, $last);
    foreach my $e (@{$history->get_all_StableIdEvents}){
      my $old = $e->old_ArchiveStableId;
      my $new = $e->new_ArchiveStableId;
      next unless ($old && $new);
      if ($new->stable_id eq $id && $new->version == $version){
        $first = $new->release;
      } 
      if ($old->stable_id eq $id && $old->version == $version && $new->release ne $old->release){
        $last = $new->release;
      }       
    }
    unless ($first =~/^\d/){
	  foreach my $e (@{$history->get_all_StableIdEvents}){
	    my $old = $e->old_ArchiveStableId;
	    my $new = $e->new_ArchiveStableId;
        next unless ($old && $new);
        my $prev = $version;
        $prev -=1;
        if ($new->stable_id eq $id && $new->version == $prev){
          $first = $new->release;
        }
      }	
    }
    # need to compensate for cases where the same release number has different versions of the same gene  
 	unless ($last =~/^\d/){
	  foreach my $e (@{$history->get_all_StableIdEvents}){
	    my $old = $e->old_ArchiveStableId;
	    my $new = $e->new_ArchiveStableId;
        next unless ($old && $new);
        my $next = $version;
        $next +=1;
        if ($old->stable_id eq $id && $old->version == $next){
          $last = $new->release;
        }
      }	
    }
    my $first_link = _archive_link($object, $name, $param, "Archive <img alt='link to archive version' src='/img/ensemblicon.gif'/>", $first, $version  )|| "(no web archive)";
    $text = "$name was in release $first $first_link";
    my $last_link;
    unless ($last == $first){
     $last -= 1;
     $last_link = _archive_link($object, $name, $param, "Archive <img alt='link to archive version' src='/img/ensemblicon.gif'/>", $last, $version )|| "(no web archive)";
     $text .= " to $last $last_link"; 
    }
      if ($last  eq $firstr){ $text = "$name was in release $last $last_link"; } 
   } else {
      $text = "No archive available for $id";
   }

    # Add protein sequence if old version of peptide

    if ($object->type eq 'Translation') {
      my $seq = $object->peptide_seq;
      if ($seq) {
	    $seq =~ s#(.{1,60})#$1<br />#g;
	    $text .= "<br /><kbd>>$id<br />$seq</kbd>";
      }
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

  # e.g. Get all gene ids;  Do map to rm duplicate IDS
  my %ids = map { $_->stable_id => $_; } @{ $object->$id_type || [] };

  foreach (keys %ids) {
    my $html;
    $html .= "<p>".ucfirst($id_type). sprintf ($url, $id_type, $_, $_). "</p>";
    my %id2;  # need to uniquify these
    if ($id_type eq 'transcript'){ 
	 my $transcript_obj = $ids{$_};
	 foreach  ( @{ $transcript_obj->get_all_translation_archive_ids || [] }) {
      my $stable_id2 = $_->stable_id;
      next unless $stable_id2;
      $id2{$stable_id2} = $_;
     } 
	} else {
     foreach  ( @{ $object->$id_type2 || [] }) {
      my $stable_id2 = $_->stable_id;
      next unless $stable_id2;
      $id2{$stable_id2} = $_;
     }
    } 
    foreach my $stable_id2 (keys %id2) {
      $html .= "<p>".ucfirst($id_type2). sprintf ($url, $id_type2, $stable_id2, $stable_id2);

      if ($id_type2 eq 'peptide') {
	my $peptide_obj = $id2{$stable_id2};
	my $seq = $peptide_obj->get_peptide;

	if ($seq) {
	  $seq =~ s#(.{1,60})#$1<br />#g;
	  $html .= "<br /><kbd>$seq</kbd>";
	}
	else  {
	  $html .= qq( (sequence same as <a href="protview?peptide=$stable_id2">current release</a>));
	}
      }
      $html .= "</p>";
    }
    $panel->add_row( "Associated IDs in archive", $html);
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

  my $id = $object->stable_id;;
  my  $history = $object->history;
  my @temp = @{$history->get_release_display_names};
  my @releases = sort ({$a <=> $b} @temp);
  return unless keys %$history;
  return ($history, \@releases);
}




=head2 history

 Arg1,2      : panel, data object
 Description : adds the history tree for the archive ID
 Output      : spreadsheet table
 Return type : 1

=cut

sub historypanel{
  my($panel, $object) = @_;
  my @temp = @{$panel->params};
  my %releases;

  foreach my $id (@temp){
    my $history = $id->get_history_tree;
    my @temp = @{$history->get_release_display_names};
    my @rel = sort ({$a <=> $b} @temp);
    foreach my $r (@rel){
	   unless ($r =~/18\./){
	     unless (exists $releases{$r}){$releases{$r} =$r;}
       }
    }
  }
  $panel->add_option('triangular',1); 	
  $panel->add_columns(
    { 'key' => 'request', 'align'=>'left', 'title' => 'Uploaded ID'},
    { 'key' => 'match', 'align'=>'left', 'title' => 'Matched ID' },
    { 'key' => 'rel', 'align'=>'left', 'title' => 'Release:' },
  );
  foreach my $key (sort {$a <=> $b} keys %releases){
	  $panel->add_columns(
	    { 'key' => $key, 'align'=>'center', 'title' => $key   },
	  );	
  }

  foreach my $id (@temp){
	my %seen; 
	my $history = $id->get_history_tree;
	my @events = @{ $history->get_all_StableIdEvents };
    my $stable_id = $id->stable_id .".". $id->version;
    foreach my $a_id (@{ $history->get_all_ArchiveStableIds }) {
	 my @info;
	 my $a_stable = $a_id->stable_id;
	 my %rel_matches;
	 foreach my $key (keys %releases){
	   $rel_matches{$key} = "";	
	 }
	 foreach my $e (@events){
	  my $old = $e->old_ArchiveStableId;
      my $new = $e->new_ArchiveStableId;
      if (defined $new){ 
       if ($new->stable_id eq $a_stable){
         my $new_release = $new->release;
         $rel_matches{$new_release} =$new->version; 	 
       }
      }
	  if (defined $old){
	   if ($old->stable_id eq $a_stable){
          my $old_release = $old->release;
         $rel_matches{$old_release} =  $old->version; 	 
        }
      }	
	 }

    ## Try and backfill any empty gaps ##
      my %rel_pos;
      my @rel = sort ({$a <=> $b} keys %rel_matches);
      my $count = 0;
      foreach my $r (@rel){
	    $rel_pos{$r} = $count;
	    $count++; 
      }
      my $size = @rel; 
      foreach my $key (%rel_matches){
        my $value = $rel_matches{$key};
	    unless ($value =~/^\w/){
		  my $previous_value; 
          my $pos = $rel_pos{$key};
          unless ($pos == 0){
           my $previous = $pos -= 1; 
           my $previous_rel = $rel[$previous];
           $previous_value = $rel_matches{$previous_rel}; 
          }
          my $i = $pos +1;
          for ( $i; $i<=$size; $i++){
	         my $next = $rel[$i];
	        # if ($next=~/^\w/){ $rel_matches{$key} = $previous_value; next;}
          }
	    }
      }       
      my $combination = $stable_id . $a_stable;
      unless (exists $seen{$combination}){
        $panel->add_row({
	     'request' => $stable_id,
	     'match'   => $a_stable,
	     'rel'     => '',
	     %rel_matches
	   });
	   $seen{$combination} = "";
	  }
   } 
  }

  return 1;
}

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
  my $current_release = $object->species_defs->ENSEMBL_VERSION;


  # loop over releases and print results

  my @releases = @$release_ref;
  for (my $i =0; $i <= $#releases; $i++) {
    my $row;
    if ( $i==0 or $releases[$i-1]-$releases[$i] == 1) {
      $row->{Release} = $releases[$i];
    }
    else {
      my $end = $releases[$i-1] -1;
      $row->{Release} = "$releases[$i]-$end";
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

    $row->{Release} .= $releases[$i] == $current_release ? " (current)" : "";

    # loop over archive ids
    foreach my $a (sort {$a->stable_id cmp $b->stable_id} @{ $history->{$releases[$i]} }) {
      my $id = $a->stable_id.".".$a->version;
      $panel->add_columns(  { 'key' => $a->stable_id, 
			      'title' => $type.": ".$a->stable_id} ) unless $columns{$a->stable_id};
      $columns{$a->stable_id}++;

      # Link to archive of first appearance
      my $first = $releases[$i];
      my $earliest_archive =  $object->species_defs->EARLIEST_ARCHIVE;
      $first =  $earliest_archive if $first <  $earliest_archive && $releases[$i-1]+1 > $earliest_archive;

      my $archive = _archive_link($object, $id, $param, "<img alt='link to archive version' src='/img/ensemblicon.gif'/>",  $first, $a->version );
      my $display_id = $id eq $id_focus ? "<b>$id</b>" : $id;
      $row->{$a->stable_id} = qq(<a href="idhistoryview?$param).qq(=$id">$display_id</a> $archive);
    }
    $panel->add_row( $row );
  }
  return 1;
}

sub _flip_URL {
  my( $object) = @_;
  my $temp = $object->type; 
  my $type = $temp eq 'Translation' ? "peptide" : lc($temp);
  return sprintf '%s=%s;%s', $type, $object->stable_id .".". $object->version;
}

sub tree {
  my($panel, $object) = @_;
  my $name = $object->stable_id .".". $object->version;
  my $status   = 'status_tree';
  my $label = "ID History Map";
  my $URL = _flip_URL($object);
  if( $object->param( $status ) eq 'off' ) { $panel->add_row( '', "$URL=on" ); return 0; }
   
  if ($panel->is_asynchronous('tree')) {
    warn "Asynchronously load history tree";
    my $json = "{ components: [ 'EnsEMBL::Web::Component::ArchiveStableId::tree'], fragment: {stable_id: '" . $object->stable_id . "." . $object->version . "', species: '" . $object->species . "'} }";
    my $html = "<div id='component_0' class='info'>Loading history tree...</div><div class='fragment'>$json</div>";
    $panel->add_row($label ." <img src='/img/ajax-loader.gif' width='16' height='16' alt='(loading)' id='loading' />", $html, "$URL=odd") ;
  } else{ 
    my $historytree = $object->history;
    ( $panel->print( qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>) ) and return 1) unless (defined $historytree);
    my $tree = _create_idhistory_tree ($object, $historytree);
    my $T = $tree->render;
    $panel->add_row($label, $tree->render, "$URL=off");
   }
  return 1;
}



sub _create_idhistory_tree {
 my ($object, $tree ) = @_;
 my $base_URL = _flip_URL($object);
 my $wuc        = $object->user_config_hash( 'idhistoryview' );
 my $image_width  =  $object->param( 'image_width' ) || 1200; 
 $wuc->container_width($image_width); 
 $wuc->set_width( $object->param('image_width') );
 $wuc->set( '_settings', 'LINK',  $base_URL );
 $wuc->{_object} = $object;
 my $mc =  _id_history_tree_menu($object, 'idhistoryview', [qw(IdhImageSize )]);
 my $image  = $object->new_image( $tree, $wuc, [$object->stable_id] );
 $image->image_type  = 'idhistorytree';
 $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
 $image->imagemap           = 'yes';
 $image->menu_container = $mc;
# $image->imagemap ='no'; 
 return $image;
}
 
sub _id_history_tree_menu {
 my($object, $configname, $left ) = @_;
 my $mc = $object->new_menu_container(
                                         'configname'  => $configname,
                                         'panel'       => 'image',
                                         'object' => $object,
                                         'leftmenus'  => $left,
                                         );
    return $mc;

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
  my $site_type;
  if ($current_obj && $current_obj->version eq $version) {
    $url = "/";
    $site_type = "current ";
  }
  else {
    my %archive_sites;
    map { $archive_sites{ $_->{release_id} } = $_->{short_date} }@{ $object->species_defs->RELEASE_INFO };
    $url = "http://$archive_sites{$release}.archive.ensembl.org/";
    $url =~ s/ //;
    $site_type = "archived ";
  }

  $url .=  $ENV{'ENSEMBL_SPECIES'}."/";
  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  }
  elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  $id = qq(<a title="View in $site_type$view" href="$url$view?$type=$name">$id</a>);
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

