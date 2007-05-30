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
 Output      : two col table
 Return type : 1

=cut

sub associated_ids {
  my ($panel, $object) = @_;
  
  my $type = $object->type;
  my $html;

  if ($type eq 'Gene') {

    # get associated transcripts
    my %tr = map { $_->stable_id => $_; } @{ $object->transcript };
    foreach my $tr_id (sort keys %tr) {
      $html .= '<p>'._get_assoc_link('Transcript', 'transcript', $tr_id,
        $tr_id).'</p>';

      # get associated translations for this transcript
      my $tr_obj = $tr{$tr_id};
      my %trlt = map { $_->stable_id => $_; }
        @{ $tr_obj->get_all_translation_archive_ids };

      foreach my $trlt_id (sort keys %trlt) {
        $html .= '<p>'._get_assoc_link('Translation', 'peptide',
          $trlt_id, $trlt_id);
          
        # peptide sequence
        $html .= _get_formatted_pep_seq($trlt{$trlt_id});
        
        $html .= '</p>';
      }
    }

  } elsif ($type eq 'Transcript') {
    
    # get associated genes
    my %genes = map { $_->stable_id => $_; } @{ $object->gene };
    foreach my $gene_id (sort keys %genes) {
      $html .= '<p>'._get_assoc_link('Gene', 'gene', $gene_id,
        $gene_id).'</p>';
    }

    # get associated translations
    my %trlt = map { $_->stable_id => $_; } @{ $object->peptide };
    foreach my $trlt_id (sort keys %trlt) {
      $html .= '<p>'._get_assoc_link('Translation', 'peptide',
        $trlt_id, $trlt_id);
        
      # peptide sequence
      $html .= _get_formatted_pep_seq($trlt{$trlt_id});
      
      $html .= '</p>';
    }

  } elsif ($type eq 'Translation') {

    # peptide sequence of this object if found in archive
    if ($object->peptide) {
      $html .= '<p>'._get_assoc_link('Translation', 'peptide',
        $object->stable_id, $object->stable_id);
      $html .= _get_formatted_pep_seq($object).'</p>';
    }
    
    # get associated genes
    my %genes = map { $_->stable_id => $_; } @{ $object->gene };
    foreach my $gene_id (sort keys %genes) {
      $html .= '<p>'._get_assoc_link('Gene', 'gene', $gene_id,
        $gene_id).'</p>';
    }

    # get associated transcripts
    my %tr = map { $_->stable_id => $_; } @{ $object->transcript };
    foreach my $tr_id (sort keys %tr) {
      $html .= '<p>'._get_assoc_link('Transcript', 'transcript', $tr_id,
        $tr_id).'</p>';
    }

  } else {
    warn "Error: Unknown type $type in idhistoryview.";
  }

  return 0 unless ($html);

  $panel->add_row( "Associated IDs in archive", $html);
  return 1;
}


sub _get_assoc_link {
  my $fmt = qq(%s <a href="idhistoryview?%s=%s">%s</a>);
  return sprintf($fmt, @_);
}


sub _get_formatted_pep_seq {
  my $object = shift;

  my $seq = $object->get_peptide;
  my $html;

  if ($seq) {
    $seq =~ s#(.{1,60})#$1<br />#g;
    $html = "<br /><kbd>$seq</kbd>";
  } else  {
    $html = ' (sequence same as <a href="protview?peptide=';
    $html .= $object->stable_id . '>current release</a>)';
  }

  return $html;
}


sub historypanel {
  my ($panel, $object) = @_;
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
    { 'key' => 'request', 'align'=>'left', 'title' => 'Requested ID'},
    { 'key' => 'match', 'align'=>'left', 'title' => 'Matched ID(s)' },
    { 'key' => 'rel', 'align'=>'left', 'title' => 'Release:' },
  );
  foreach my $key (sort {$a <=> $b} keys %releases){
	  $panel->add_columns(
	    { 'key' => $key, 'align'=>'left', 'title' => $key   },
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
         if ($rel_matches{$new_release}=~/^\w/){
	       ## compensate for strange data from release 42   
	       if ($new->release eq '43') {$rel_matches{$new_release} = $new->version}
	       my @temp = split(/\//,$rel_matches{$new_release});
	        my $s =0;
	       foreach my $aa (@temp){ if ($aa eq $new->version){$s = 1;}} 
	       unless ($s =~/1/){ push (@temp, $new->version); }
	       @temp = sort @temp;
	       my $new_value = join ('/', @temp);
	       $rel_matches{$new_release} = $new_value;
         }else {
	      $rel_matches{$new_release} =$new->version; 	 
         } 
       }
      }
	  if (defined $old){
	   if ($old->stable_id eq $a_stable){
          my $old_release = $old->release;
		  if ($rel_matches{$old_release}=~/^\w/){
			if ($old_release =~/43/){$rel_matches{$old_release} = $old->version}
			else{  
	         my @temp = split(/\//,$rel_matches{$old_release});
	         my $s =0;
	         foreach my $aa (@temp){if ($aa eq $old->version){$s = 1;}} 
	         unless ($s =~/1/){ push (@temp, $old->version); }
	         @temp = sort @temp;
	         my $new_value = join ('/', @temp);
	         $rel_matches{$old_release} = $new_value;
            }
          } else{
           $rel_matches{$old_release} =  $old->version; 	 
         }
        }
      }	
	 }

    ## Try and backfill any empty gaps ##
      my %rel_pos;
      my @rel = sort {$a <=> $b} keys %rel_matches;
      my $count = 0;
      foreach my $r (@rel){
	    $rel_pos{$r} = $count;
	    $count++; 
      }
      my $size = @rel;
      $size -=1; 
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
          my $i = $pos + 1;
          for ( $i; $i<=$size; $i++){
	         my $next = $rel[$i];
	         my $next_value = $rel_matches{$next};
	         if ($next_value=~/^\w/){ $rel_matches{$key} = $previous_value; next;}
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

sub nohistory {
  my ($panel, $object) = @_;
  my @temp = @{$panel->params};
  $panel->print(qq(<p>No ID history was found for the following identifiers:</p><p>));
  foreach my $id (@temp){
    $panel->print(qq(<br>$id));	
  }
  $panel->print(qq(</p>));
  return 1;
}


sub _flip_URL {
  my( $object) = @_;
  my $temp = $object->type; 
  my $type = $temp eq 'Translation' ? "peptide" : lc($temp);
  return sprintf '%s=%s;%s', $type, $object->stable_id .".". $object->version;
}


sub tree {
  my ($panel, $object) = @_;
  my $name = $object->stable_id .".". $object->version;
  my $status   = 'status_tree';
  my $label = "ID History Map";
  my $URL = _flip_URL($object);
  if( $object->param( $status ) eq 'off' ) { $panel->add_row( '', "$URL=on" ); return 0; }
  my $historytree = $object->history;
  unless (defined $historytree){$panel->add_row($label, qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>) ) and return 1;}  
  my @temp = @{$historytree->get_release_display_names};
  my $size = @temp;
  unless ($size >=2 ){$panel->add_row( $label, qq(<p style="text-align:center"><b>There is no history for $name stored in the database.</b></p>) ) and return 1;}
    if ($panel->is_asynchronous('tree')) {
    warn "Asynchronously load history tree";
    my $json = "{ components: [ 'EnsEMBL::Web::Component::ArchiveStableId::tree'], fragment: {stable_id: '" . $object->stable_id . "." . $object->version . "', species: '" . $object->species . "'} }";
    my $html = "<div id='component_0' class='info'>Loading history tree...</div><div class='fragment'>$json</div>";
    $panel->add_row($label ." <img src='/img/ajax-loader.gif' width='16' height='16' alt='(loading)' id='loading' />", $html, "$URL=odd") ;
  } else{ 
    ( $panel->add_row($label, qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>) ) and return 1) unless (defined $historytree); 
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

